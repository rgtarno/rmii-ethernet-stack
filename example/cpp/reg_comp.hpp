
#pragma once

#include <cstdint>

#include "reg_interface.hpp"

class reg_comp
{
  public:
    reg_comp(reg_interface& reg_interface, const std::uint32_t comp_id, const std::uint32_t offset) : _offset(offset), _comp_id(comp_id), _reg_interface(reg_interface) {};
    virtual ~reg_comp() = default;

    void reg_write(const std::uint32_t address, const std::uint32_t data)
    {
      _reg_interface.write(_offset + address, data);
    }

    std::uint32_t reg_read(const std::uint32_t address) const
    {
      return _reg_interface.read(_offset + address);
    }

    bool probe() const
    {
      return reg_read(0) == _comp_id;
    };


  private:
    std::uint32_t  _offset;
    std::uint32_t  _comp_id;
    reg_interface& _reg_interface;
};
