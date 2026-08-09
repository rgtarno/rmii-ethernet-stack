
from vunit import VUnit
import os
from os.path import dirname


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()
    vu.add_verification_components()

    # Create library 'lib'
    lib = vu.add_library("uart_apb_bridge")

    current_dir = os.path.dirname(os.path.abspath(__file__))
    repo_top = f"{dirname(__file__)}/../../../../"

    lib.add_source_file(f"{current_dir}/uart_apb_bridge_tb.vhd")
    lib.add_source_file(f"{current_dir}/../uart_apb_bridge.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/apb_component/component_register_block.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/types/apb_data_types.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/uart/axi_uart_rx.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/uart/axi_uart_tx.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
