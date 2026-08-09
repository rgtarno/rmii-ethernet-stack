library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;
use work.axi_std_logic_checker_pkg.all;

use work.utils.all;
use work.ethernet_deframer_tb_data_pkg.all;

entity eth_deframer_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of eth_deframer_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 8 ns;

  constant C_ETH_HEADER_BYTES     : natural := 14;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk            : std_logic := '0';
  signal reset          : std_logic := '0';

  signal enable                 : std_logic := '0';
  signal idle                   : std_logic := '0';
  signal filter_source_mac      : std_logic := '0';
  signal source_mac             : std_logic_vector(47 downto 0) := (others => '0');
  signal destination_mac        : std_logic_vector(47 downto 0) := (others => '0');
  signal dropped_packet_count   : std_logic_vector(15 downto 0) := (others => '0');
  signal s_axis_tdata           : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid          : std_logic := '0';
  signal s_axis_tlast           : std_logic := '0';
  signal m_axis_tdata           : std_logic_vector(7 downto 0) := (others => '0');
  signal m_axis_tuser           : std_logic_vector(0 downto 0) := (others => '0');
  signal m_axis_tvalid          : std_logic := '0';
  signal m_axis_tlast           : std_logic := '0';

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
begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 1 ms);

  s_axis_tdata  <= (others => '0');
  s_axis_tvalid <= '0';
  s_axis_tlast  <= '0';
  filter_source_mac <= '1';

  reset <= '1';
  wait_clk(clk, 10);
  reset <= '0';
  enable <= '1';
  wait_clk(clk, 10);

  if run("packet_0_good_fcs") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    for i in 0 to C_INPUT_DATA_0'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_0(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_0'length-4 then -- Not the header or FCS
        if i = C_INPUT_DATA_0'length-5 then
          axi_expect(net, payload_checker, C_INPUT_DATA_0(i), "0", '1');
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_0(i), "0", '0');
        end if;
      end if;
      if i = C_INPUT_DATA_0'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_clk(clk, 10);
  elsif run("packet_1_bad_fcs") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    for i in 0 to C_INPUT_DATA_1'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_1(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_1'length-4 then  -- Not the header or FCS
        if i = C_INPUT_DATA_1'length-5 then
          axi_expect(net, payload_checker, C_INPUT_DATA_1(i), "1", '1'); -- Expect tuser high on tlast --> FCS fail
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_1(i), "0", '0');
        end if;
      end if;

      if i = C_INPUT_DATA_1'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);

  elsif run("packet_2_wrong_dest_mac") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    for i in 0 to C_INPUT_DATA_2'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_2(i);
      s_axis_tvalid <= '1';

      -- Not expect calls. The AXI signal checker will error if it gets any valids
        
      if i = C_INPUT_DATA_2'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);
  elsif run("packet_3_wrong_src_mac") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    for i in 0 to C_INPUT_DATA_3'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_3(i);
      s_axis_tvalid <= '1';

      -- Not expect calls. The AXI signal checker will error if it gets any valids
        
      if i = C_INPUT_DATA_3'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);

    check_equal(unsigned(dropped_packet_count), to_unsigned(1, dropped_packet_count'length), "Dropped packet count should be 1");

  elsif run("packet_4_broadcast_mac") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    for i in 0 to C_INPUT_DATA_4'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_4(i);
      s_axis_tvalid <= '1';

    -- Configure the AXI signal checkers expectations
    if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_4'length-4 then -- Not the header or FCS
      if i = C_INPUT_DATA_4'length-5 then
        axi_expect(net, payload_checker, C_INPUT_DATA_4(i), "0", '1');
      else
        axi_expect(net, payload_checker, C_INPUT_DATA_4(i), "0", '0');
      end if;
    end if;
        
      if i = C_INPUT_DATA_4'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);
  elsif run("back_to_back_packets") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";
    
    -- 1st packet
    for i in 0 to C_INPUT_DATA_0'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_0(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_0'length-4 then -- Not the header or FCS
        if i = C_INPUT_DATA_0'length-5 then
          axi_expect(net, payload_checker, C_INPUT_DATA_0(i), "0", '1');
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_0(i), "0", '0');
        end if;
      end if;
      if i = C_INPUT_DATA_0'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;

    s_axis_tlast  <= '0';
    
    -- 2nd packet
    for i in 0 to C_INPUT_DATA_1'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_1(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_1'length-4 then  -- Not the header or FCS
        if i = C_INPUT_DATA_1'length-5 then
          axi_expect(net, payload_checker, C_INPUT_DATA_1(i), "1", '1'); -- Expect tuser high on tlast --> FCS fail
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_1(i), "0", '0');
        end if;
      end if;

      if i = C_INPUT_DATA_1'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);
  elsif run("packet_4_broadcast_mac_with_tvalid_gaps") then
    source_mac      <= x"aabbccddeeff";
    destination_mac <= x"112233445566";

    for i in 0 to C_INPUT_DATA_4'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_4(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_ETH_HEADER_BYTES and i < C_INPUT_DATA_4'length-4 then -- Not the header or FCS
        if i = C_INPUT_DATA_4'length-5 then
          axi_expect(net, payload_checker, C_INPUT_DATA_4(i), "0", '1');
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_4(i), "0", '0');
        end if;
      end if;
          
      if i = C_INPUT_DATA_4'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
      s_axis_tvalid <= '0';
      s_axis_tlast  <= '0';
      wait_clk(clk, 8);

    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);

  end if;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- DUT
----------------------------------------

  i_dut : entity work.ethernet_deframer
  port map (
    clk                       => clk,
    reset                     => reset,
    --------------------------------------------------------
    enable_in                 => enable,
    idle_out                  => idle,
    filter_source_mac_in      => filter_source_mac,
    source_mac_in             => source_mac,
    destination_mac_in        => destination_mac,
    dropped_packet_count_out  => dropped_packet_count,
    --------------------------------------------------------
    s_axis_tdata_in           => s_axis_tdata,
    s_axis_tvalid_in          => s_axis_tvalid,
    s_axis_tlast_in           => s_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out          => m_axis_tdata,
    m_axis_tuser_out          => m_axis_tuser,
    m_axis_tvalid_out         => m_axis_tvalid,
    m_axis_tlast_out          => m_axis_tlast
  );

  ----------------------------------------
  -- Check data
  ----------------------------------------

  payload_checker_inst: entity work.axi_std_logic_checker
  generic map (
    check_tuser    => true,
    signal_checker => payload_checker
  )
  port map (
    clk      => clk,
    tdata    => m_axis_tdata,
    tuser    => m_axis_tuser,
    tvalid   => m_axis_tvalid,
    tlast    => m_axis_tlast
  );


end architecture;