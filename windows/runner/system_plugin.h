#ifndef RUNNER_SYSTEM_PLUGIN_H_
#define RUNNER_SYSTEM_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <winrt/Windows.Foundation.h>

#include <memory>

#include "platform_dispatcher.h"

// Non-Bluetooth OS integrations for the Dart side (channel `flsony/system`).
class SystemPlugin {
 public:
  SystemPlugin(flutter::BinaryMessenger* messenger,
               std::shared_ptr<PlatformDispatcher> dispatcher);

 private:
  using Result = flutter::MethodResult<flutter::EncodableValue>;

  static winrt::fire_and_forget PauseMediaAsync(
      std::shared_ptr<PlatformDispatcher> dispatcher,
      std::shared_ptr<Result> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SYSTEM_PLUGIN_H_
