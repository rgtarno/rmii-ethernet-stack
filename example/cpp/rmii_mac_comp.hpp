
#pragma once

#include "mdio_comp.hpp"
#include "reg_interface.hpp"
#include "reg_comp.hpp"


class rmii_mac_comp : public reg_comp
{
public:
	rmii_mac_comp(reg_interface& reg_interface, const std::uint32_t offset);

	void set_rx_enable(bool enable);
	void set_tx_enable(bool enable);
	bool get_rx_enable() const;
	bool get_tx_enable() const;
	bool wait_for_idle(bool rx, bool tx);
	void reset();
	void set_destination_mac(const unsigned char* mac);
	void set_source_mac(const unsigned char* mac);
	void set_source_ip(std::uint32_t src_ip);

	void send_arp();

	std::uint32_t get_num_bytes_transmitted() const;
	std::uint32_t get_num_packets_transmitted() const;
	std::uint32_t get_num_bytes_received() const;
	std::uint32_t get_num_packets_received() const;
	std::uint16_t get_num_fcs_fails() const;
	std::uint16_t get_num_eth_drops() const;

	mdio_comp& mdio();

private:

	mdio_comp _mdio;
};

