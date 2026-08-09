
#include "udp_connection.hpp"

#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <stdexcept>

#include "logging.hpp"
#include "utils.hpp"

//========================================================
udp_connection::udp_connection() :
    _sd(-1)
{
  _sd = socket(AF_INET, SOCK_DGRAM, 0);

  if (_sd < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }

  const int enable = 1;
  if (setsockopt(_sd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0)
  {
    close(_sd);
    throw std::runtime_error(utils::string_error(errno));
  }

  // Set default socket buffer sizes to 4MB for high-throughput streaming
  const int default_buf_size = 4 * 1024 * 1024;
  setsockopt(_sd, SOL_SOCKET, SO_RCVBUF, &default_buf_size, sizeof(default_buf_size));
  setsockopt(_sd, SOL_SOCKET, SO_SNDBUF, &default_buf_size, sizeof(default_buf_size));
}

//========================================================
udp_connection::~udp_connection()
{
  if (_sd >= 0)
  {
    close(_sd);
  }
}

//========================================================
void udp_connection::set_non_blocking(const bool enable)
{
  int flags = fcntl(_sd, F_GETFL);
  if (flags < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
  if (enable)
  {
    flags |= O_NONBLOCK;
  }
  else
  {
    flags &= ~O_NONBLOCK;
  }
  if (fcntl(_sd, F_SETFL, flags) < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
}

//========================================================
void udp_connection::set_send_buffer_size(const int size_bytes)
{
  if (setsockopt(_sd, SOL_SOCKET, SO_SNDBUF, &size_bytes, sizeof(size_bytes)) < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
}

//========================================================
void udp_connection::set_recv_buffer_size(const int size_bytes)
{
  if (setsockopt(_sd, SOL_SOCKET, SO_RCVBUF, &size_bytes, sizeof(size_bytes)) < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
}

//========================================================
void udp_connection::bind(const std::string &ip_address, const uint16_t port_num)
{
  struct sockaddr_in sa;
  std::memset(&sa, 0, sizeof(struct sockaddr_in));
  sa.sin_port   = htons(port_num);
  sa.sin_family = AF_INET;

  LOG_DEBUG("Bind to %s:%u", ip_address.c_str(), port_num);

  if (ip_address.empty())
  {
    sa.sin_addr.s_addr = INADDR_ANY;
  }
  else
  {
    if (!inet_pton(AF_INET, ip_address.c_str(), &(sa.sin_addr)))
    {
      throw std::runtime_error("Invalid address");
    }
  }

  if (::bind(_sd, (const struct sockaddr *)&sa, sizeof(struct sockaddr_in)) < 0)
  {
    LOG_ERROR("Bind failed");
    throw std::runtime_error(utils::string_error(errno));
  }
}

//========================================================
void udp_connection::connect(const std::string &ip_address, const uint16_t port_num)
{
  struct sockaddr_in sa;
  std::memset(&sa, 0, sizeof(struct sockaddr_in));
  sa.sin_port   = htons(port_num);
  sa.sin_family = AF_INET;

  LOG_DEBUG("Connect to %s:%u", ip_address.c_str(), port_num);

  if (!inet_pton(AF_INET, ip_address.c_str(), &(sa.sin_addr)))
  {
    throw std::runtime_error("Invalid IP address");
  }

  return udp_connection::connect(sa);
}

//========================================================
void udp_connection::connect(const struct sockaddr_in sa)
{
  if (::connect(_sd, (const struct sockaddr *)&sa, sizeof(struct sockaddr_in)) < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
}

//========================================================
ssize_t udp_connection::send(const std::vector<char> &data)
{
  return ::send(_sd, data.data(), data.size(), 0);
}

//========================================================
ssize_t udp_connection::send_to(const std::string &ip_address, const uint16_t port_num, const std::vector<char> &data)
{
  struct sockaddr_in sa;
  std::memset(&sa, 0, sizeof(struct sockaddr_in));
  sa.sin_port   = htons(port_num);
  sa.sin_family = AF_INET;
  if (!inet_pton(AF_INET, ip_address.c_str(), &(sa.sin_addr)))
  {
    throw std::runtime_error("Invalid IP address");
  }

  return ::sendto(_sd, data.data(), data.size(), 0, (const struct sockaddr *)&sa, sizeof(struct sockaddr_in));
}

//========================================================
ssize_t udp_connection::recv(char *buffer, const size_t max_size)
{
  const ssize_t received = ::recv(_sd, buffer, max_size, 0);
  if ((received <= 0) && ((errno == EAGAIN) || (errno == EWOULDBLOCK)))
  {
    return 0;
  }
  else if (received < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }
  return received;
}

//========================================================
std::vector<char> udp_connection::recv(const size_t size)
{
  std::vector<char> buffer(size, 0);
  const ssize_t     received = recv(buffer.data(), size);
  if (received <= 0)
  {
    return {};
  }
  if (static_cast<size_t>(received) < size)
  {
    buffer.resize(static_cast<size_t>(received));
  }
  return buffer;
}

//========================================================
ssize_t udp_connection::recv_from(std::string &ip_address, uint16_t &port_num, char *buffer, const size_t max_size)
{
  struct sockaddr_in sa;
  socklen_t          sa_len = sizeof(sa);
  std::memset(&sa, 0, sizeof(struct sockaddr_in));

  const ssize_t received = ::recvfrom(_sd, buffer, max_size, 0, (struct sockaddr *)&sa, &sa_len);

  if ((received <= 0) && ((errno == EAGAIN) || (errno == EWOULDBLOCK)))
  {
    return 0;
  }
  else if (received < 0)
  {
    throw std::runtime_error(utils::string_error(errno));
  }

  char addr_buf[INET_ADDRSTRLEN] = {0};
  if (inet_ntop(AF_INET, &(sa.sin_addr), addr_buf, INET_ADDRSTRLEN) != NULL)
  {
    ip_address = std::string(addr_buf);
  }
  port_num = ntohs(sa.sin_port);
  return received;
}

//========================================================
std::vector<char> udp_connection::recv_from(std::string &ip_address, uint16_t &port_num, const size_t size)
{
  std::vector<char> buffer(size, 0);
  const ssize_t     received = recv_from(ip_address, port_num, buffer.data(), size);
  if (received <= 0)
  {
    return {};
  }
  if (static_cast<size_t>(received) < size)
  {
    buffer.resize(static_cast<size_t>(received));
  }
  return buffer;
}