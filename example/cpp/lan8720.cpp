
#include "lan8720.hpp"

#include <bitset>
#include <cstdint>

#include "utils.hpp"

namespace lan8720 {

///////////////////////////////////////////////////////
basic_control_reg_t::basic_control_reg_t(const std::uint16_t reg)
    : soft_reset{utils::get_bit(reg, 15)},
      loopback{utils::get_bit(reg, 14)},
      speed_select{utils::get_bit(reg, 13)},
      auto_negotiation_enabled{utils::get_bit(reg, 12)},
      power_down{utils::get_bit(reg, 11)},
      isolate{utils::get_bit(reg, 10)},
      restart_auto_negotiation{utils::get_bit(reg, 9)},
      duplex_mode{utils::get_bit(reg, 8)} {}

std::uint16_t basic_control_reg_t::to_u16() const
{
  std::bitset<16> ret{0};
  ret.set(15, soft_reset);
  ret.set(14, loopback);
  ret.set(13, speed_select);
  ret.set(12, auto_negotiation_enabled);
  ret.set(11, power_down);
  ret.set(10, isolate);
  ret.set(9, restart_auto_negotiation);
  ret.set(8, duplex_mode);
  return ret.to_ulong();
}

///////////////////////////////////////////////////////
basic_status_reg_t::basic_status_reg_t(const std::uint16_t reg)
    : ability_100_base_t4{utils::get_bit(reg, 15)},
      ability_100_base_tx_full_duplex{utils::get_bit(reg, 14)},
      ability_100_base_tx_half_duplex{utils::get_bit(reg, 13)},
      ability_10_base_t_full_duplex{utils::get_bit(reg, 12)},
      ability_10_base_t_half_duplex{utils::get_bit(reg, 11)},
      auto_negotiation_complete{utils::get_bit(reg, 5)},
      remote_fault{utils::get_bit(reg, 4)},
      auto_negotiate_ability{utils::get_bit(reg, 3)},
      link_status{utils::get_bit(reg, 2)},
      jabber_detected{utils::get_bit(reg, 1)},
      extended_capabilites{utils::get_bit(reg, 0)} {}

///////////////////////////////////////////////////////
special_status_reg_t::special_status_reg_t(const std::uint16_t reg)
    : auto_negotiation_done{utils::get_bit(reg, 12)},
      speed{speed_t::UNKNOWN} {
  const std::uint16_t speed_bits = utils::get_bits(reg, 2, 4);
  switch (speed_bits) {
  case 1: {
    speed = speed_t::TEN_BASE_T_HALF_DUPLEX;
    break;
  }
  case 2: {
    speed = speed_t::HUNDRED_BASE_TX_HALF_DUPLEX;
    break;
  }
  case 5: {
    speed = speed_t::TEN_BASE_T_FULL_DUPLEX;
    break;
  }
  case 6: {
    speed = speed_t::HUNDRED_BASE_TX_FULL_DUPLEX;
    break;
  }
  default: {
    speed = speed_t::UNKNOWN;
  }
  }
}

std::string speed_t_to_string(const speed_t speed) {
  switch (speed) {
  case speed_t::UNKNOWN:
    return std::string("UNKNOWN");
  case speed_t::TEN_BASE_T_HALF_DUPLEX:
    return std::string("10BASE-T Half-duplex");
  case speed_t::TEN_BASE_T_FULL_DUPLEX:
    return std::string("10BASE-T");
  case speed_t::HUNDRED_BASE_TX_HALF_DUPLEX:
    return std::string("100BASE-TX Half-duplex");
  case speed_t::HUNDRED_BASE_TX_FULL_DUPLEX:
    return std::string("100BASE-TX");
  }
  return std::string("UNKNOWN");
}

} // namespace lan8720