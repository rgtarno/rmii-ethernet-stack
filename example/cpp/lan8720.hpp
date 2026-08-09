
#pragma once

#include <cstdint>
#include <string>

namespace lan8720 {

enum class speed_t : std::uint8_t {
  UNKNOWN,
  TEN_BASE_T_HALF_DUPLEX,
  TEN_BASE_T_FULL_DUPLEX,
  HUNDRED_BASE_TX_HALF_DUPLEX,
  HUNDRED_BASE_TX_FULL_DUPLEX
};

std::string speed_t_to_string(const speed_t speed);

struct basic_control_reg_t {

  basic_control_reg_t(const std::uint16_t reg);

  std::uint16_t to_u16() const;

  static constexpr std::uint16_t REG_NUM = 0;

  bool soft_reset{false};
  bool loopback{false};
  bool speed_select{false};
  bool auto_negotiation_enabled{false};
  bool power_down{false};
  bool isolate{false};
  bool restart_auto_negotiation{false};
  bool duplex_mode{false};
};

struct basic_status_reg_t {

  basic_status_reg_t(const std::uint16_t reg);

  static constexpr std::uint16_t REG_NUM = 1;

  bool ability_100_base_t4{false};
  bool ability_100_base_tx_full_duplex{false};
  bool ability_100_base_tx_half_duplex{false};
  bool ability_10_base_t_full_duplex{false};
  bool ability_10_base_t_half_duplex{false};
  bool auto_negotiation_complete{false};
  bool remote_fault{false};
  bool auto_negotiate_ability{false};
  bool link_status{false};
  bool jabber_detected{false};
  bool extended_capabilites{false};
};

struct special_status_reg_t {

  special_status_reg_t(const std::uint16_t reg);

  static constexpr std::uint16_t REG_NUM = 31;

  bool auto_negotiation_done{false};
  speed_t speed{speed_t::UNKNOWN};
};

} // namespace lan8720