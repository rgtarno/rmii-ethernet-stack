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

entity axi_uart_rx_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of axi_uart_rx_tb is

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


  constant master_uart            : uart_master_t := new_uart_master;
  constant master_stream          : stream_master_t := as_stream(master_uart);
  constant uart_rx_checker        : signal_checker_t := new_signal_checker(logger => get_logger("uart_rx_checker"));

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk              : std_logic := '0';
  signal reset            : std_logic := '0';

  signal uart_rx          : std_logic := '1';
  signal s_axi_tdata_out  : std_logic_vector(C_FRAME_LENGTH - 1 downto 0) := (others => '0');
  signal s_axi_tvalid_out : std_logic := '0';

  signal uart_rx_check    : std_logic_vector(C_FRAME_LENGTH - 1 downto 0) := (others => '0');

  signal valid_count      : std_logic_vector(15 downto 0) := (others => '0');

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
  begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 20 ms);
    
    while test_suite loop

      reset <= '1';
      wait_clk(clk, 5);
      reset <= '0';
      wait_clk(clk, 5);
      

      if run("uart_rx") then
        set_baud_rate(net, master_uart, C_BAUD_RATE_Hz);

        for i in 1 to 256-1 loop
          push_stream(net, master_stream, std_logic_vector(to_unsigned(i, C_FRAME_LENGTH)));
          expect(net, uart_rx_checker, std_logic_vector(to_unsigned(i, C_FRAME_LENGTH)), now,  now  + 1000 ms);
        end loop;

        wait_until_idle(net, uart_rx_checker);

        check_equal(valid_count, to_unsigned(255, valid_count'length), "Expected to receive 255 words");

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- UART MASTER
----------------------------------------
i_uart_master: entity vunit_lib.uart_master
  generic map (
    uart => master_uart
  )
  port map (
    tx => uart_rx
  );

----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.axi_uart_rx
  generic map(
    G_CLK_RATE_Hz      => C_CLK_RATE_Hz,
    G_BAUD_RATE_Hz     => C_BAUD_RATE_Hz,
    G_FRAME_LENGTH     => C_FRAME_LENGTH
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------------
    rx_in            => uart_rx,
    --------------------------------------------------------
    s_axi_tdata_out  => s_axi_tdata_out,
    s_axi_tvalid_out => s_axi_tvalid_out
  );

  process(clk)
  begin
    if rising_edge(clk) then
      if s_axi_tvalid_out = '1' then
        uart_rx_check <= s_axi_tdata_out;
      end if;
    end if;
  end process;

  i_uart_rx_checker: entity vunit_lib.std_logic_checker
  generic map (
    signal_checker => uart_rx_checker
  )
  port map (
    value => uart_rx_check
  );

  i_pulse_counter : entity work.pulse_counter
    port map (
      clk              => clk,
      reset            => reset,
      --------------------------------------------------
      enable_in        => s_axi_tvalid_out,
      --------------------------------------------------
      count_out        => valid_count
    );


end architecture;