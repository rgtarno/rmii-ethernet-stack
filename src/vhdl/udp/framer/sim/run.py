
from vunit import VUnit
import os
from os.path import dirname


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("udp_framer")

    current_dir = os.path.dirname(os.path.abspath(__file__))
    repo_top = f"{dirname(__file__)}/../../../../../"

    lib.add_source_file(f"{current_dir}/udp_ip_framer_tb.vhd")
    lib.add_source_file(f"{current_dir}/../udp_ip_framer.vhd")

    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/pcap_file_writer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/pulse_counter.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/ethernet_framer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/fifo/fifo.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/fcs/ethernet_fcs.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
