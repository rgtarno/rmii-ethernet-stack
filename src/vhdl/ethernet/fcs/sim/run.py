
from vunit import VUnit
import os


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("ethernet_fcs")

    current_dir = os.path.dirname(os.path.abspath(__file__))

    lib.add_source_file(f"{current_dir}/ethernet_fcs_tb.vhd")
    lib.add_source_file(f"{current_dir}/../ethernet_fcs.vhd")
    lib.add_source_file(f"{current_dir}/../../../utils/utils.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
