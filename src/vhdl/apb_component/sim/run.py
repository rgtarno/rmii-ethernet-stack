
from vunit import VUnit
import os
from os.path import dirname


# Create VUnit instance by parsing command line arguments
def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("apb_component")

    current_dir = os.path.dirname(os.path.abspath(__file__))
    repo_top = f"{dirname(__file__)}/../../../../"

    lib.add_source_file(f"{current_dir}/component_register_block_tb.vhd")
    lib.add_source_file(f"{current_dir}/component_register_block_timing_tb.vhd")
    lib.add_source_file(f"{current_dir}/../component_register_block.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/types/apb_data_types.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/pulse_counter.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/tb_pulse_checker.vhd")


# Run vunit function
if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
