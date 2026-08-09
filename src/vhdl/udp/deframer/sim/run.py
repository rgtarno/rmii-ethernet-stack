
from vunit import VUnit
import os
from os.path import dirname


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("udp_deframer")

    current_dir = os.path.dirname(os.path.abspath(__file__))
    repo_top = f"{dirname(__file__)}/../../../../../"

    lib.add_source_file(f"{current_dir}/udp_ip_deframer_tb.vhd")
    lib.add_source_file(f"{current_dir}/udp_ip_deframer_tb_data_pkg.vhd")
    lib.add_source_file(f"{current_dir}/../udp_ip_deframer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker_pkg.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
