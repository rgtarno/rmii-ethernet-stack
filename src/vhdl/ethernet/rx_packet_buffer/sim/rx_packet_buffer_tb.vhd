library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;
use work.axi_std_logic_checker_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity rx_packet_buffer_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of rx_packet_buffer_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP               : time := 8 ns;

  constant C_MIN_STALL        : natural := 1;
  constant C_MAX_STALL        : natural := 10;
  constant C_STALL_PROB       : real    := 0.9;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                 : std_logic := '0';
  signal reset               : std_logic := '0';

  signal s_axis_tdata        : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tuser        : std_logic_vector(0 downto 0) := (others => '0');
  signal s_axis_tvalid       : std_logic := '0';
  signal s_axis_tlast        : std_logic := '0';

  signal m_axis_tdata        : std_logic_vector(7 downto 0) := (others => '0');
  signal m_axis_tvalid       : std_logic := '0';
  signal m_axis_tlast        : std_logic := '0';

  signal tuser_tieoff : std_logic_vector(0 downto 0) := (others => '0');


begin

  test_runner_watchdog(runner, 1 ms);
  
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
  procedure inject_packet(packet_length : natural;
                          bad_packet : boolean) is
  begin
    s_axis_tdata  <= (others => '0');
    s_axis_tuser  <= (others => '0');
    s_axis_tvalid <= '0';
    s_axis_tlast  <= '0';

    for i in 0 to packet_length-1 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = packet_length-1 then
        s_axis_tlast  <= '1';
        if bad_packet then
          s_axis_tuser(0) <= '1'; -- bad packet
        else
          axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        end if;
      else
        if not bad_packet then
          axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        end if;
        s_axis_tlast  <= '0';
      end if;

      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';
    s_axis_tuser(0) <= '0';

  end procedure;

  variable rnd : RandomPType;
  variable num_stall_cycles : natural := 0;
begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 200 us);
  rnd.InitSeed(rnd'instance_name);

  s_axis_tdata  <= (others => '0');
  s_axis_tuser  <= (others => '0');
  s_axis_tvalid <= '0';
  s_axis_tlast  <= '0';

  reset <= '1';
  wait_clk(clk, 10);
  reset <= '0';
  wait_clk(clk, 10);

  if run("single_good_packet_is_passed_through") then
    inject_packet(8, false);
    wait_until_idle(net, payload_checker);

  elsif run("single_bad_packet_is_not_passed_through") then
    inject_packet(8, true);
    wait_until_idle(net, payload_checker);

  elsif run("multiple_back_to_back_good_packets_should_all_pass_through") then

    inject_packet(16, false);
    inject_packet(16, false);

    for i in 1 to 16 loop
      inject_packet(i, false);
    end loop;

    for i in 16 downto 1 loop
      inject_packet(i, false);
    end loop;

      wait_until_idle(net, payload_checker);

  elsif run("one_long_good_packet_then_multiple_short_bad") then

    inject_packet(16, false);
    inject_packet(3, true);
    inject_packet(3, true);
    inject_packet(3, true);
    inject_packet(3, true);

    wait_until_idle(net, payload_checker);

  elsif run("one_long_bad_packet_then_multiple_short_good") then

      inject_packet(16, true);
      inject_packet(3, false);
      inject_packet(5, false);
      inject_packet(3, false);
      inject_packet(3, false);
  
      wait_until_idle(net, payload_checker);

  elsif run("good_packet_with_valid_gaps") then
    s_axis_tdata  <= (others => '0');
    s_axis_tuser  <= (others => '0');
    s_axis_tvalid <= '0';
    s_axis_tlast  <= '0';

    for i in 0 to 13-1 loop

      if rnd.RandReal(0.0, 1.0) < C_STALL_PROB then
        num_stall_cycles := rnd.FavorSmall(C_MIN_STALL, C_MAX_STALL);
      end if;
      for stall in 0 to num_stall_cycles-1 loop
        s_axis_tvalid <= '0';
        wait until rising_edge(clk);
      end loop;

      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 13-1 then
        s_axis_tlast  <= '1';
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';
    s_axis_tuser(0) <= '0';

    wait_until_idle(net, payload_checker);

  elsif run("bad_packet_with_valid_gaps") then
    s_axis_tdata  <= (others => '0');
    s_axis_tuser  <= (others => '0');
    s_axis_tvalid <= '0';
    s_axis_tlast  <= '0';

    for i in 0 to 13-1 loop

      if rnd.RandReal(0.0, 1.0) < C_STALL_PROB then
        num_stall_cycles := rnd.FavorSmall(C_MIN_STALL, C_MAX_STALL);
      end if;
      for stall in 0 to num_stall_cycles-1 loop
        s_axis_tvalid <= '0';
        wait until rising_edge(clk);
      end loop;

      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 13-1 then
        s_axis_tlast  <= '1';
        s_axis_tuser(0) <= '1'; -- bad packet
      else
        s_axis_tlast  <= '0';
      end if;

      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';
    s_axis_tuser(0) <= '0';

    wait_until_idle(net, payload_checker);
  end if;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- DUT
----------------------------------------

  i_dut : entity work.rx_packet_buffer
  generic map (
    G_LOG2_DEPTH           => 4
  )
  port map (
    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    s_axis_tdata_in        => s_axis_tdata,
    s_axis_tuser_in        => s_axis_tuser,
    s_axis_tvalid_in       => s_axis_tvalid,
    s_axis_tlast_in        => s_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out       => m_axis_tdata,
    m_axis_tvalid_out      => m_axis_tvalid,
    m_axis_tlast_out       => m_axis_tlast,
    m_axis_tready_in       => '1'
  );

  ----------------------------------------
  -- Check data
  ----------------------------------------

  payload_checker_inst: entity work.axi_std_logic_checker
  generic map (
    check_tuser    => false,
    signal_checker => payload_checker
  )
  port map (
    clk      => clk,
    tdata    => m_axis_tdata,
    tuser    => tuser_tieoff,
    tvalid   => m_axis_tvalid,
    tlast    => m_axis_tlast
  );


end architecture;