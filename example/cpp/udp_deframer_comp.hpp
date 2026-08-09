
#pragma once

#include "reg_interface.hpp"
#include "reg_comp.hpp"
#include <cstdint>


class udp_deframer_comp : public reg_comp
{
public:
	udp_deframer_comp(reg_interface& reg_interface, const std::uint32_t offset);

	struct config_t
	{
		std::uint32_t ip = 0;
		std::uint32_t broadcast_ip = 0;
		std::uint16_t port = 0;
	};


	void reset();
	void set_enable(bool enable);
	bool get_idle() const;
  void set_config(const config_t& config);

	std::uint16_t get_valid_packet_count() const;
	std::uint16_t get_dropped_packet_count() const;
};
