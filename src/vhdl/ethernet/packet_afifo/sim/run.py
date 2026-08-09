from os.path import dirname
from vunit import VUnit


def create_test_suite(project):
    project.add_vhdl_builtins()
    project.add_osvvm()

    # Create library 'lib'
    lib = project.add_library("packet_afifo")

    repo_top = f"{dirname(__file__)}/../../../../../"

    lib.add_source_file(
        f"{repo_top}/src/vhdl/ethernet/packet_afifo/sim/packet_afifo_tb.vhd")
    lib.add_source_file(
        f"{repo_top}/src/vhdl/ethernet/packet_afifo/packet_afifo.vhd")
    lib.add_source_file(
            f"{repo_top}/src/vhdl/ethernet/packet_afifo/skid_buffer_single.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo_read_logic.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo_write_logic.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/grey_pointer_sync.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/fifo_fwft.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/cdc/bit_synchroniser.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ram/sdp_ram.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/cdc/pulse_transfer.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/fifo/fifo.vhd")


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
