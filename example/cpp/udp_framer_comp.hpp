
#pragma once

#include "reg_interface.hpp"
#include "reg_comp.hpp"
#include <cstdint>


class udp_framer_comp : public reg_comp
{
public:
	udp_framer_comp(reg_interface& reg_interface, const std::uint32_t offset);

	struct config_t
	{
		std::uint32_t src_ip = 0;
		std::uint32_t dst_ip = 0;
		std::uint16_t src_port = 0;
		std::uint16_t dst_port = 0;
	};

	void reset();
	void set_enable(bool enable);
	bool get_idle() const;

	void set_config(const config_t& config);

// private:

	struct ip_header_t
	{
		std::uint8_t version : 4;
		std::uint8_t ihl : 4;
		std::uint8_t dscp : 6;
		std::uint8_t ecn : 2;
		std::uint16_t total_length;
		std::uint16_t id;
		std::uint8_t flags : 3;
		std::uint16_t fragment_offset : 13;
		std::uint8_t ttl;
		std::uint8_t protocol;
		std::uint16_t header_checksum;
		std::uint32_t src_address;
		std::uint32_t dest_address;
	} __attribute__((packed));

	static std::uint16_t calculate_checksum_seed(const std::uint32_t src_ip, const std::uint32_t dest_ip);

};
