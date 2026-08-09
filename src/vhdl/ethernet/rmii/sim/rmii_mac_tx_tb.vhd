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

entity rmii_mac_tx_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of rmii_mac_tx_tb is

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
  
  signal s_axis_tdata_in      : std_logic_vector(7 downto 0);
  signal s_axis_tvalid_in     : std_logic;
  signal s_axis_tlast_in      : std_logic;
  signal s_axis_tready_out    : std_logic;

  signal tx_en                : std_logic;
  signal txd                  : std_logic_vector(1 downto 0);

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

      s_axis_tdata_in   <= (others => '0');
      s_axis_tvalid_in  <= '0';
      s_axis_tlast_in   <= '0';

      reset <= '1';
      wait_clk(clk_a, 5);
      reset <= '0';
      wait_clk(clk_a, 5);

      if run("send_multiple_packets") then

        for packet_num in 0 to C_NUM_PACKETS-1 loop

          packet_length := rnd.RandInt(64, 1500);
          s_axis_tvalid_in <= '1';
          
          for i in 0 to packet_length-1 loop
            
            s_axis_tdata_in <= std_logic_vector(counter);
            expect(net, payload_checker, std_logic_vector(counter), now, now + 100 * C_CLK_A_PERIOD);
            counter := counter + 1;
            if i = packet_length-1 then
              s_axis_tlast_in <= '1';
            else
              s_axis_tlast_in <= '0';
            end if;

            wait until rising_edge(clk_a) and s_axis_tready_out  = '1';
            
          end loop;
          
          s_axis_tvalid_in <= '0';
          wait_clk(clk_a, rnd.RandInt(0, 1500));

        end loop;

        s_axis_tvalid_in <= '0';

        wait_clk(clk_a, 100);

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;


----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.rmii_mac_tx
  port map (
    clk50               => clk_a,
    reset               => reset,
    --------------------------------------------------------
    s_axis_tdata        => s_axis_tdata_in,
    s_axis_tvalid       => s_axis_tvalid_in,
    s_axis_tlast        => s_axis_tlast_in,
    s_axis_tready       => s_axis_tready_out,
    --------------------------------------------------------
    tx_en               => tx_en,
    txd                 => txd
  );

----------------------------------------
-- Check data
----------------------------------------

  i_rmii_phy_rx: entity work.rmii_phy_rx
  port map (
    clk50               => clk_a,
    reset               => reset,
    --------------------------------------------------------
    tx_en               => tx_en,
    txd                 => txd,
    --------------------------------------------------------
    payload_data_out    => payload_data,
    payload_valid_out   => payload_valid
  );

  process(clk_a)
  begin
    if rising_edge(clk_a) then
      if payload_valid = '1' then
        checker_data <= payload_data;
      end if;
    end if;
  end process;

  i_payload_checker: entity vunit_lib.std_logic_checker
  generic map (
    signal_checker => payload_checker)
  port map (
    value => checker_data
  );

end architecture;