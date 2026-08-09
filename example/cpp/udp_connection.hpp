#pragma once

#include <string>
#include <vector>
#include <cstdint>

class udp_connection
{
public:
  udp_connection();
  udp_connection(const udp_connection &) = delete;
  udp_connection(udp_connection &&)      = delete;
  udp_connection &operator=(const udp_connection &) = delete;
  udp_connection &operator=(udp_connection &&) = delete;
  ~udp_connection();

  void              bind(const std::string &ip_address, const uint16_t port_num);
  void              connect(const std::string &ip_address, const uint16_t port_num);
  void              connect(const struct sockaddr_in sa);
  ssize_t           send(const std::vector<char> &data);
  std::vector<char> recv(const size_t size);
  ssize_t           recv(char *buffer, const size_t max_size);
  ssize_t           send_to(const std::string &ip_address, const uint16_t port_num, const std::vector<char> &data);
  std::vector<char> recv_from(std::string &ip_address, uint16_t &port_num, const size_t size);
  ssize_t           recv_from(std::string &ip_address, uint16_t &port_num, char *buffer, const size_t max_size);
  void              set_non_blocking(const bool enable);
  void              set_send_buffer_size(const int size_bytes);
  void              set_recv_buffer_size(const int size_bytes);

  int sd() const
  {
    return _sd;
  }

private:
  int _sd;
};