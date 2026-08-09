
#pragma once

#include <inttypes.h>

#include "reg_interface.hpp"

/**
 * @brief Provides a read / write register interface over UART.
 *
 * A request and response format is used for communication with the FPGA.
 * 31 bits of address space are available (becasue the top bit is used to distinguish
 * write and read requests).
 *
 * The data bus width is 32 bits.
 *
 * This was written to work with the BASYS3 board, which has an FTDI USB-UART chip.
 * The "low latency" flag is set for this chips driver, allowing us a read latency of 1ms.
 * This limits the overall throughput of this interface, as it works in a lock step fashion. IE
 * send write address and data and readback response.
 *
 * This could be modified to increase overall throughput (IE batch multiple read/write operations and only read
 * back responses later).

 * REFERENCES :
 * https://www.ftdichip.com/Documents/AppNotes/AN232B-04_DataLatencyFlow.pdf
 * 
 */
class uart_reg_interface : public reg_interface
{
  public:
    explicit uart_reg_interface(const char* dev_name, const int baud_rate);
    ~uart_reg_interface();

    uart_reg_interface(const uart_reg_interface&) = delete;
    uart_reg_interface(uart_reg_interface&&) = delete;
    uart_reg_interface& operator=(const uart_reg_interface&) = delete;
    uart_reg_interface& operator=(uart_reg_interface&&) = delete;

    uint32_t read(const uint32_t address) const override;
    void write(const uint32_t address, const uint32_t data) override;

  private:
    mutable int _fd;
};