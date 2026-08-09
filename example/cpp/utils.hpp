
#pragma once

#include <cstdint>
#include <cstring>
#include <optional>
#include <string>

namespace utils {

  [[nodiscard]] constexpr std::uint32_t COMP_NUM_TO_OFFSET(const std::uint32_t comp_num)
  {
    return (comp_num << 8);
  }

  [[nodiscard]] constexpr std::uint32_t to_reg_address(const std::uint32_t comp_num, const std::uint32_t reg_addr)
  {
    return (comp_num << 8) | reg_addr;
  }

  template <typename T>
  [[nodiscard]] inline T get_bits(const T value, const std::size_t index_low, std::size_t index_high)
  {
    const std::size_t num_bits = index_high - index_low + 1;
    const T           mask     = (1 << (num_bits + 1)) - 1;
    return (value >> index_low) & mask;
  }

  template <typename T>
  [[nodiscard]] inline bool get_bit(const T value, const std::size_t index)
  {
    return (value >> index) & 0x01;
  }

  template <typename T>
  [[nodiscard]] inline T set_bit(const T value, const std::size_t index)
  {
    return value | (T{1} << index);
  }

  template <typename T>
  [[nodiscard]] inline T clear_bit(const T value, const std::size_t index)
  {
    return value & ~(T{1} << index);
  }

  [[nodiscard]] inline std::string string_error(const int errnum)
  {
    return std::string(std::strerror(errnum));
  }

  [[nodiscard]] std::string                  mac_to_string(const unsigned char addr[6]);
  [[nodiscard]] std::string                  ip_to_string(const std::uint32_t addr);

  /**
   * @brief Convert an IPv4 address in dot-decimal notation to an uint32
   * 
   * @param addr IPv4 address in dot-decimal notation
   * @return std::optional<std::uint32_t> IP address in network byte order, or nullopt if addr can't be converted
   */
  [[nodiscard]] std::optional<std::uint32_t> string_to_ip(const std::string &addr);
}; // namespace utils
