
#include "udp_deframer_comp.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <unistd.h>
#include <cassert>

#include "logging.hpp"
#include "utils.hpp"


namespace {
  const std::uint32_t udp_ip_framer_component_id              = 106;

  const std::uint32_t reg_num_control              = 1;
  const std::uint32_t reg_num_src_port             = 2;
  const std::uint32_t reg_num_dst_port             = 3;
  const std::uint32_t reg_num_dst_addr             = 4;
  const std::uint32_t reg_num_broadcast_addr       = 5;
	const std::uint32_t reg_num_valid_pkt_count			 = 6;
	const std::uint32_t reg_num_dropped_pkt_count		 = 7;
};


///////////////////////////////////////////////////////
udp_deframer_comp::udp_deframer_comp(reg_interface& reg_interface, const std::uint32_t offset) :
	reg_comp(reg_interface, udp_ip_framer_component_id, offset)
{
	if (!probe())
	{
		throw std::runtime_error("Failed to probe UDP IP framercomp");
	}
};

///////////////////////////////////////////////////////
void udp_deframer_comp::reset()
{
	LOG_TRACE("Reset UDP framer");
	const auto reg = reg_read(reg_num_control);
	reg_write(reg_num_control, utils::set_bit(reg, 2));
	usleep(100);
	reg_write(reg_num_control, utils::clear_bit(reg, 2));
}

///////////////////////////////////////////////////////
void udp_deframer_comp::set_enable(bool enable)
{
	LOG_TRACE("%s UDP framer", (enable ? "Enabling" : "Disabling"));
	auto reg = reg_read(reg_num_control);
	if (enable)
	{
		reg = utils::set_bit(reg, 0);
	}
	else
	{
		reg = utils::clear_bit(reg, 0);
	}
	reg_write(reg_num_control, reg);
}

///////////////////////////////////////////////////////
bool udp_deframer_comp::get_idle() const
{
	return utils::get_bit(reg_read(reg_num_control), 1);
}

///////////////////////////////////////////////////////
void udp_deframer_comp::set_config(const config_t& config)
{
	LOG_DEBUG("Configure UDP deframer. IP = %s Broadcast IP = %s. Port = %u", utils::ip_to_string(config.ip).c_str(), utils::ip_to_string(config.broadcast_ip).c_str(), config.port);
	reg_write(reg_num_dst_port, config.port);
	reg_write(reg_num_dst_addr, config.ip);
	reg_write(reg_num_broadcast_addr, config.broadcast_ip);
}

///////////////////////////////////////////////////////
std::uint16_t udp_deframer_comp::get_valid_packet_count() const
{
	return reg_read(reg_num_valid_pkt_count);
}
///////////////////////////////////////////////////////
std::uint16_t udp_deframer_comp::get_dropped_packet_count() const
{
	return reg_read(reg_num_dropped_pkt_count);
}