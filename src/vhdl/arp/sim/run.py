
from vunit import VUnit
import os


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()
    vu.add_verification_components()

    # Create library 'lib'
    lib = vu.add_library("arp")

    current_dir = os.path.dirname(os.path.abspath(__file__))
    repo_top = f"{current_dir}/../../../../"

    lib.add_source_file(f"{current_dir}/arp_tb.vhd")
    lib.add_source_file(f"{current_dir}/../arp.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/fifo/fifo.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/ethernet_framer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/fcs/ethernet_fcs.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/pcap_file_writer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker_pkg.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
