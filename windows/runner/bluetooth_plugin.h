#ifndef RUNNER_BLUETOOTH_PLUGIN_H_
#define RUNNER_BLUETOOTH_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Storage.Streams.h>

#include <cstdint>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "platform_dispatcher.h"

// Byte pipe between Dart and Sony's proprietary RFCOMM service
// ("Serial HPC"). All protocol logic lives in Dart; see lib/core and
// docs/platform-bridge.md.
//
// State is only touched on the platform thread. The WinRT work runs in
// coroutines on the thread pool, which post their results back through the
// PlatformDispatcher. Every connection gets a new |attempt_| number, so
// results from a connection that has since been closed are ignored.
class BluetoothPlugin : public std::enable_shared_from_this<BluetoothPlugin> {
 public:
  static std::shared_ptr<BluetoothPlugin> Register(
      flutter::BinaryMessenger* messenger,
      std::shared_ptr<PlatformDispatcher> dispatcher);

  explicit BluetoothPlugin(std::shared_ptr<PlatformDispatcher> dispatcher);

  // Closes the connection and stops reporting. Platform thread.
  void Shutdown();

 private:
  using BluetoothDevice = winrt::Windows::Devices::Bluetooth::BluetoothDevice;
  using StreamSocket = winrt::Windows::Networking::Sockets::StreamSocket;
  using DataWriter = winrt::Windows::Storage::Streams::DataWriter;
  using Details = std::map<std::string, std::string>;

  // Posts a task back to this plugin on the platform thread, if it still
  // exists. Safe to copy into thread-pool code.
  struct Home {
    std::weak_ptr<BluetoothPlugin> plugin;
    std::shared_ptr<PlatformDispatcher> dispatcher;
    void Post(std::function<void(BluetoothPlugin&)> task) const;
  };

  Home home();
  void Attach(flutter::BinaryMessenger* messenger);
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        flutter::MethodResult<flutter::EncodableValue>& result);

  void StartMonitoring();
  void Connect();
  void Disconnect();
  void Send(const std::vector<uint8_t>& bytes);

  // Thread-pool work.
  static winrt::Windows::Foundation::IAsyncOperation<BluetoothDevice>
  FindHeadphonesAsync();
  static winrt::fire_and_forget MonitorAsync(Home home);
  static winrt::fire_and_forget ConnectAsync(Home home, uint64_t attempt);
  static winrt::fire_and_forget ReadAsync(Home home, uint64_t attempt,
                                          StreamSocket socket);
  static winrt::fire_and_forget WriteAsync(Home home, uint64_t attempt,
                                           DataWriter writer,
                                           std::vector<uint8_t> bytes);

  // Results, back on the platform thread.
  void OnMonitorDevice(BluetoothDevice device);
  void OnConnecting(uint64_t attempt, const std::string& name);
  void OnConnectFailed(uint64_t attempt, const std::string& name,
                       const std::string& reason, BluetoothDevice device);
  void OnConnected(uint64_t attempt, StreamSocket socket,
                   const std::string& name, const Details& details,
                   BluetoothDevice device);
  void OnData(uint64_t attempt, const std::vector<uint8_t>& bytes);
  void OnClosed(uint64_t attempt);
  void OnWriteDone(uint64_t attempt);

  void Watch(BluetoothDevice device);
  void PumpWrites();
  void CloseSocket();

  void Emit(flutter::EncodableMap event);
  void EmitStatus(const std::string& state,
                  const std::optional<std::string>& name = std::nullopt,
                  const std::optional<std::string>& reason = std::nullopt,
                  const std::optional<Details>& details = std::nullopt);
  void EmitReachable(bool value, const std::string& name);

  std::shared_ptr<PlatformDispatcher> dispatcher_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;

  // Reachability.
  bool monitoring_ = false;
  BluetoothDevice device_{nullptr};
  BluetoothDevice::ConnectionStatusChanged_revoker status_changed_;

  // RFCOMM connection.
  uint64_t attempt_ = 0;
  bool connecting_ = false;
  StreamSocket socket_{nullptr};
  DataWriter writer_{nullptr};
  std::deque<std::vector<uint8_t>> outbox_;
  bool writing_ = false;
};

#endif  // RUNNER_BLUETOOTH_PLUGIN_H_
