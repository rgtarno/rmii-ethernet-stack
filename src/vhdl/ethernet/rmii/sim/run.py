
from vunit import VUnit
from os.path import dirname


def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_verification_components()
    vu.add_osvvm()

    # Create library 'lib'
    lib = vu.add_library("rmii")

    repo_top = f"{dirname(__file__)}/../../../../../"

    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/rmii/sim/rmii_mac_tx_tb.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/rmii/sim/rmii_phy_rx.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/rmii/rmii_mac_tx.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")

    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/rmii/sim/rmii_mac_rx_tb.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ethernet/rmii/rmii_mac_rx.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
