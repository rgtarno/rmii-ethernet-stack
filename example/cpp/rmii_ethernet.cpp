
#include "rmii_ethernet.hpp"
#include "lan8720.hpp"
#include "logging.hpp"
#include "utils.hpp"
#include <chrono>
#include <cstdint>
#include <optional>
#include <thread>


///////////////////////////////////////////////////////
rmii_ethernet::rmii_ethernet(reg_interface& reg_interface, const std::uint32_t offset) :
_mac(reg_interface, offset),
_phy_address{0}
{

}

///////////////////////////////////////////////////////
bool rmii_ethernet::init(bool auto_negotiate)
{
    _mac.set_rx_enable(false);
    _mac.set_tx_enable(false);
    _mac.reset();
    _mac.set_rx_enable(true);
    _mac.set_tx_enable(true);
    _mac.wait_for_idle(true, true);


    if (!find_phy_address(_phy_address))
    {
        LOG_ERROR("Failed to find PHY");
        return false;
    }

    if (auto_negotiate && !phy_autonegotiate())
    {
        LOG_ERROR("Failed to auto-negotiate");
        return false;
    }
    LOG_INFO("PHY auto-negotiation complete");

    return true;
}

///////////////////////////////////////////////////////
bool rmii_ethernet::phy_autonegotiate()
{
    if (is_autonegotiation_complete())
    {
        LOG_TRACE("Auto-negotiation is already complete");
        return true;
    }
    LOG_TRACE("Attempting to auto-negotiate");
    lan8720::basic_control_reg_t write_val(0);
    write_val.auto_negotiation_enabled = true;
    write_val.restart_auto_negotiation = true;
    if (!_mac.mdio().mdio_write(_phy_address, lan8720::basic_control_reg_t::REG_NUM, write_val.to_u16()))
    {
        LOG_ERROR("Failed to write to PHY basic control register");
        return false;
    }

    int retries = 5;

    while ((retries > 0) && (!is_autonegotiation_complete()))
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return is_autonegotiation_complete();
}

///////////////////////////////////////////////////////
bool rmii_ethernet::is_autonegotiation_complete()
{
    std::uint16_t read_data;
    if (!_mac.mdio().mdio_read(_phy_address, lan8720::special_status_reg_t::REG_NUM, &read_data))
    {
        LOG_ERROR("Failed to read from PHY special status register");
        return false;
    }

    const auto special_status_reg = lan8720::special_status_reg_t(read_data);
    return special_status_reg.auto_negotiation_done;
}

///////////////////////////////////////////////////////
void rmii_ethernet::send_arp()
{
    _mac.send_arp();
}

///////////////////////////////////////////////////////
void rmii_ethernet::set_source_mac(const unsigned char addr[6])
{
    LOG_INFO("Setting source MAC address to %s", utils::mac_to_string(addr).c_str());
    const bool was_tx_enabled = _mac.get_tx_enable();
    const bool was_rx_enabled = _mac.get_tx_enable();

    _mac.set_rx_enable(false);
    _mac.set_tx_enable(false);
    _mac.wait_for_idle(was_rx_enabled, was_tx_enabled);

    _mac.set_source_mac(addr);

    _mac.set_tx_enable(was_tx_enabled);
    _mac.set_rx_enable(was_rx_enabled);
}

///////////////////////////////////////////////////////
void rmii_ethernet::set_destination_mac(const unsigned char addr[6])
{
    LOG_INFO("Setting destination MAC address to %s", utils::mac_to_string(addr).c_str());
    const bool was_enabled = _mac.get_tx_enable();
    if (was_enabled)
    {
        _mac.set_tx_enable(false);
        _mac.wait_for_idle(false, true);
    }
    _mac.set_destination_mac(addr);
    if (was_enabled)
    {
        _mac.set_tx_enable(true);
    }
}

///////////////////////////////////////////////////////
void rmii_ethernet::set_source_ip(std::uint32_t ip)
{
    _mac.set_source_ip(ip);
}

///////////////////////////////////////////////////////
bool rmii_ethernet::find_phy_address(std::uint16_t& phy_addr)
{
    for (std::uint16_t i = 0; i < 31; ++i)
    {
        std::uint16_t read_data;
        if (!_mac.mdio().mdio_read(i, 0, &read_data))
        {
            LOG_WARN("Failed to read PHY control reg");
            return false;
        }
        if (read_data != 0xFFFF)
        {
            LOG_TRACE("Found PHY @ address %u", i);
            phy_addr = i;
            return true;
        }
    }

    return false;
}

///////////////////////////////////////////////////////
rmii_ethernet::status_t rmii_ethernet::get_status()
{
    status_t ret;
    std::uint16_t read_data;
    if (!_mac.mdio().mdio_read(_phy_address, lan8720::basic_status_reg_t::REG_NUM, &read_data))
    {
        LOG_ERROR("Failed to read basic status register");
        return ret;
    }
    const auto status_reg = lan8720::basic_status_reg_t(read_data);
    ret.link_up = status_reg.link_status;

    if (!_mac.mdio().mdio_read(_phy_address, lan8720::special_status_reg_t::REG_NUM, &read_data))
    {
        LOG_ERROR("Failed to read special status register");
        return ret;
    }
    const auto special_status_reg = lan8720::special_status_reg_t(read_data);
    ret.link_speed = special_status_reg.speed;
    ret.bytes_sent = _mac.get_num_bytes_transmitted();
    ret.packets_sent = _mac.get_num_packets_transmitted();
    ret.bytes_received = _mac.get_num_bytes_received();
    ret.packets_received = _mac.get_num_packets_received();
    ret.fcs_fails = _mac.get_num_fcs_fails();
    ret.ethernet_packets_dropped = _mac.get_num_eth_drops();

    return ret;
}

///////////////////////////////////////////////////////
void rmii_ethernet::dump_phy_regs()
{
    auto read_phy_reg = [](mdio_comp& mdio, std::uint16_t phy_addr, std::uint16_t reg_addr)
    {
        std::uint16_t read_data;
        bool success = mdio.mdio_read(phy_addr, reg_addr, &read_data);
        if (!success)
        {
            LOG_WARN("Failed to read from PHY register %u", reg_addr);
            return std::optional<std::uint16_t>();
        }

        LOG_TRACE("Read 0x%04x from reg %u", read_data, reg_addr);
        return std::optional<std::uint16_t>(read_data);
    };


    auto ret = read_phy_reg(_mac.mdio(), _phy_address, lan8720::basic_control_reg_t::REG_NUM);
	if (ret)
	{
		const auto reg = lan8720::basic_control_reg_t(ret.value());
		LOG_DEBUG("Auto negotiation enabled : %s", (reg.auto_negotiation_enabled ? "Yes" : "No"));
		LOG_DEBUG("Duplex mode              : %s", reg.duplex_mode ? "Full" : "Half");
	}

    ret = read_phy_reg(_mac.mdio(), _phy_address, lan8720::basic_status_reg_t::REG_NUM);
	if (ret)
	{
		const auto reg = lan8720::basic_status_reg_t(ret.value());
		LOG_DEBUG("Link status             = %s", (reg.link_status ? "Up" : "Down"));
		LOG_DEBUG("Auto negotiate ability  = %s", (reg.auto_negotiate_ability ? "Yes" : "No"));
		LOG_DEBUG("Remote fault            = %s", (reg.remote_fault ? "Yes" : "No"));
		LOG_DEBUG("Auto negotiate complete = %s", (reg.auto_negotiation_complete ? "Yes" : "No"));
		LOG_DEBUG("Jabber                  = %s", (reg.jabber_detected ? "Yes" : "No"));
		LOG_DEBUG("100BASE-TX Full Duplex  = %s", (reg.ability_100_base_tx_full_duplex ? "Yes" : "No"));
		LOG_DEBUG("100BASE-TX              = %s", (reg.ability_100_base_tx_half_duplex ? "Yes" : "No"));
		LOG_DEBUG("10BASE-T Full Duplex    = %s", (reg.ability_10_base_t_full_duplex ? "Yes" : "No"));
		LOG_DEBUG("10BASE-T                = %s", (reg.ability_10_base_t_half_duplex ? "Yes" : "No")); 
	}

	ret = read_phy_reg(_mac.mdio(), _phy_address, lan8720::special_status_reg_t::REG_NUM);
	if (ret)
	{
		const auto reg = lan8720::special_status_reg_t(ret.value());
		LOG_DEBUG("Auto negotiation complete : %d", reg.auto_negotiation_done);
		LOG_DEBUG("Link speed                : %s", lan8720::speed_t_to_string(reg.speed).c_str());
	}
}