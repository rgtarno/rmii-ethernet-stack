
#pragma once

#include <atomic>
#include <stdio.h>

enum class log_level_t {
  TRACE = 0,
  DEBUG,
  INFO,
  WARN,
  ERROR
};

extern std::atomic<log_level_t> global_log_level;

/* Helpers to run basename() on the __FILE__ string literal at compile time */
template <std::size_t Len>
consteval const char *baseNameImpl(const char (&str)[Len], std::size_t pos)
{
  return pos == 0 ? str : (str[pos] == '/' || str[pos] == '\\') ? str + pos + 1
                                                                : baseNameImpl(str, --pos);
}
template <std::size_t Len>
consteval const char *baseName(const char (&str)[Len])
{
  return baseNameImpl(str, Len - 1);
}

#define STRING(s) #s

#define COLOUR_TRACE "\033[0;36m"
#define COLOUR_DEBUG "\033[0;35m"
#define COLOUR_INFO "\033[0;32m"
#define COLOUR_WARN "\033[0;33m"
#define COLOUR_ERROR "\033[0;31m"
#define COLOUR_RESET "\033[0m"

#define LOG_IMPL(LEVEL, ...)                                                                   \
  if (global_log_level <= log_level_t::LEVEL) {                                                \
    flockfile(stderr);                                                                         \
    fprintf(stderr, COLOUR_##LEVEL "%s:%d " STRING(LEVEL) ": ", baseName(__FILE__), __LINE__); \
    fprintf(stderr, __VA_ARGS__);                                                              \
    fprintf(stderr, COLOUR_RESET "\n");                                                        \
    funlockfile(stderr);                                                                       \
  }

#define LOG_TRACE(...) LOG_IMPL(TRACE, __VA_ARGS__)
#define LOG_DEBUG(...) LOG_IMPL(DEBUG, __VA_ARGS__)
#define LOG_INFO(...) LOG_IMPL(INFO, __VA_ARGS__)
#define LOG_WARN(...) LOG_IMPL(WARN, __VA_ARGS__)
#define LOG_ERROR(...) LOG_IMPL(ERROR, __VA_ARGS__)