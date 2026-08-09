library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;

use vunit_lib.uart_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;

use work.utils.all;

entity axi_uart_tx_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of axi_uart_tx_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 10 ns;
  constant C_NUM_REGISTERS        : natural := 8;
  constant C_NUM_SLAVES           : natural := 2;
  constant C_ADDR_BITS_PER_SLAVE  : natural := 8;

  constant C_CLK_RATE_Hz          : natural := 100000000;
  constant C_BAUD_RATE_Hz         : natural := 115200;
  constant C_FRAME_LENGTH         : natural := 8;


  constant slave_uart             : uart_slave_t := new_uart_slave(data_length => 8);
  constant slave_stream           : stream_slave_t := as_stream(slave_uart);

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk              : std_logic := '0';
  signal reset            : std_logic := '0';

  signal uart_tx          : std_logic := '1';
  signal s_axi_tdata_in   : std_logic_vector(C_FRAME_LENGTH - 1 downto 0);
  signal s_axi_tvalid_in  : std_logic := '0';
  signal s_axi_tready_out : std_logic := '0';

begin

----------------------------------------
-- CLK generation
----------------------------------------
process
begin
  wait for CLKP/2;
  clk <= not clk;
end process;

----------------------------------------
-- Stim
----------------------------------------

main : process
    variable reference_queue : queue_t := new_queue;
    variable reference  : stream_reference_t;
    variable input_data     : std_logic_vector(C_FRAME_LENGTH-1 downto 0);
    variable output_data       : std_logic_vector(C_FRAME_LENGTH-1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 20 ms);
    
    while test_suite loop

      reset <= '1';
      wait_clk(clk, 5);
      reset <= '0';
      wait_clk(clk, 5);
      

      if run("uart_tx") then
        set_baud_rate(net, slave_uart, C_BAUD_RATE_Hz);

        for i in 0 to 32-1 loop
          pop_stream(net, slave_stream, reference);
          push(reference_queue, reference);
        end loop;

        for i in 0 to 32-1 loop
          input_data      := std_logic_vector(to_unsigned(i, C_FRAME_LENGTH));
          s_axi_tdata_in  <= input_data;
          s_axi_tvalid_in <= '1';
          wait until s_axi_tvalid_in = '1' and s_axi_tready_out = '1' and rising_edge(clk);
          s_axi_tvalid_in <= '0';
        end loop;

        for i in 0 to 32-1 loop
          input_data      := std_logic_vector(to_unsigned(i, C_FRAME_LENGTH));
          reference := pop(reference_queue);
          await_pop_stream_reply(net, reference, output_data);
          check_equal(output_data, input_data);
        end loop;

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- UART SLAVE
----------------------------------------
i_uart_master: entity vunit_lib.uart_slave
  generic map (
    uart => slave_uart
  )
  port map (
    rx => uart_tx
  );
----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.axi_uart_tx
  generic map (
    G_CLK_RATE_Hz      => C_CLK_RATE_Hz,
    G_BAUD_RATE_Hz     => C_BAUD_RATE_Hz,
    G_FRAME_LENGTH     => C_FRAME_LENGTH
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------------
    s_axi_tdata_in   => s_axi_tdata_in,
    s_axi_tvalid_in  => s_axi_tvalid_in,
    s_axi_tready_out => s_axi_tready_out,
    --------------------------------------------------------
    tx_out           => uart_tx
  );


end architecture;