
#include "utils.hpp"

#include <arpa/inet.h>
#include <sstream>
#include <sys/socket.h>

namespace utils {

  std::string mac_to_string(const unsigned char addr[6])
  {
    std::ostringstream oss;
    oss << std::hex << static_cast<int>(addr[0]) << ":";
    oss << std::hex << static_cast<int>(addr[1]) << ":";
    oss << std::hex << static_cast<int>(addr[2]) << ":";
    oss << std::hex << static_cast<int>(addr[3]) << ":";
    oss << std::hex << static_cast<int>(addr[4]) << ":";
    oss << std::hex << static_cast<int>(addr[5]);
    return oss.str();
  }

  std::string ip_to_string(const std::uint32_t addr)
  {
    std::ostringstream oss;
    oss << std::dec << ((addr >> 24) & 0xFF) << ".";
    oss << std::dec << ((addr >> 16) & 0xFF) << ".";
    oss << std::dec << ((addr >> 8) & 0xFF) << ".";
    oss << std::dec << ((addr >> 0) & 0xFF) << ":";
    return oss.str();
  }

  std::optional<std::uint32_t> string_to_ip(const std::string &addr)
  {
    std::uint32_t ret = 0;
    if (inet_pton(AF_INET, addr.c_str(), &ret) != 1) {
      return std::nullopt;
    }
    return ret;
  }

} // namespace utils