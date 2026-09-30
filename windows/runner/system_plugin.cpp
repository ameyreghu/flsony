#include "system_plugin.h"

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>

#include <utility>

using flutter::EncodableValue;
using winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSessionManager;
using winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSessionPlaybackStatus;

SystemPlugin::SystemPlugin(flutter::BinaryMessenger* messenger,
                           std::shared_ptr<PlatformDispatcher> dispatcher) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "flsony/system", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [dispatcher](const flutter::MethodCall<EncodableValue>& call,
                   std::unique_ptr<Result> result) {
        if (call.method_name() == "pauseMedia") {
          PauseMediaAsync(dispatcher, std::shared_ptr<Result>(std::move(result)));
        } else if (call.method_name() == "prepareMediaPause") {
          // Media control needs no permission on Windows.
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

// Pauses every media session that is playing, through the system media
// transport controls. TryPauseAsync never starts playback, and this covers
// browsers as well as media apps.
winrt::fire_and_forget SystemPlugin::PauseMediaAsync(
    std::shared_ptr<PlatformDispatcher> dispatcher,
    std::shared_ptr<Result> result) {
  co_await winrt::resume_background();
  bool paused = false;
  try {
    auto manager =
        co_await GlobalSystemMediaTransportControlsSessionManager::RequestAsync();
    for (auto const& session : manager.GetSessions()) {
      try {
        if (session.GetPlaybackInfo().PlaybackStatus() ==
                GlobalSystemMediaTransportControlsSessionPlaybackStatus::
                    Playing &&
            co_await session.TryPauseAsync()) {
          paused = true;
        }
      } catch (winrt::hresult_error const&) {
        // Keep going with the other sessions.
      }
    }
  } catch (winrt::hresult_error const&) {
  }
  dispatcher->Post([result, paused] { result->Success(EncodableValue(paused)); });
}
