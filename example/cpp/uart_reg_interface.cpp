#include "uart_reg_interface.hpp"

#include <fcntl.h>     // Contains file controls like O_RDWR
#include <errno.h>     // Error integer and strerror() function
#include <termios.h>   // Contains POSIX terminal control definitions
#include <unistd.h>    // write(), read(), close()
#include <sys/ioctl.h> // ioctl
#include <linux/serial.h>
#include <stdexcept>



//==============================================================
uart_reg_interface::uart_reg_interface(const char* dev_name, const int baud_rate) : _fd(-1)
{
  _fd = open(dev_name, O_RDWR);

  if (_fd < 0)
  {
    throw std::runtime_error("Failed to open device");
  }

  struct termios tty;
  if (tcgetattr(_fd, &tty) != 0)
  {
    close(_fd);
    throw std::runtime_error("tcgetattr error");
  }

  tty.c_iflag &= ~(IXON | IXOFF | IXANY);                                      // Turn off s/w flow ctrl
  tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL); // Disable any special handling of received bytes

  tty.c_cflag &= ~PARENB; // Clear parity bit, disabling parity (most common)
  tty.c_cflag &= ~CSTOPB; // Clear stop field, only one stop bit used in communication (most common)
  // tty.c_cflag |= CSTOPB;         // Set stop field, 2 stop bits
  tty.c_cflag &= ~CSIZE;         // Clear all the size bits, then use one of the statements below
  tty.c_cflag |= CS8;            // 8 bits per byte (most common)
  tty.c_cflag &= ~CRTSCTS;       // Disable RTS/CTS hardware flow control (most common)
  tty.c_cflag |= CREAD | CLOCAL; // Turn on READ & ignore ctrl lines (CLOCAL = 1)
  tty.c_lflag &= ~ICANON;
  tty.c_lflag &= ~ECHO;    // Disable echo
  tty.c_lflag &= ~ECHOE;   // Disable erasure
  tty.c_lflag &= ~ECHONL;  // Disable new-line echo
  tty.c_lflag &= ~ISIG;    // Disable interpretation of INTR, QUIT and SUSP
  tty.c_oflag &= ~OPOST;   // Prevent special interpretation of output bytes (e.g. newline chars)
  tty.c_oflag &= ~ONLCR;   // Prevent conversion of newline to carriage return/line feed

  tty.c_cc[VTIME] = 0;
  tty.c_cc[VMIN] = 4;

  if (cfsetispeed(&tty, baud_rate))
  {
    close(_fd);
    throw std::runtime_error("cfsetispeed error");
  }
  if (cfsetospeed(&tty, baud_rate))
  {
    close(_fd);
    throw std::runtime_error("cfsetospeed error");
  }

  if (tcsetattr(_fd, TCSANOW, &tty) != 0)
  {
    close(_fd);
    throw std::runtime_error("tcsetattr error");
  }

  struct serial_struct serial_info;
  if (ioctl(_fd, TIOCGSERIAL, &serial_info))
  {
    close(_fd);
    throw std::runtime_error("ioctl TIOCGSERIAL error");
  }
  serial_info.flags |= ASYNC_LOW_LATENCY; // Reduces the FTDI chips latency timer to 1ms.
  if (ioctl(_fd, TIOCSSERIAL, &serial_info))
  {
    close(_fd);
    throw std::runtime_error("ioctl TIOCSSERIAL error");
  }
}

//==============================================================
uart_reg_interface::~uart_reg_interface()
{
  close(_fd);
}

//==============================================================
uint32_t uart_reg_interface::read(const uint32_t address) const
{
  uint32_t reg = 0;
  reg = reg | (address & (uint32_t(0xFFFFFFFF) >> 1));
  ssize_t ret = ::write(_fd, &reg, sizeof(reg));
  if (ret != sizeof(reg))
  {
    throw std::runtime_error("Failed to write read address");
  }
  uint32_t response = 0;
  ret = ::read(_fd, &response, sizeof(response));
  if (ret != sizeof(reg))
  {
    throw std::runtime_error("Failed to read response");
  }
  return response;
}

//==============================================================
void uart_reg_interface::write(const uint32_t address, const uint32_t data)
{
  uint32_t reg = 1 << 31;
  reg = reg | address;
  ssize_t ret = ::write(_fd, &reg, sizeof(reg));
  if (ret != sizeof(reg))
  {
    throw std::runtime_error("Failed to send write address");
  }
  ret = ::write(_fd, &data, sizeof(data));
  if (ret != sizeof(reg))
  {
    throw std::runtime_error("Failed to send write data");
  }

  uint32_t response = 0;
  ret = ::read(_fd, &response, sizeof(response));
  if (ret != sizeof(reg))
  {
    throw std::runtime_error("Failed to read write response");
  }
  if (data != response)
  {
    throw std::runtime_error("Failed to read back expected value");
  }
}