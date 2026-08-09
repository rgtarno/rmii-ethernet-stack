
#include "mdio_comp.hpp"

#include <cstdio>
#include <unistd.h>

#include "utils.hpp"
#include "logging.hpp"


namespace  {
	const std::uint32_t mdio_component_id          = 101;
	const std::uint32_t reg_mdio_comp_control      = 1;
	const std::uint32_t reg_mdio_comp_phy_addr     = 3;
	const std::uint32_t reg_mdio_comp_reg_addr     = 4;
	const std::uint32_t reg_mdio_comp_write_data   = 5;
	const std::uint32_t reg_mdio_comp_read_data    = 6;
};


///////////////////////////////////////////////////////
mdio_comp::mdio_comp(reg_interface& reg_interface, const std::uint32_t offset) :
	reg_comp(reg_interface, mdio_component_id, offset)
{
};


///////////////////////////////////////////////////////
bool mdio_comp::mdio_read(std::uint16_t phy_address, std::uint16_t reg_address, std::uint16_t* return_data)
{
	LOG_TRACE("MDIO read from PHY %u REG %u", phy_address, reg_address);
	reg_write(reg_mdio_comp_phy_addr, phy_address);
	reg_write(reg_mdio_comp_reg_addr, reg_address);
	reg_write(reg_mdio_comp_control, 0);
	const bool complete = wait_for_op_complete();
	if (complete && return_data)
	{
		*return_data = static_cast<std::uint16_t>(reg_read(reg_mdio_comp_read_data) & 0xFFFF);
	}
	return complete;
}

///////////////////////////////////////////////////////
bool mdio_comp::mdio_write(std::uint16_t phy_address, std::uint16_t reg_address, std::uint16_t write_data)
{
	LOG_TRACE("MDIO WRITE to PHY %u REG %u DATA 0x%04x", phy_address, reg_address, write_data);
	reg_write(reg_mdio_comp_phy_addr, phy_address);
	reg_write(reg_mdio_comp_reg_addr, reg_address);
	reg_write(reg_mdio_comp_write_data, write_data);
	reg_write(reg_mdio_comp_control, 1);
	return wait_for_op_complete();
}


///////////////////////////////////////////////////////
bool mdio_comp::wait_for_op_complete()
{
	bool finished = utils::get_bit(reg_read(reg_mdio_comp_control), 1);
	int timeout = 10;
	while (!finished && (timeout > 0))
	{
		timeout -= 1;
		finished = reg_read(reg_mdio_comp_control);
		usleep(5000);
	}
	if (!finished && (timeout <= 0))
	{
		LOG_WARN("Timedout waiting for mdio complete");
	}
	return finished;
}
