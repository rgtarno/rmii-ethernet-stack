library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;
use work.axi_std_logic_checker_pkg.all;

use work.utils.all;

entity afifo_tb is
  generic (
    runner_cfg   : string;
    clk_a_period_ns : string;
    clk_b_period_ns : string;
    data_width : natural;
    log2_depth : natural
  );
end entity;

architecture tb of afifo_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant C_CLK_A_PERIOD           : time := time'Value(clk_a_period_ns);
  constant C_CLK_B_PERIOD           : time := time'Value(clk_b_period_ns);
  constant C_DATA_WIDTH           : natural := data_width;
  constant C_LOG2_DEPTH           : natural := log2_depth;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));
  

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk_a              : std_logic := '0';
  signal clk_b              : std_logic := '0';

  signal reset            : std_logic := '0';
  signal reset_busy       : std_logic := '0';

  signal write_data       : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal write_en         : std_logic := '0';
  signal full             : std_logic := '0';
  signal read_data        : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal read_en          : std_logic := '0';
  signal empty            : std_logic := '0';

  signal tvalid           : std_logic := '0';
  signal tdata            : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal tuser            : std_logic_vector(0 downto 0);
  signal tlast            : std_logic := '0';

begin

----------------------------------------
-- CLK generation
----------------------------------------
process
begin
  wait for C_CLK_A_PERIOD/2;
  clk_a <= not clk_a;
end process;

process
begin
  wait for C_CLK_B_PERIOD/2;
  clk_b <= not clk_b;
end process;

----------------------------------------
-- Stim
----------------------------------------
main : process
  variable data_in_counter      : unsigned(C_DATA_WIDTH-1 downto 0) := (others => '0');
begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 5 ms);
    
    while test_suite loop

      reset    <= '1';
      wait_clk(clk_a, 1);
      reset    <= '0';
      wait until rising_edge(clk_a) and reset_busy = '0';

      reset    <= '0';
      read_en  <= '0';
      write_en <= '0';
      data_in_counter := (others => '0');
      
      if run("read_en_held_high") then

        wait until rising_edge(clk_b);
        read_en <= '1';

        for i in 0 to 2000 loop
          write_data <= std_logic_vector(data_in_counter);
          write_en <= '1';
          wait until rising_edge(clk_a) and full = '0';
          axi_expect(net, payload_checker, std_logic_vector(data_in_counter), "0", '0');
          write_en <= '0';
          data_in_counter := data_in_counter + 1;
        end loop;

        wait_until_idle(net, payload_checker);

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;


----------------------------------------
-- DUT
----------------------------------------

  i_dut : entity work.afifo
    generic map (
      G_DATA_WIDTH     => C_DATA_WIDTH,
      G_LOG2_DEPTH     => C_LOG2_DEPTH,
      G_FWFT           => true
    )
    port map (
      wr_clk           => clk_a,
      reset            => reset,
      reset_busy       => reset_busy,
      write_data       => write_data,
      write_en         => write_en,
      full             => full,
      --------------------------------------------------
      rd_clk           => clk_b,
      read_data        => read_data,
      read_en          => read_en,
      empty            => empty
    );

  
  tvalid <= read_en and not empty;
  tdata <= read_data;

  payload_checker_inst: entity work.axi_std_logic_checker
    generic map (
      check_tuser    => false,
      signal_checker => payload_checker
    )
    port map (
      clk      => clk_b,
      tdata    => tdata,
      tuser    => tuser,
      tvalid   => tvalid,
      tlast    => tlast
    );
  

end architecture;