#pragma once

#include <chrono>
#include <cmath>
#include <thread>

#if defined(__x86_64__) || defined(_M_X64)
#include <emmintrin.h>
#endif

class token_bucket
{
public:
  token_bucket() :
      m_next_time(std::chrono::steady_clock::now())
  {
  }

  void set_rate(double tokens_per_sec)
  {
    if (tokens_per_sec > 0.0)
    {
      m_interval = std::chrono::nanoseconds(
          static_cast<int64_t>(std::round(1.0e9 / tokens_per_sec)));
    }
  }

  void acquire()
  {
    auto now = std::chrono::steady_clock::now();

    // Prevent drift: If we fell behind by more than 5 intervals, resync schedule
    if (now - m_next_time > m_interval * 5)
    {
      m_next_time = now;
    }

    // Schedule the slot for the CURRENT token
    std::chrono::steady_clock::time_point target_time = m_next_time;

    // Advance schedule for the NEXT token immediately
    m_next_time += m_interval;

    // If target_time is already in the past, no waiting needed
    if (now >= target_time)
    {
      return;
    }

    // --- HYBRID PACING ---
    auto                                remaining = std::chrono::duration_cast<std::chrono::microseconds>(target_time - now);
    constexpr std::chrono::microseconds SLEEP_THRESHOLD(50);

    if (remaining > SLEEP_THRESHOLD)
    {
      // Sleep until 20us before target_time to yield CPU
      std::this_thread::sleep_until(target_time - std::chrono::microseconds(20));
    }

    // Spin-lock for remaining high-precision duration
    while (std::chrono::steady_clock::now() < target_time)
    {
#if defined(__x86_64__) || defined(_M_X64)
      _mm_pause();
#elif defined(__aarch64__) || defined(_M_ARM64)
      asm volatile("yield" ::: "memory");
#endif
    }
  }

private:
  std::chrono::steady_clock::time_point m_next_time;
  std::chrono::nanoseconds              m_interval{0};
};