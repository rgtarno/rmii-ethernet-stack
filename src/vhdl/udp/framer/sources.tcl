
source $repo_top/src/vhdl/apb_component/sources.tcl
source $repo_top/src/vhdl/fifo/sources.tcl

read_vhdl $repo_top/src/vhdl/utils/utils.vhd
read_vhdl $repo_top/src/vhdl/udp/framer/udp_ip_framer_comp.vhd
read_vhdl -vhdl2008 $repo_top/src/vhdl/udp/framer/udp_ip_framer.vhd
