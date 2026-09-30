#include "platform_dispatcher.h"

#include <utility>

void PlatformDispatcher::Post(std::function<void()> task) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (closed_) {
    return;
  }
  // One message per batch: Drain empties the whole queue.
  const bool was_empty = queue_.empty();
  queue_.push_back(std::move(task));
  if (was_empty) {
    ::PostMessage(window_, kMessage, 0, 0);
  }
}

void PlatformDispatcher::Drain() {
  std::deque<std::function<void()>> tasks;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    tasks.swap(queue_);
  }
  for (auto& task : tasks) {
    task();
  }
}

void PlatformDispatcher::Close() {
  std::lock_guard<std::mutex> lock(mutex_);
  closed_ = true;
  queue_.clear();
}
