
#pragma once

#include <chrono>

template <typename Clock = std::chrono::high_resolution_clock>
class timer {

public:
  timer()
      : _start_time{},
        _expire_time{},
        _started{false} {};

  timer(const typename Clock::duration &timeout_duration)
      : timer()
  {
    restart(timeout_duration);
  }

  [[nodiscard]] inline bool expired()
  {
    const bool expired = !_started || (Clock::now() >= _expire_time);
    return expired;
  }

  template <typename Rep = typename Clock::duration::rep, typename Units = typename Clock::duration>
  [[nodiscard]] inline Rep elapsed()
  {
    const auto counted_time = std::chrono::duration_cast<Units>(Clock::now() - _start_time).count();
    return static_cast<Rep>(counted_time);
  }

  inline void restart(const typename Clock::duration &timeout_duration)
  {
    _started     = true;
    _start_time  = Clock::now();
    _expire_time = _start_time + timeout_duration;
  }

private:
  typename Clock::time_point _start_time;
  typename Clock::time_point _expire_time;
  bool                       _started;
};

using precise_timer   = timer<>;
using system_timer    = timer<std::chrono::system_clock>;
using monotonic_timer = timer<std::chrono::steady_clock>;