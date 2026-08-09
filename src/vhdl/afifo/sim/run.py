
from vunit import VUnit
from os.path import dirname

def create_config(tb, clk_a_ns, clk_b_ns, data_width, log2_depth):
    tb.add_config(
        name=f"wr_clk={clk_a_ns}ns_wr_clk={clk_b_ns}ns_width={data_width}_depth={log2_depth}",
        generics=dict(
            clk_a_period_ns=f"{clk_a_ns} ns",
            clk_b_period_ns=f"{clk_b_ns} ns",
            data_width=data_width,
            log2_depth=log2_depth,
            )
    )

def create_test_suite(vu):
    vu.add_vhdl_builtins()
    vu.add_osvvm()
    vu.add_verification_components()

    # Create library 'lib'
    lib = vu.add_library("afifo")

    repo_top = f"{dirname(__file__)}/../../../../"

    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/sim/afifo_tb.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/sim/afifo_backpressure_tb.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo_read_logic.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/afifo_write_logic.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/grey_pointer_sync.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/afifo/fifo_fwft.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/cdc/bit_synchroniser.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/utils.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/ram/sdp_ram.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker.vhd")
    lib.add_source_file(f"{repo_top}/src/vhdl/utils/axi_std_logic_checker_pkg.vhd")

    tb = lib.test_bench("afifo_tb")
    create_config(tb, 10, 1, 10, 9)
    create_config(tb, 1, 10, 10, 8)
    create_config(tb, 93, 1, 12, 11)
    create_config(tb, 1, 1, 8, 7)
    create_config(tb, 3.3, 2, 1, 12)


if __name__ == '__main__':
    # Create VUnit instance by parsing command line arguments
    vu = VUnit.from_argv()
    create_test_suite(vu)
    # Run vunit function
    vu.main()
