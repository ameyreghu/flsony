#ifndef RUNNER_PLATFORM_DISPATCHER_H_
#define RUNNER_PLATFORM_DISPATCHER_H_

#include <windows.h>

#include <deque>
#include <functional>
#include <mutex>

// Runs tasks on the platform (UI) thread. WinRT completions and the socket
// read loop run on thread-pool threads, but Flutter channels may only be used
// from the platform thread, so they post their results here.
class PlatformDispatcher {
 public:
  // Posted to the Flutter window; FlutterWindow::MessageHandler calls Drain.
  static constexpr UINT kMessage = WM_APP + 1;

  explicit PlatformDispatcher(HWND window) : window_(window) {}

  // Any thread.
  void Post(std::function<void()> task);

  // Platform thread only.
  void Drain();

  // Drops queued and future tasks. Platform thread, before the window goes.
  void Close();

 private:
  HWND window_;
  std::mutex mutex_;
  std::deque<std::function<void()>> queue_;
  bool closed_ = false;
};

#endif  // RUNNER_PLATFORM_DISPATCHER_H_
