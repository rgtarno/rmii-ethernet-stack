

#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <netinet/in.h>
#include <optional>
#include <poll.h>
#include <signal.h>
#include <stdexcept>
#include <stdio.h>
#include <string>
#include <termios.h> // Contains POSIX terminal control definitions
#include <thread>

#include "lan8720.hpp"
#include "logging.hpp"
#include "prbs.hpp"
#include "prbs_verifier.hpp"
#include "reg_comp.hpp"
#include "reg_interface.hpp"
#include "rmii_ethernet.hpp"
#include "timer.hpp"
#include "token_bucket.hpp"
#include "uart_reg_interface.hpp"
#include "udp_connection.hpp"
#include "udp_deframer_comp.hpp"
#include "udp_framer_comp.hpp"
#include "utils.hpp"
#include "token_bucket.hpp"

std::atomic<log_level_t> global_log_level{log_level_t::INFO};
std::atomic_bool         global_exit_requested{false};

void sig_handler(int signum);

void send_thread(std::string src_ip, std::string dst_ip, std::uint16_t src_port, std::uint16_t dst_port, std::uint32_t data_rate_bps);
void receive_thread(std::string ip, std::uint16_t port);

//===================================================================================
int main(int argc, char **argv)
{
  using namespace std::chrono_literals;

  (void)argc;
  (void)argv;

  signal(SIGINT, sig_handler);

  /* Constants */
  const std::uint32_t UDP_IP_FRAMER_COMP_NUM   = 1;
  const std::uint32_t UDP_IP_DEFRAMER_COMP_NUM = 2;
  const std::uint32_t RMII_MAC_COMP_NUM        = 3;
  const std::string   FPGA_IP{"192.168.0.2"};
  const std::string   PC_IP{"192.168.0.1"};
  const std::string   BROADCAST_IP{"192.168.0.255"};
  const std::uint16_t PC_TX_PORT         = 9990;
  const std::uint16_t FPGA_RX_PORT       = 9991;
  const std::uint16_t FPGA_TX_PORT       = 9992;
  const std::uint16_t PC_RX_PORT         = 9993;
  const unsigned char FPGA_MAC[6]        = {0xe9, 0xd6, 0x85, 0x0c, 0x47, 0x5a};
  const unsigned char DESTINATION_MAC[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
  const std::uint32_t target_data_rate_bps{95 * 1000 * 1000};

  /* Create FPGA components */
  uart_reg_interface regs("/dev/ttyUSB1", B115200);
  LOG_INFO("Created UART register interface");

  udp_framer_comp udp_framer(regs, utils::COMP_NUM_TO_OFFSET(UDP_IP_FRAMER_COMP_NUM));
  LOG_INFO("Created UDP framer");

  rmii_ethernet rmii(regs, utils::COMP_NUM_TO_OFFSET(RMII_MAC_COMP_NUM));
  LOG_INFO("Created RMII");

  udp_deframer_comp udp_deframer(regs, utils::COMP_NUM_TO_OFFSET(UDP_IP_DEFRAMER_COMP_NUM));
  LOG_INFO("Created UDP deframer");

  /* Configure RMII MAC */
  rmii.set_destination_mac(DESTINATION_MAC);
  rmii.set_source_mac(FPGA_MAC);
  rmii.set_source_ip(ntohl(utils::string_to_ip(FPGA_IP).value()));

  if (!rmii.init())
  {
    LOG_ERROR("Failed to init RMII");
    return 1;
  }

  /* Configure UDP framer */
  udp_framer_comp::config_t udp_framer_cfg;
  udp_framer_cfg.src_ip   = ntohl(utils::string_to_ip(FPGA_IP).value());
  udp_framer_cfg.dst_ip   = ntohl(utils::string_to_ip(PC_IP).value());
  udp_framer_cfg.src_port = FPGA_TX_PORT;
  udp_framer_cfg.dst_port = PC_RX_PORT;

  udp_framer.reset();
  udp_framer.set_config(udp_framer_cfg);
  udp_framer.set_enable(true);

  /* Configure UDP deframer */
  udp_deframer_comp::config_t udp_deframer_cfg;
  udp_deframer_cfg.ip           = ntohl(utils::string_to_ip(FPGA_IP).value());
  udp_deframer_cfg.port         = FPGA_RX_PORT;
  udp_deframer_cfg.broadcast_ip = ntohl(utils::string_to_ip(BROADCAST_IP).value());

  udp_deframer.reset();
  udp_deframer.set_config(udp_deframer_cfg);
  udp_deframer.set_enable(true);

  std::thread send    = std::thread(&send_thread, PC_IP, FPGA_IP, PC_TX_PORT, FPGA_RX_PORT, target_data_rate_bps);
  std::thread receive = std::thread(&receive_thread, PC_IP, PC_RX_PORT);

  const auto status_interval = std::chrono::seconds(10);
  monotonic_timer status_timer(status_interval);

  auto print_mac_status = [&rmii, &udp_deframer] {
    const auto mac_status = rmii.get_status();
    LOG_INFO("MAC RX packets = %" PRIu32 " bytes = %" PRIu32, mac_status.packets_received, mac_status.bytes_received);
    LOG_INFO("MAC RX Drops = %" PRIu16 " FCS fails = %" PRIu32, mac_status.ethernet_packets_dropped, mac_status.fcs_fails);
    LOG_INFO("UDP RX valid packets = %" PRIu16 " dropped packets = %" PRIu16, udp_deframer.get_valid_packet_count(), udp_deframer.get_dropped_packet_count());
    LOG_INFO("MAC TX packets = %" PRIu32 " bytes = %" PRIu32, mac_status.packets_sent, mac_status.bytes_sent);
  };

  while (!global_exit_requested)
  {
    std::this_thread::sleep_for(std::chrono::milliseconds(250));

    if (status_timer.expired())
    {
      print_mac_status();
      status_timer.restart(status_interval);
    }
  }

  send.join();
  receive.join();

  print_mac_status();
  LOG_INFO("Exit");
  return 0;
}

//===================================================================================
void send_thread(std::string src_ip, std::string dst_ip, std::uint16_t src_port, std::uint16_t dst_port, std::uint32_t data_rate_bps)
{
  /* Configure local UDP socket */
  udp_connection udp;
  udp.set_send_buffer_size(4 * 1024 * 1024);
  udp.bind(src_ip, src_port);
  udp.connect(dst_ip, dst_port);

  /* Setup PRBS generator */
  const std::vector<std::uint32_t> taps{23, 18};
  prbs                             prbs_generator(taps);

  const std::size_t packet_length = 1400;

  std::vector<char> packet(packet_length);

  const double packets_per_sec = static_cast<double>(data_rate_bps) / (packet_length * 8);

  token_bucket token_bucket;
  token_bucket.set_rate(packets_per_sec);

  std::size_t     total_sent    = 0;
  std::size_t     interval_sent = 0;
  monotonic_timer status_timer(std::chrono::seconds(10));

  LOG_INFO("Transmitting packets now (target rate: %.2f Mbps, %.1f pkts/sec)...",
           data_rate_bps / 1.0e6, packets_per_sec);

  while (!global_exit_requested)
  {

    std::generate(packet.begin(), packet.end(), [&prbs_generator]() {
      return static_cast<char>(prbs_generator.get_word(8));
    });

    token_bucket.acquire();

    const ssize_t ret = udp.send(packet);

    total_sent += 1;
    interval_sent += 1;
    LOG_DEBUG("Send packet to %s (%zu bytes) (Total sent : %zu)", dst_ip.c_str(), packet.size(), total_sent);
    if (ret <= 0)
    {
      LOG_ERROR("Send failed : %s", utils::string_error(errno).c_str());
    }

    if (status_timer.expired())
    {
      const auto  elapsed_ms      = status_timer.elapsed<double, std::chrono::milliseconds>();
      const float actual_pkts_sec = (interval_sent * 1000.0f) / elapsed_ms;
      const float actual_mbps     = (interval_sent * packet_length * 8.0f * 1000.0f) / (elapsed_ms * 1.0e6f);
      const float expected_pkts   = (packets_per_sec * elapsed_ms) / 1000.0f;
      const float deficit_percent = 100.0f * (1.0f - (actual_pkts_sec / packets_per_sec));

      LOG_INFO("TX Target Rate   : %.2f Mbps (%.1f pkts/sec)", data_rate_bps / 1.0e6, packets_per_sec);
      LOG_INFO("TX Actual Rate   : %.2f Mbps (%.1f pkts/sec)", actual_mbps, actual_pkts_sec);
      LOG_INFO("TX Lag / Deficit : %.1f%% (%d packets behind target)",
               deficit_percent > 0.0f ? deficit_percent : 0.0f,
               static_cast<int>(expected_pkts) - static_cast<int>(interval_sent));
      if (deficit_percent > 1.0)
      {
        LOG_WARN("Send thread not keeping up");
      }
      interval_sent = 0;
      status_timer.restart(std::chrono::seconds(10));
    }
  }

  LOG_INFO("Exit send thread");
}

//===================================================================================
void receive_thread(std::string ip, std::uint16_t port)
{
  /* Configure local UDP socket */
  udp_connection udp;
  udp.set_recv_buffer_size(4 * 1024 * 1024);
  udp.bind(ip, port);
  udp.set_non_blocking(true);

  /* Setup PRBS verifier */
  const std::vector<std::uint32_t> taps{23, 18};
  prbs_verifier                    verifier(taps);

  const std::size_t max_packet_length_bytes = 1500;
  std::vector<char> recv_buffer(max_packet_length_bytes);
  std::string       recv_ip;
  std::uint16_t     recv_port;
  std::uint64_t     num_received_packets = 0;
  std::uint64_t     num_received_bytes   = 0;
  monotonic_timer   status_timer(std::chrono::seconds(10));

  pollfd pfd = {
      .fd      = udp.sd(),
      .events  = POLL_IN,
      .revents = 0,
  };

  LOG_INFO("Receiving packets now...");

  while (!global_exit_requested)
  {

    const int ret = poll(&pfd, 1, 1000);

    if (ret < 0 && errno == EINTR)
    {
      /* Signal interrupt */
      continue;
    }
    else if (ret < 0)
    {
      LOG_WARN("Poll error : %s", utils::string_error(errno).c_str());
    }
    else if (ret > 0)
    {
      try
      {
        const ssize_t bytes_received = udp.recv_from(recv_ip, recv_port, recv_buffer.data(), recv_buffer.size());
        if (bytes_received > 0)
        {
          num_received_packets++;
          num_received_bytes += bytes_received;
          LOG_DEBUG("Received %zd bytes from %s:%u", bytes_received, recv_ip.c_str(), recv_port);
          for (ssize_t i = 0; i < bytes_received; ++i)
          {
            verifier.push_bits(recv_buffer[i], 8);
          }
        }
      }
      catch (const std::exception &err)
      {
        LOG_ERROR("Failed to receive a packet : %s", err.what());
        break;
      }
    }

    if (status_timer.expired())
    {
      const auto prbs_status = verifier.get_status();
      LOG_INFO("=======================================");
      LOG_INFO("RX Num prbs bits received    = %" PRIu64, prbs_status.num_bits);
      LOG_INFO("RX Num prbs bit errors       = %" PRIu64, prbs_status.num_bit_errors);
      LOG_INFO("RX Lock count                = %" PRIu64, prbs_status.lock_count);
      LOG_INFO("RX PRBS locked               = %d", prbs_status.locked);
      LOG_INFO("RX Num packets               = %" PRIu64, num_received_packets);
      const auto  duration_milliseconds = status_timer.elapsed<std::uint64_t, std::chrono::milliseconds>();
      const float MBs                   = ((num_received_bytes * 8 * 1.0e3) / (duration_milliseconds * 1.0e6));
      const float bps                   = ((num_received_bytes * 8 * 1.0e3) / (duration_milliseconds));
      LOG_INFO("RX Estimated rate (bps)      = %.0f", bps);
      LOG_INFO("RX Estimated rate (MBs)      = %.2f", MBs);
      num_received_bytes = 0;
      status_timer.restart(std::chrono::seconds(10));
    }
  }

  LOG_INFO("Exit receive thread")
}

//===================================================================================
void sig_handler(int signum)
{
  (void)signum;
  LOG_INFO("Caught signal %d", signum);
  global_exit_requested = true;
}