
import struct
import os
import sys
import zlib

sys.path.append('../../../../python/')
from packet_gen import create_udp, create_ip, print_vhdl



############################################################################
def main():
  payload_data = ([x for x in range(200)])
  payload = struct.pack(f'>{len(payload_data)}H', *payload_data)


  SRC_MAC = "aa:bb:cc:dd:ee:ff"
  DST_MAC = "11:22:33:44:55:66"

  SRC_IP = "192.168.0.1"
  DST_IP = "192.168.0.2"
  SRC_PORT = 11001
  DST_PORT = 11002

  header_options = ([0xFFFFFFFF for x in range(4)])

  udp_packet = create_udp(SRC_PORT, DST_PORT,payload, SRC_IP, DST_IP, True)
  ip_packet = create_ip(SRC_IP, DST_IP, udp_packet, True)

  packets = []
  comments = []

  # 1
  comments.append("UDP IP packet. SRC IP 192.168.0.1 DST IP 192.168.0.2")
  packets.append(ip_packet)

  #2
  ip_packet = create_ip(SRC_IP, DST_IP, udp_packet, True, header_options)
  comments.append("UDP IP packet with 4 IP header options words. SRC IP 192.168.0.1 DST IP 192.168.0.2")
  packets.append(ip_packet)

  #3
  ip_packet = create_ip(SRC_IP, "192.168.0.255", udp_packet, True)
  comments.append("UDP IP packet. SRC IP 192.168.0.1 DST IP 192.168.0.255")
  packets.append(ip_packet)

  #4
  udp_packet = create_udp(SRC_PORT, 1234, payload, SRC_IP, DST_IP, True)
  ip_packet = create_ip(SRC_IP, DST_IP, udp_packet, True)
  comments.append("UDP IP packet. SRC IP 192.168.0.1 DST IP 192.168.0.2. DST PORT 1234")
  packets.append(ip_packet)

  print_vhdl("udp_ip_deframer_tb_data_pkg.vhd", "udp_ip_deframer_tb_data_pkg", packets, comments, 1)
  return












if __name__ == '__main__':
  main()