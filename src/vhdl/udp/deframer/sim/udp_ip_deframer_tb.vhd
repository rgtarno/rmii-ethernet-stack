library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;
use work.axi_std_logic_checker_pkg.all;

use work.utils.all;
use work.udp_ip_deframer_tb_data_pkg.all;

entity udp_ip_deframer_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of udp_ip_deframer_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 8 ns;

  constant C_PACKET_0_HEADER_BYTES     : natural := 20+8;
  constant C_PACKET_1_HEADER_BYTES     : natural := 20+16+8;
  constant C_PACKET_2_HEADER_BYTES     : natural := 20+8;
  constant C_PACKET_3_HEADER_BYTES     : natural := 20+8;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                    : std_logic := '0';
  signal reset                  : std_logic := '0';

  signal enable                 : std_logic := '0';
  signal idle                   : std_logic := '0';

  signal source_port            : std_logic_vector(15 downto 0) := (others => '0');
  signal destination_port       : std_logic_vector(15 downto 0) := (others => '0');
  signal destination_address    : std_logic_vector(31 downto 0) := (others => '0');
  signal broadcast_address      : std_logic_vector(31 downto 0) := (others => '0');

  signal s_axis_tdata           : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid          : std_logic := '0';
  signal s_axis_tlast           : std_logic := '0';
  signal m_axis_tdata           : std_logic_vector(7 downto 0) := (others => '0');
  signal m_axis_tuser           : std_logic_vector(0 downto 0) := (others => '0');
  signal m_axis_tvalid          : std_logic := '0';
  signal m_axis_tlast           : std_logic := '0';


  function ip_to_slv(b3 : natural;b2 : natural;b1 : natural;b0 : natural) return std_logic_vector is
    variable ret : std_logic_vector(31 downto 0) := (others => '0');
  begin
    ret(31 downto 24) := std_logic_vector(to_unsigned(b3, 8));
    ret(23 downto 16) := std_logic_vector(to_unsigned(b2, 8));
    ret(15 downto 8) := std_logic_vector(to_unsigned(b1, 8));
    ret(7 downto 0) := std_logic_vector(to_unsigned(b0, 8));
    return ret;
  end function;

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

  reset <= '1';
  wait_clk(clk, 10);
  reset <= '0';
  enable <= '1';
  wait_clk(clk, 10);

  if run("packet_0_ip_and_port_match") then
    source_port         <= x"2af9";
    destination_port    <= x"2afa";
    destination_address <= ip_to_slv(192, 168, 0, 2);
    broadcast_address   <= ip_to_slv(192, 168, 0, 255);

    for i in 0 to C_INPUT_DATA_0'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_0(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_PACKET_0_HEADER_BYTES then
        if i = C_INPUT_DATA_0'length-1 then
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

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);
  elsif run("packet_1_ip_and_port_match_with_ip_header_options") then
    source_port         <= x"2af9";
    destination_port    <= x"2afa";
    destination_address <= ip_to_slv(192, 168, 0, 2);
    broadcast_address   <= ip_to_slv(192, 168, 0, 255);

    for i in 0 to C_INPUT_DATA_1'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_1(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_PACKET_1_HEADER_BYTES then
        if i = C_INPUT_DATA_1'length-1 then
          axi_expect(net, payload_checker, C_INPUT_DATA_1(i), "0", '1');
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

  elsif run("packet_2_broadcast_ip") then
    source_port         <= x"2af9";
    destination_port    <= x"2afa";
    destination_address <= ip_to_slv(192, 168, 0, 2);
    broadcast_address   <= ip_to_slv(192, 168, 0, 255);

    for i in 0 to C_INPUT_DATA_2'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_2(i);
      s_axis_tvalid <= '1';

      -- Configure the AXI signal checkers expectations
      if i >= C_PACKET_2_HEADER_BYTES then
        if i = C_INPUT_DATA_2'length-1 then
          axi_expect(net, payload_checker, C_INPUT_DATA_2(i), "0", '1');
        else
          axi_expect(net, payload_checker, C_INPUT_DATA_2(i), "0", '0');
        end if;
      end if;
      if i = C_INPUT_DATA_2'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);

  elsif run("packet_3_wrong_dst_port") then
    source_port         <= x"2af9";
    destination_port    <= x"2afa";
    destination_address <= ip_to_slv(192, 168, 0, 2);
    broadcast_address   <= ip_to_slv(192, 168, 0, 255);

    for i in 0 to C_INPUT_DATA_3'length-1 loop
      s_axis_tdata  <= C_INPUT_DATA_3(i);
      s_axis_tvalid <= '1';

      -- Expect no output

      if i = C_INPUT_DATA_3'length-1 then
        s_axis_tlast  <= '1';
      end if;
      wait_clk(clk, 1);
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_until_idle(net, payload_checker);

    wait_clk(clk, 10);

    elsif run("packet_0_4_times") then
      source_port         <= x"2af9";
      destination_port    <= x"2afa";
      destination_address <= ip_to_slv(192, 168, 0, 2);
      broadcast_address   <= ip_to_slv(192, 168, 0, 255);

      for j in 0 to 3 loop
  
        for i in 0 to C_INPUT_DATA_0'length-1 loop
          s_axis_tdata  <= C_INPUT_DATA_0(i);
          s_axis_tvalid <= '1';
    
          -- Configure the AXI signal checkers expectations
          if i >= C_PACKET_0_HEADER_BYTES then
            if i = C_INPUT_DATA_0'length-1 then
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

      end loop;
  
      wait_until_idle(net, payload_checker);
  
      wait_clk(clk, 10);

    elsif run("good_and_bad_packets_mixed") then
      source_port         <= x"2af9";
      destination_port    <= x"2afa";
      destination_address <= ip_to_slv(192, 168, 0, 2);
      broadcast_address   <= ip_to_slv(192, 168, 0, 255);
      
      -- 4x good packets
      for j in 0 to 3 loop
        for i in 0 to C_INPUT_DATA_0'length-1 loop
          s_axis_tdata  <= C_INPUT_DATA_0(i);
          s_axis_tvalid <= '1';
    
          -- Configure the AXI signal checkers expectations
          if i >= C_PACKET_0_HEADER_BYTES then
            if i = C_INPUT_DATA_0'length-1 then
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
      end loop;

      -- 1x bad packet
      for i in 0 to C_INPUT_DATA_3'length-1 loop
        s_axis_tdata  <= C_INPUT_DATA_3(i);
        s_axis_tvalid <= '1';
  
        -- Expect no output
  
        if i = C_INPUT_DATA_3'length-1 then
          s_axis_tlast  <= '1';
        end if;
        wait_clk(clk, 1);
      end loop;
      s_axis_tlast  <= '0';
      s_axis_tvalid <= '0';

      -- 4x good packets
      for j in 0 to 3 loop
  
        for i in 0 to C_INPUT_DATA_0'length-1 loop
          s_axis_tdata  <= C_INPUT_DATA_0(i);
          s_axis_tvalid <= '1';
    
          -- Configure the AXI signal checkers expectations
          if i >= C_PACKET_0_HEADER_BYTES then
            if i = C_INPUT_DATA_0'length-1 then
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
    
      end loop;
  
    wait_until_idle(net, payload_checker);
  
    wait_clk(clk, 10);

  end if;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- DUT
----------------------------------------

  i_dut : entity work.udp_ip_deframer
  port map (
    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => enable,
    idle_out               => idle,
    source_port_in         => source_port,
    destination_port_in    => destination_port,
    destination_address_in => destination_address,
    broadcast_address_in   => broadcast_address,
    --------------------------------------------------------
    s_axis_tdata_in        => s_axis_tdata,
    s_axis_tvalid_in       => s_axis_tvalid,
    s_axis_tlast_in        => s_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out       => m_axis_tdata,
    m_axis_tvalid_out      => m_axis_tvalid,
    m_axis_tlast_out       => m_axis_tlast
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