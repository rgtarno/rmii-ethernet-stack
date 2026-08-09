
from vunit import VUnit
import os


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()
    vu.add_verification_components()

    # Create library 'lib'
    lib = vu.add_library("fifo")

    current_dir = os.path.dirname(os.path.abspath(__file__))

    lib.add_source_file(f"{current_dir}/fifo_tb.vhd")
    lib.add_source_file(f"{current_dir}/fifo_backpressure_tb.vhd")
    lib.add_source_file(f"{current_dir}/fifo.vhd")
    lib.add_source_file(f"{current_dir}/../utils/utils.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
