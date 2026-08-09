
#include "rmii_mac_comp.hpp"

#include <chrono>
#include <cstring>
#include <ratio>
#include <stdexcept>
#include <thread>

#include "logging.hpp"
#include "utils.hpp"

namespace {

  const std::uint32_t rmii_mac_component_id          = 102;

  const std::uint32_t reg_num_mdio_control      = 1;
  const std::uint32_t reg_num_mdio_reset        = 2;
  const std::uint32_t reg_num_mdio_phy_addr     = 3;
  const std::uint32_t reg_num_mdio_reg_addr     = 4;
  const std::uint32_t reg_num_mdio_write_data   = 5;
  const std::uint32_t reg_num_mdio_read_data    = 6;
  const std::uint32_t reg_num_eth_control       = 7;
  const std::uint32_t reg_num_src_mac_upper     = 8;
  const std::uint32_t reg_num_src_mac_lower     = 9;
  const std::uint32_t reg_num_dst_mac_upper     = 10;
  const std::uint32_t reg_num_dst_mac_lower     = 11;
  const std::uint32_t reg_num_src_ip            = 12;
  const std::uint32_t reg_num_send_arp          = 13;

  const std::uint32_t reg_num_tx_bytes          = 14;
  const std::uint32_t reg_num_tx_packets        = 15;
  const std::uint32_t reg_num_rx_bytes          = 16;
  const std::uint32_t reg_num_rx_packets        = 17;
  const std::uint32_t reg_num_rx_bad_carriers   = 18;
  const std::uint32_t reg_num_rx_eth_drops      = 19;
  const std::uint32_t reg_num_rx_eth_fcs_fails  = 20;
  const std::uint32_t reg_num_mdio_send_count   = 21;
  const std::uint32_t reg_num_mdio_rx_count     = 22;
  const std::uint32_t reg_num_mdio_mac_rx_count = 23;
  const std::uint32_t reg_num_debug             = 24;
};

///////////////////////////////////////////////////////
rmii_mac_comp::rmii_mac_comp(reg_interface& reg_interface, const std::uint32_t offset) :
  reg_comp(reg_interface, rmii_mac_component_id, offset),
  _mdio(reg_interface, offset)
{
  if (!probe())
  {
    throw std::runtime_error("Failed to probe RMII MAC comp");
  }
}

///////////////////////////////////////////////////////
bool rmii_mac_comp::wait_for_idle(bool rx, bool tx)
{
  LOG_TRACE("Waiting for idle RX %d TX %d", rx, tx);
  int retries = 10;
  std::uint32_t reg = reg_read(reg_num_eth_control);
  bool is_idle = !rx || utils::get_bit(reg, 3);
  is_idle = is_idle && (!tx || utils::get_bit(reg, 1));

  while ((retries > 0) && !is_idle)
  {
    std::this_thread::sleep_for(std::chrono::microseconds(100));
    reg = reg_read(reg_num_eth_control);
    is_idle = !rx || utils::get_bit(reg, 3);
    is_idle = is_idle && (!tx || utils::get_bit(reg, 1));
    retries -= 1;
  }
  if (!is_idle)
  {
    LOG_WARN("MAC did not go idle");
  }
  return is_idle;
}

///////////////////////////////////////////////////////
void rmii_mac_comp::reset()
{
  LOG_TRACE("Reset RMII MAC");
  reg_write(reg_num_mdio_reset, 1);
}

///////////////////////////////////////////////////////
bool rmii_mac_comp::get_rx_enable() const
{
  return utils::get_bit(reg_read(reg_num_eth_control), 2);
}

///////////////////////////////////////////////////////
bool rmii_mac_comp::get_tx_enable() const
{
  return utils::get_bit(reg_read(reg_num_eth_control), 0);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::set_rx_enable(bool enable)
{
  LOG_TRACE("%s RMII MAC RX", (enable ? "Enabling" : "Disabling"));
  auto reg = reg_read(reg_num_eth_control);
  if (enable)
  {
    reg = utils::set_bit(reg, 2);
  }
  else
  {
    reg = utils::clear_bit(reg, 2);
  }
  reg_write(reg_num_eth_control, reg);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::set_tx_enable(bool enable)
{
  LOG_TRACE("%s RMII MAC TX", (enable ? "Enabling" : "Disabling"));
  auto reg = reg_read(reg_num_eth_control);
  if (enable)
  {
    reg = utils::set_bit(reg, 0);
  }
  else
  {
    reg = utils::clear_bit(reg, 0);
  }
  reg_write(reg_num_eth_control, reg);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::set_destination_mac(const unsigned char* mac)
{
  std::uint32_t lower = 0;
  std::memcpy(&lower, mac, sizeof(lower));
  LOG_TRACE("Destination mac lower = %08x", lower);
  reg_write(reg_num_dst_mac_lower, lower);
  std::uint32_t upper = 0;
  std::memcpy(&upper, mac+sizeof(lower), 2);
  LOG_TRACE("Destination mac upper = %08x", upper);
  reg_write(reg_num_dst_mac_upper, upper);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::set_source_mac(const unsigned char* mac)
{
  std::uint32_t lower = 0;
  std::memcpy(&lower, mac, sizeof(lower));
  LOG_TRACE("Source mac lower = %08x", lower);
  reg_write(reg_num_src_mac_lower, lower);
  std::uint32_t upper = 0;
  std::memcpy(&upper, mac+sizeof(lower), 2);
  LOG_TRACE("Source mac upper = %08x", upper);
  reg_write(reg_num_src_mac_upper, upper);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::set_source_ip(std::uint32_t src_ip)
{
  reg_write(reg_num_src_ip, src_ip);
}

///////////////////////////////////////////////////////
void rmii_mac_comp::send_arp()
{
  LOG_DEBUG("Sending ARP packet");
  reg_write(reg_num_send_arp, 1);

}

///////////////////////////////////////////////////////
mdio_comp& rmii_mac_comp::mdio()
{
  return _mdio;
}

///////////////////////////////////////////////////////
std::uint32_t rmii_mac_comp::get_num_bytes_transmitted() const
{
  return reg_read(reg_num_tx_bytes);
}

///////////////////////////////////////////////////////
std::uint32_t rmii_mac_comp::get_num_packets_transmitted() const
{
  return reg_read(reg_num_tx_packets);
}

///////////////////////////////////////////////////////
std::uint32_t rmii_mac_comp::get_num_bytes_received() const
{
  return reg_read(reg_num_rx_bytes);
}

///////////////////////////////////////////////////////
std::uint32_t rmii_mac_comp::get_num_packets_received() const
{
  return reg_read(reg_num_rx_packets);
}

///////////////////////////////////////////////////////
std::uint16_t rmii_mac_comp::get_num_fcs_fails() const
{
  return reg_read(reg_num_rx_eth_drops);
}

///////////////////////////////////////////////////////
std::uint16_t rmii_mac_comp::get_num_eth_drops() const
{
  return reg_read(reg_num_rx_eth_drops);
}
