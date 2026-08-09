library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity rmii_mac_rx_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of rmii_mac_rx_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant C_CLK_A_PERIOD         : time := 20 ns;

  constant C_NUM_PACKETS          : natural := 30;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));
  
  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk_a                : std_logic := '0';

  signal reset                : std_logic := '0';
  signal start_signal         : std_logic := '0';
  signal finished_signal      : std_logic := '0';
  
  signal m_axis_tdata_out      : std_logic_vector(7 downto 0);
  signal m_axis_tvalid_out     : std_logic;
  signal m_axis_tlast_out      : std_logic;

  signal crs_dv                : std_logic;
  signal rxd                  : std_logic_vector(1 downto 0);

  signal payload_data         : std_logic_vector(7 downto 0);
  signal payload_valid        : std_logic := '0';

  signal checker_data         : std_logic_vector(7 downto 0);
  

begin

----------------------------------------
-- CLK generation
----------------------------------------
process
begin
  wait for C_CLK_A_PERIOD/2;
  clk_a <= not clk_a;
end process;

----------------------------------------
-- Stim
----------------------------------------
main : process
  variable rnd              : RandomPType;
  variable packet_length    : natural := 0;
  variable counter          : unsigned(7 downto 0) := (others => '0');
begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 10 ms);

    rnd.InitSeed(rnd'instance_name);
    
    while test_suite loop

      crs_dv  <= '0';
      rxd     <= (others => '0');


      if run("receive_one_packet") then

        wait_clk(clk_a, 13);

        -- 1

        crs_dv  <= '1';
        rxd     <= "00";

        wait_clk(clk_a, 5);
        rxd     <= "01";
        wait_clk(clk_a, 27);
        rxd     <= "11";
        wait_clk(clk_a, 1);
        rxd     <= "10";
        wait_clk(clk_a, 4);
        rxd     <= "01";
        wait_clk(clk_a, 4);

        crs_dv  <= '0';
        wait_clk(clk_a, 20);

        -- 2
        crs_dv  <= '1';
        rxd     <= "00";

        wait_clk(clk_a, 5);
        rxd     <= "01";
        wait_clk(clk_a, 27);
        rxd     <= "11";
        wait_clk(clk_a, 1);
        rxd     <= "10";
        wait_clk(clk_a, 4);
        rxd     <= "01";
        wait_clk(clk_a, 4);

        crs_dv  <= '0';
        wait_clk(clk_a, 20);

        -- 3 (bad)
        crs_dv  <= '1';
        rxd     <= "00";

        wait_clk(clk_a, 5);
        rxd     <= "01";
        wait_clk(clk_a, 23);

        crs_dv  <= '0';
        wait_clk(clk_a, 20);

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;


----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.rmii_mac_rx
  port map (
    clk50               => clk_a,
    reset               => reset,
    --------------------------------------------------------
    m_axis_tdata_out    => m_axis_tdata_out,
    m_axis_tvalid_out   => m_axis_tvalid_out,
    m_axis_tlast_out    => m_axis_tlast_out,
    --------------------------------------------------------
    false_carrier_out   => open,
    --------------------------------------------------------
    crs_dv              => crs_dv,
    rxd                 => rxd
  );

----------------------------------------
-- Check data
----------------------------------------


end architecture;