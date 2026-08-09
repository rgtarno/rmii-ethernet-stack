

set script_path [ file dirname [ file normalize [ info script ] ] ]
set repo_top $script_path/..

source $repo_top/src/vhdl/ethernet/rmii/sources.tcl
source $repo_top/src/vhdl/udp/framer/sources.tcl
source $repo_top/src/vhdl/udp/deframer/sources.tcl
source $repo_top/src/vhdl/uart_apb_bridge/sources.tcl
source $repo_top/src/vhdl/fifo/sources.tcl

read_vhdl $script_path/toplevel.vhd
read_xdc $script_path/constraints.xdc
