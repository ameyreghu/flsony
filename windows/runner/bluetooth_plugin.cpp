#include "bluetooth_plugin.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Devices.Bluetooth.Rfcomm.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Networking.h>

#include <cstdio>
#include <string_view>
#include <utility>

using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Devices::Bluetooth::BluetoothAdapter;
using winrt::Windows::Devices::Bluetooth::BluetoothCacheMode;
using winrt::Windows::Devices::Bluetooth::BluetoothConnectionStatus;
using winrt::Windows::Devices::Bluetooth::Rfcomm::RfcommServiceId;
using winrt::Windows::Devices::Enumeration::DeviceInformation;
using winrt::Windows::Devices::Radios::RadioState;
using winrt::Windows::Networking::Sockets::SocketProtectionLevel;
using winrt::Windows::Storage::Streams::DataReader;
using winrt::Windows::Storage::Streams::InputStreamOptions;

namespace {

constexpr std::wstring_view kNameHints[] = {L"WH-1000XM4", L"WH-1000XM5",
                                            L"WH-1000XM3"};
constexpr char kServiceUuid[] = "96CC203E-5068-46AD-B32D-E316F5E069BA";

constexpr char kNotPaired[] =
    "No paired Sony WH-1000XM headphones found. Pair them in Settings → "
    "Bluetooth & devices.";
constexpr char kOffOrAway[] = "Headphones are off or out of range.";
constexpr char kRadioOff[] =
    "Bluetooth is off. Turn it on in Settings → Bluetooth & devices.";
constexpr char kNoAdapter[] = "This PC has no Bluetooth adapter.";
constexpr char kNoService[] =
    "Headphones don't advertise Sony's control service.";

bool IsHeadphones(std::wstring_view name) {
  for (auto hint : kNameHints) {
    if (name.find(hint) != std::wstring_view::npos) {
      return true;
    }
  }
  return false;
}

std::string FormatAddress(uint64_t address) {
  char text[18];
  std::snprintf(text, sizeof(text), "%02X:%02X:%02X:%02X:%02X:%02X",
                static_cast<unsigned>((address >> 40) & 0xFF),
                static_cast<unsigned>((address >> 32) & 0xFF),
                static_cast<unsigned>((address >> 24) & 0xFF),
                static_cast<unsigned>((address >> 16) & 0xFF),
                static_cast<unsigned>((address >> 8) & 0xFF),
                static_cast<unsigned>(address & 0xFF));
  return text;
}

// Why a paired device isn't connected: the radio may be off rather than the
// headphones.
winrt::Windows::Foundation::IAsyncOperation<winrt::hstring>
WhyUnreachableAsync() {
  try {
    auto adapter = co_await BluetoothAdapter::GetDefaultAsync();
    if (!adapter) {
      co_return winrt::to_hstring(kNoAdapter);
    }
    auto radio = co_await adapter.GetRadioAsync();
    if (radio && radio.State() != RadioState::On) {
      co_return winrt::to_hstring(kRadioOff);
    }
  } catch (winrt::hresult_error const&) {
  }
  co_return winrt::to_hstring(kOffOrAway);
}

}  // namespace

void BluetoothPlugin::Home::Post(
    std::function<void(BluetoothPlugin&)> task) const {
  dispatcher->Post([plugin = plugin, task = std::move(task)] {
    if (auto self = plugin.lock()) {
      task(*self);
    }
  });
}

std::shared_ptr<BluetoothPlugin> BluetoothPlugin::Register(
    flutter::BinaryMessenger* messenger,
    std::shared_ptr<PlatformDispatcher> dispatcher) {
  auto plugin = std::make_shared<BluetoothPlugin>(std::move(dispatcher));
  plugin->Attach(messenger);
  return plugin;
}

BluetoothPlugin::BluetoothPlugin(std::shared_ptr<PlatformDispatcher> dispatcher)
    : dispatcher_(std::move(dispatcher)) {}

BluetoothPlugin::Home BluetoothPlugin::home() {
  return Home{weak_from_this(), dispatcher_};
}

void BluetoothPlugin::Attach(flutter::BinaryMessenger* messenger) {
  const auto& codec = flutter::StandardMethodCodec::GetInstance();
  std::weak_ptr<BluetoothPlugin> weak = weak_from_this();

  method_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "flsony/bt", &codec);
  method_->SetMethodCallHandler(
      [weak](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (auto self = weak.lock()) {
          self->HandleMethodCall(call, *result);
        } else {
          result->Success();
        }
      });

  events_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "flsony/bt/events", &codec);
  events_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [weak](const EncodableValue*,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& sink)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            if (auto self = weak.lock()) {
              self->sink_ = std::move(sink);
            }
            return nullptr;
          },
          [weak](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            if (auto self = weak.lock()) {
              self->sink_ = nullptr;
            }
            return nullptr;
          }));
}

void BluetoothPlugin::Shutdown() {
  monitoring_ = false;
  status_changed_.revoke();
  device_ = nullptr;
  ++attempt_;
  connecting_ = false;
  CloseSocket();
  sink_ = nullptr;
}

void BluetoothPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    flutter::MethodResult<EncodableValue>& result) {
  const std::string& method = call.method_name();
  if (method == "startMonitoring") {
    StartMonitoring();
  } else if (method == "connect") {
    Connect();
  } else if (method == "disconnect") {
    Disconnect();
  } else if (method == "send") {
    if (auto bytes = std::get_if<std::vector<uint8_t>>(call.arguments())) {
      Send(*bytes);
    }
  } else {
    result.NotImplemented();
    return;
  }
  result.Success();
}

// MARK: Device lookup + reachability

winrt::Windows::Foundation::IAsyncOperation<
    winrt::Windows::Devices::Bluetooth::BluetoothDevice>
BluetoothPlugin::FindHeadphonesAsync() {
  auto paired = co_await DeviceInformation::FindAllAsync(
      BluetoothDevice::GetDeviceSelectorFromPairingState(true));
  for (auto const& info : paired) {
    if (IsHeadphones(info.Name())) {
      co_return co_await BluetoothDevice::FromIdAsync(info.Id());
    }
  }
  co_return nullptr;
}

void BluetoothPlugin::StartMonitoring() {
  monitoring_ = true;
  if (device_) {
    EmitReachable(
        device_.ConnectionStatus() == BluetoothConnectionStatus::Connected,
        winrt::to_string(device_.Name()));
  } else {
    MonitorAsync(home());
  }
}

winrt::fire_and_forget BluetoothPlugin::MonitorAsync(Home home) {
  co_await winrt::resume_background();
  BluetoothDevice device{nullptr};
  try {
    device = co_await FindHeadphonesAsync();
  } catch (winrt::hresult_error const&) {
  }
  home.Post([device](BluetoothPlugin& self) { self.OnMonitorDevice(device); });
}

void BluetoothPlugin::OnMonitorDevice(BluetoothDevice device) {
  if (!monitoring_ || device_) {
    return;
  }
  if (device) {
    Watch(device);
  } else {
    // Headphones paired later are picked up by the next connect attempt.
    EmitReachable(false, "");
  }
}

// Starts reporting reachability for |device| and emits its current state.
void BluetoothPlugin::Watch(BluetoothDevice device) {
  if (!monitoring_ || device_ || !device) {
    return;
  }
  device_ = device;
  // Raised on a thread-pool thread.
  status_changed_ = device_.ConnectionStatusChanged(
      winrt::auto_revoke,
      [home = home()](BluetoothDevice const& sender,
                      winrt::Windows::Foundation::IInspectable const&) {
        try {
          const bool up =
              sender.ConnectionStatus() == BluetoothConnectionStatus::Connected;
          const std::string name = winrt::to_string(sender.Name());
          home.Post([up, name](BluetoothPlugin& self) {
            if (self.monitoring_) {
              self.EmitReachable(up, name);
            }
          });
        } catch (winrt::hresult_error const&) {
        }
      });
  EmitReachable(
      device_.ConnectionStatus() == BluetoothConnectionStatus::Connected,
      winrt::to_string(device_.Name()));
}

// MARK: RFCOMM

void BluetoothPlugin::Connect() {
  if (socket_ || connecting_) {
    return;
  }
  connecting_ = true;
  ConnectAsync(home(), ++attempt_);
}

winrt::fire_and_forget BluetoothPlugin::ConnectAsync(Home home,
                                                     uint64_t attempt) {
  co_await winrt::resume_background();
  BluetoothDevice device{nullptr};
  std::string name;
  std::string failure;
  try {
    device = co_await FindHeadphonesAsync();
    if (!device) {
      failure = kNotPaired;
    } else {
      name = winrt::to_string(device.Name());
      // Don't try to open a link to headphones that are switched off; it
      // just burns seconds in the Bluetooth stack.
      if (device.ConnectionStatus() != BluetoothConnectionStatus::Connected) {
        failure = winrt::to_string(co_await WhyUnreachableAsync());
      }
    }
    if (failure.empty()) {
      home.Post([attempt, name](BluetoothPlugin& self) {
        self.OnConnecting(attempt, name);
      });

      auto id = RfcommServiceId::FromUuid(winrt::guid(kServiceUuid));
      auto found = co_await device.GetRfcommServicesForIdAsync(
          id, BluetoothCacheMode::Uncached);
      if (found.Services().Size() == 0) {
        found = co_await device.GetRfcommServicesForIdAsync(
            id, BluetoothCacheMode::Cached);
      }
      if (found.Services().Size() == 0) {
        failure = kNoService;
      } else {
        auto service = found.Services().GetAt(0);
        StreamSocket socket;
        co_await socket.ConnectAsync(
            service.ConnectionHostName(), service.ConnectionServiceName(),
            SocketProtectionLevel::BluetoothEncryptionAllowNullAuthentication);
        Details details{
            {"Transport", "Classic Bluetooth · RFCOMM (SPP)"},
            {"Address", FormatAddress(device.BluetoothAddress())},
            {"RFCOMM service",
             winrt::to_string(service.ConnectionServiceName())},
            {"Service UUID", kServiceUuid},
            {"Stack", "Windows.Devices.Bluetooth (Windows)"},
        };
        home.Post([attempt, socket, name, details, device](BluetoothPlugin& self) {
          self.OnConnected(attempt, socket, name, details, device);
        });
        co_return;
      }
    }
  } catch (winrt::hresult_error const& e) {
    failure = "Couldn't open the control channel (" +
              winrt::to_string(e.message()) + ").";
  }
  home.Post([attempt, name, failure, device](BluetoothPlugin& self) {
    self.OnConnectFailed(attempt, name, failure, device);
  });
}

void BluetoothPlugin::OnConnecting(uint64_t attempt, const std::string& name) {
  if (attempt == attempt_ && connecting_) {
    EmitStatus("connecting", name);
  }
}

void BluetoothPlugin::OnConnectFailed(uint64_t attempt,
                                      const std::string& name,
                                      const std::string& reason,
                                      BluetoothDevice device) {
  Watch(device);
  if (attempt != attempt_ || !connecting_) {
    return;
  }
  connecting_ = false;
  EmitStatus("failed", name.empty() ? std::nullopt : std::optional(name),
             reason);
}

void BluetoothPlugin::OnConnected(uint64_t attempt, StreamSocket socket,
                                  const std::string& name,
                                  const Details& details,
                                  BluetoothDevice device) {
  Watch(device);
  if (attempt != attempt_ || !connecting_) {
    // Disconnected while the socket was opening.
    socket.Close();
    return;
  }
  connecting_ = false;
  socket_ = socket;
  writer_ = DataWriter(socket_.OutputStream());
  EmitStatus("connected", name, std::nullopt, details);
  ReadAsync(home(), attempt_, socket_);
}

winrt::fire_and_forget BluetoothPlugin::ReadAsync(Home home, uint64_t attempt,
                                                  StreamSocket socket) {
  co_await winrt::resume_background();
  try {
    DataReader reader(socket.InputStream());
    reader.InputStreamOptions(InputStreamOptions::Partial);
    for (;;) {
      const uint32_t count = co_await reader.LoadAsync(1024);
      if (count == 0) {
        break;
      }
      std::vector<uint8_t> bytes(count);
      reader.ReadBytes(bytes);
      home.Post([attempt, bytes = std::move(bytes)](BluetoothPlugin& self) {
        self.OnData(attempt, bytes);
      });
    }
  } catch (winrt::hresult_error const&) {
    // Closed by us, or the link dropped.
  }
  home.Post([attempt](BluetoothPlugin& self) { self.OnClosed(attempt); });
}

void BluetoothPlugin::OnData(uint64_t attempt,
                             const std::vector<uint8_t>& bytes) {
  if (attempt == attempt_ && socket_) {
    Emit({{EncodableValue("type"), EncodableValue("data")},
          {EncodableValue("bytes"), EncodableValue(bytes)}});
  }
}

void BluetoothPlugin::OnClosed(uint64_t attempt) {
  if (attempt != attempt_ || !socket_) {
    return;
  }
  CloseSocket();
  EmitStatus("disconnected");
}

void BluetoothPlugin::Disconnect() {
  const bool open = connecting_ || socket_;
  ++attempt_;
  connecting_ = false;
  CloseSocket();
  if (open) {
    EmitStatus("disconnected");
  }
}

void BluetoothPlugin::CloseSocket() {
  outbox_.clear();
  writing_ = false;
  writer_ = nullptr;
  if (socket_) {
    // Also cancels the pending read, which ends ReadAsync.
    socket_.Close();
    socket_ = nullptr;
  }
}

// Writes go out one at a time, in order.
void BluetoothPlugin::Send(const std::vector<uint8_t>& bytes) {
  if (!socket_) {
    return;
  }
  outbox_.push_back(bytes);
  PumpWrites();
}

void BluetoothPlugin::PumpWrites() {
  if (writing_ || outbox_.empty() || !writer_) {
    return;
  }
  writing_ = true;
  std::vector<uint8_t> bytes = std::move(outbox_.front());
  outbox_.pop_front();
  WriteAsync(home(), attempt_, writer_, std::move(bytes));
}

winrt::fire_and_forget BluetoothPlugin::WriteAsync(Home home, uint64_t attempt,
                                                   DataWriter writer,
                                                   std::vector<uint8_t> bytes) {
  co_await winrt::resume_background();
  try {
    writer.WriteBytes(bytes);
    co_await writer.StoreAsync();
  } catch (winrt::hresult_error const&) {
    // A dead link is reported by ReadAsync.
  }
  home.Post([attempt](BluetoothPlugin& self) { self.OnWriteDone(attempt); });
}

void BluetoothPlugin::OnWriteDone(uint64_t attempt) {
  if (attempt != attempt_) {
    return;
  }
  writing_ = false;
  PumpWrites();
}

// MARK: Events

void BluetoothPlugin::Emit(EncodableMap event) {
  if (sink_) {
    sink_->Success(EncodableValue(std::move(event)));
  }
}

void BluetoothPlugin::EmitStatus(const std::string& state,
                                 const std::optional<std::string>& name,
                                 const std::optional<std::string>& reason,
                                 const std::optional<Details>& details) {
  EncodableMap event{{EncodableValue("type"), EncodableValue("status")},
                     {EncodableValue("state"), EncodableValue(state)}};
  if (name) {
    event[EncodableValue("name")] = EncodableValue(*name);
  }
  if (reason) {
    event[EncodableValue("reason")] = EncodableValue(*reason);
  }
  if (details) {
    EncodableMap map;
    for (const auto& [key, value] : *details) {
      map[EncodableValue(key)] = EncodableValue(value);
    }
    event[EncodableValue("details")] = EncodableValue(std::move(map));
  }
  Emit(std::move(event));
}

void BluetoothPlugin::EmitReachable(bool value, const std::string& name) {
  EncodableMap event{{EncodableValue("type"), EncodableValue("reachable")},
                     {EncodableValue("value"), EncodableValue(value)}};
  if (!name.empty()) {
    event[EncodableValue("name")] = EncodableValue(name);
  }
  Emit(std::move(event));
}
