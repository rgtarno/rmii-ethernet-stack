
from vunit import VUnit
import os


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("mdio")

    current_dir = os.path.dirname(os.path.abspath(__file__))

    lib.add_source_file(f"{current_dir}/mdio_tb.vhd")
    lib.add_source_file(f"{current_dir}/mdio_slave.vhd")
    lib.add_source_file(f"{current_dir}/mdio_slave_pkg.vhd")
    lib.add_source_file(f"{current_dir}/../mdio.vhd")
    lib.add_source_file(f"{current_dir}/../../../utils/utils.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
