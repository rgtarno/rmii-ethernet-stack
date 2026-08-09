
#include "udp_framer_comp.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <unistd.h>
#include <cassert>

#include "logging.hpp"
#include "utils.hpp"


namespace {
  const std::uint32_t udp_ip_framer_component_id             = 105;

  const std::uint32_t reg_num_control              = 1;
  const std::uint32_t reg_num_src_port             = 2;
  const std::uint32_t reg_num_dst_port             = 3;
  const std::uint32_t reg_num_src_addr             = 4;
  const std::uint32_t reg_num_dst_addr             = 5;
  const std::uint32_t reg_num_ip_checksum_seed     = 6;
};


///////////////////////////////////////////////////////
udp_framer_comp::udp_framer_comp(reg_interface& reg_interface, const std::uint32_t offset) :
	reg_comp(reg_interface, udp_ip_framer_component_id, offset)
{
	if (!probe())
	{
		throw std::runtime_error("Failed to probe UDP IP framercomp");
	}
};

///////////////////////////////////////////////////////
void udp_framer_comp::reset()
{
	LOG_TRACE("Reset UDP framer");
	const auto reg = reg_read(reg_num_control);
	reg_write(reg_num_control, utils::set_bit(reg, 2));
	usleep(100);
	reg_write(reg_num_control, utils::clear_bit(reg, 2));
}

///////////////////////////////////////////////////////
void udp_framer_comp::set_enable(bool enable)
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
bool udp_framer_comp::get_idle() const
{
	return utils::get_bit(reg_read(reg_num_control), 1);
}

///////////////////////////////////////////////////////
void udp_framer_comp::set_config(const config_t& config)
{
	LOG_DEBUG("Configure UDP framer. Source = %s:%u. Destination = %s:%u", utils::ip_to_string(config.src_ip).c_str(), config.src_port, utils::ip_to_string(config.dst_ip).c_str(), config.dst_port);
	LOG_TRACE("src_ip = %08x", config.src_ip);
	LOG_TRACE("dst_ip = %08x", config.dst_ip);
	reg_write(reg_num_src_port, config.src_port);
	reg_write(reg_num_dst_port, config.dst_port);
	reg_write(reg_num_src_addr, config.src_ip);
	reg_write(reg_num_dst_addr, config.dst_ip);
	reg_write(reg_num_ip_checksum_seed, calculate_checksum_seed(config.src_ip, config.dst_ip));
}

///////////////////////////////////////////////////////
std::uint16_t udp_framer_comp::calculate_checksum_seed(const std::uint32_t src_ip, const std::uint32_t dest_ip)
{
	constexpr std::size_t IP_HEADER_LENGTH_BYTES = 20;
	constexpr std::size_t IP_HEADER_LENGTH_U16 = IP_HEADER_LENGTH_BYTES/2;
	unsigned char header_bytes[IP_HEADER_LENGTH_BYTES] = {};
	std::memset(header_bytes, 0, IP_HEADER_LENGTH_BYTES);

	header_bytes[0] = 0x45; // Version and IHL
	header_bytes[1] = 0; // DSCP & ECN
	header_bytes[2] = 0; // Total length
	header_bytes[3] = 0; // Total length
	header_bytes[4] = 0; // ID
	header_bytes[5] = 0; // ID
	header_bytes[6] = 0; // Flags & Fragment offset
	header_bytes[7] = 0; // Fragment offset
	header_bytes[8] = 0x80; // TTL
	header_bytes[9] = 0x11; // Protocol
	header_bytes[10] = 0; // Header checksum
	header_bytes[11] = 0; // Header checksum
	header_bytes[12] = (src_ip >> 24) & 0xFF;
	header_bytes[13] = (src_ip >> 16) & 0xFF;
	header_bytes[14] = (src_ip >> 8) & 0xFF;
	header_bytes[15] = (src_ip >> 0) & 0xFF;
	header_bytes[16] = (dest_ip >> 24) & 0xFF;
	header_bytes[17] = (dest_ip >> 16) & 0xFF;
	header_bytes[18] = (dest_ip >> 8) & 0xFF;
	header_bytes[19] = (dest_ip >> 0) & 0xFF;

	std::uint16_t header_words[IP_HEADER_LENGTH_U16];
	std::memset(header_words, 0, IP_HEADER_LENGTH_U16*sizeof(uint16_t));


	for (std::size_t i = 0; i < IP_HEADER_LENGTH_BYTES; i+=2)
	{
		const std::uint16_t a = header_bytes[i];
		const std::uint16_t b = header_bytes[i+1];
		const std::uint16_t c = (a << 8) | b;
		header_words[i/2] = c;
	}

	std::uint32_t seed = 0;
	for (std::size_t i = 0; i < IP_HEADER_LENGTH_U16; ++i)
	{
		seed += header_words[i];
		if (seed > 0xFFFF)
		{
			seed = seed & 0xFFFF;
			seed += 1;
		}
	}

	assert(seed <= 0xFFFF);

	return static_cast<std::uint16_t>(seed);
}
