
#pragma once

#include <inttypes.h>


class reg_interface
{
  public:
    virtual uint32_t read(const uint32_t address) const = 0;
    virtual void     write(const uint32_t address, const uint32_t data) = 0;
};
