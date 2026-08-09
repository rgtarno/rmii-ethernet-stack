
#pragma once

#include "reg_interface.hpp"
#include "reg_comp.hpp"
#include <cstdint>



class mdio_comp : public reg_comp
{
public:
	mdio_comp(reg_interface& reg_interface, const std::uint32_t offset);

	bool mdio_read(std::uint16_t phy_address, std::uint16_t reg_address, std::uint16_t* return_data);
	bool mdio_write(std::uint16_t phy_address, std::uint16_t reg_address, std::uint16_t write_data);

private:
	bool wait_for_op_complete();

};
