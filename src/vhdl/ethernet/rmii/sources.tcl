
read_vhdl $repo_top/src/vhdl/utils/utils.vhd

read_vhdl $repo_top/src/vhdl/ethernet/rmii/rmii_mac_comp.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/ethernet/rmii/rmii_mac.vhd
read_vhdl $repo_top/src/vhdl/ethernet/rmii/rmii_mac_tx.vhd
read_vhdl $repo_top/src/vhdl/ethernet/rmii/rmii_mac_rx.vhd
read_vhdl $repo_top/src/vhdl/ethernet/rmii/rmii_mac_counters.vhd
read_vhdl $repo_top/src/vhdl/ethernet/mdio/mdio.vhd
read_vhdl $repo_top/src/vhdl/ethernet/fcs/ethernet_fcs.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/ethernet/packet_afifo/packet_afifo.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/ethernet/packet_afifo/skid_buffer_single.vhd
read_vhdl $repo_top/src/vhdl/ethernet/ethernet_framer.vhd
read_vhdl $repo_top/src/vhdl/cdc/pulse_transfer.vhd
read_vhdl $repo_top/src/vhdl/cdc/bit_synchroniser.vhd
read_vhdl $repo_top/src/vhdl/arp/arp.vhd
read_vhdl $repo_top/src/vhdl/ethernet/rx_packet_buffer/rx_packet_buffer.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/ethernet/ethernet_deframer/ethernet_deframer.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/ethernet/ethernet_deframer/circular_buffer.vhd


source $repo_top/src/vhdl/afifo/sources.tcl

