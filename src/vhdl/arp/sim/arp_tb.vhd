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

entity arp_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of arp_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP               : time := 8 ns;

  constant C_READ_MIN_STALL   : natural := 1;
  constant C_READ_MAX_STALL   : natural := 10;
  signal READ_STALL_PROB      : real    := 0.9;

  constant payload_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("payload_checker"));

  ----------------------------------------
  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                 : std_logic := '0';
  signal reset               : std_logic := '0';

  signal send_arp            : std_logic;
  signal send_arp_ready      : std_logic;
  signal mac_address         : std_logic_vector(47 downto 0);
  signal ip_address          : std_logic_vector(31 downto 0);

  signal rx_axis_tdata       : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_axis_tvalid      : std_logic := '0';
  signal rx_axis_tlast       : std_logic := '0';

  signal eth_dest_mac        : std_logic_vector(47 downto 0);

  signal s_axis_tdata        : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid       : std_logic := '0';
  signal s_axis_tlast        : std_logic := '0';
  signal s_axis_tready       : std_logic := '0';

  signal m_axis_tdata        : std_logic_vector(7 downto 0) := (others => '0');
  signal m_axis_tuser        : std_logic_vector(0 downto 0) := (others => '0');
  signal m_axis_tvalid       : std_logic := '0';
  signal m_axis_tlast        : std_logic := '0';
  signal m_axis_tready       : std_logic := '0';


  signal fifo_write : std_logic := '0';
  signal fifo_full  : std_logic := '0';
  signal fifo_din   : std_logic_vector(9 downto 0) := (others => '0');
  signal fifo_dout   : std_logic_vector(9 downto 0) := (others => '0');
  signal fifo_empty : std_logic := '1';

  signal axi_eth_tdata          : std_logic_vector(7 downto 0);
  signal axi_eth_tvalid         : std_logic := '0';
  signal axi_eth_tuser        : std_logic_vector(0 downto 0) := (others => '0');
  signal axi_eth_tlast          : std_logic := '0';
  signal axi_eth_tready         : std_logic := '0';

  signal axi_pcap_tdata          : std_logic_vector(7 downto 0);
  signal axi_pcap_tvalid         : std_logic := '0';
  signal axi_pcap_tlast          : std_logic := '0';

  signal destination_mac        : std_logic_vector(47 downto 0) := (others => '1');

  signal sim_finish             : std_logic := '0';

  procedure send_rx_arp_request (
    signal clk_s           : in std_logic;
    signal rx_tdata_s      : out std_logic_vector(7 downto 0);
    signal rx_tvalid_s     : out std_logic;
    signal rx_tlast_s      : out std_logic;
    constant req_mac       : in std_logic_vector(47 downto 0);
    constant req_ip        : in std_logic_vector(31 downto 0);
    constant target_ip     : in std_logic_vector(31 downto 0)
  ) is
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    variable pkt : byte_array_t(0 to 41);
  begin
    -- Dest MAC: Broadcast
    pkt(0)  := x"FF"; pkt(1) := x"FF"; pkt(2) := x"FF"; pkt(3) := x"FF"; pkt(4) := x"FF"; pkt(5) := x"FF";
    -- Src MAC
    pkt(6)  := req_mac(47 downto 40); pkt(7)  := req_mac(39 downto 32);
    pkt(8)  := req_mac(31 downto 24); pkt(9)  := req_mac(23 downto 16);
    pkt(10) := req_mac(15 downto 8);  pkt(11) := req_mac(7 downto 0);
    -- Ethertype (0x0806)
    pkt(12) := x"08"; pkt(13) := x"06";
    -- HW Type (0x0001)
    pkt(14) := x"00"; pkt(15) := x"01";
    -- Proto Type (0x0800)
    pkt(16) := x"08"; pkt(17) := x"00";
    -- HW Len (6), Proto Len (4)
    pkt(18) := x"06"; pkt(19) := x"04";
    -- Opcode (0x0001 - Request)
    pkt(20) := x"00"; pkt(21) := x"01";
    -- SHA (Sender MAC)
    pkt(22) := req_mac(47 downto 40); pkt(23) := req_mac(39 downto 32);
    pkt(24) := req_mac(31 downto 24); pkt(25) := req_mac(23 downto 16);
    pkt(26) := req_mac(15 downto 8);  pkt(27) := req_mac(7 downto 0);
    -- SPA (Sender IP)
    pkt(28) := req_ip(31 downto 24); pkt(29) := req_ip(23 downto 16);
    pkt(30) := req_ip(15 downto 8);  pkt(31) := req_ip(7 downto 0);
    -- THA (Target MAC - 0s)
    pkt(32) := x"00"; pkt(33) := x"00"; pkt(34) := x"00";
    pkt(35) := x"00"; pkt(36) := x"00"; pkt(37) := x"00";
    -- TPA (Target IP)
    pkt(38) := target_ip(31 downto 24); pkt(39) := target_ip(23 downto 16);
    pkt(40) := target_ip(15 downto 8);  pkt(41) := target_ip(7 downto 0);

    for i in 0 to 41 loop
      rx_tdata_s  <= pkt(i);
      rx_tvalid_s <= '1';
      if i = 41 then
        rx_tlast_s <= '1';
      else
        rx_tlast_s <= '0';
      end if;
      wait until rising_edge(clk_s);
    end loop;

    rx_tdata_s  <= (others => '0');
    rx_tvalid_s <= '0';
    rx_tlast_s  <= '0';
  end procedure;

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

  rx_axis_tdata  <= (others => '0');
  rx_axis_tvalid <= '0';
  rx_axis_tlast  <= '0';

  send_arp    <= '0';
  mac_address <= x"aabbccddeeff";
  ip_address  <= x"c0a8002c";

  reset <= '1';
  wait_clk(clk, 10);
  reset <= '0';
  wait_clk(clk, 10);

  if run("pass_through_packet") then

    for i in 0 to 99 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 99 then
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        s_axis_tlast  <= '1';
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait until rising_edge(clk) and s_axis_tready = '1';
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_clk(clk, 10);

    wait_until_idle(net, payload_checker);

  elsif run("pass_through_packet_with_valid_gaps") then

    for i in 0 to 99 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));

      if i mod 3 = 0 then
        s_axis_tvalid <= '0';
        wait_clk(clk, 5);
      end if;

      s_axis_tvalid <= '1';
      if i = 99 then
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        s_axis_tlast  <= '1';
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait until rising_edge(clk) and s_axis_tready = '1';
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_clk(clk, 10);

    wait_until_idle(net, payload_checker);
  

  elsif run("insert_arp_at_same_time_as_data_packet") then
    send_arp <= '1';

    -- Packet 1
    for i in 0 to 155 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 155 then
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        s_axis_tlast  <= '1';
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait until rising_edge(clk) and (s_axis_tready = '1' or (send_arp = '1' and send_arp_ready = '1'));
      if send_arp = '1' then
        send_arp <= '0';
      end if;

    end loop;
    
    -- Packet 2
    for i in 0 to 111 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 111 then
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        s_axis_tlast  <= '1';
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait until rising_edge(clk) and (s_axis_tready = '1' or (send_arp = '1' and send_arp_ready = '1'));
      if send_arp = '1' then
        send_arp <= '0';
      end if;

    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_clk(clk, 10);

    wait_until_idle(net, payload_checker);

  elsif run("send_arp_with_no_data_flowing") then
    send_arp <= '1';
    wait until rising_edge(clk) and send_arp = '1' and send_arp_ready = '1';
    send_arp <= '0';

    wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';

  elsif run("send_two_arps_with_no_data_flowing") then
      send_arp <= '1';
      wait until rising_edge(clk) and send_arp = '1' and send_arp_ready = '1';
      send_arp <= '0';
      wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';
      send_arp <= '1';
      wait until rising_edge(clk) and send_arp = '1' and send_arp_ready = '1';
      send_arp <= '0';
      wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';

      wait_clk(clk, 500);

  elsif run("data_arrives_during_arp_send") then
    send_arp <= '1';
    wait until rising_edge(clk) and send_arp = '1' and send_arp_ready = '1';
    send_arp <= '0';

    wait_clk(clk, 2);

    for i in 0 to 99 loop
      s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
      s_axis_tvalid <= '1';
      if i = 99 then
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
        s_axis_tlast  <= '1';
      else
        axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
        s_axis_tlast  <= '0';
      end if;

      wait until rising_edge(clk) and s_axis_tready = '1';
    end loop;
    s_axis_tlast  <= '0';
    s_axis_tvalid <= '0';

    wait_clk(clk, 10);

    wait_until_idle(net, payload_checker);

  elsif run("respond_to_arp_request_for_our_ip") then

    send_rx_arp_request(clk, rx_axis_tdata, rx_axis_tvalid, rx_axis_tlast, x"112233445566", x"c0a80001", ip_address);
    wait_clk(clk, 1);
    wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';
    assert eth_dest_mac = x"112233445566" report "Destination MAC of ARP reply should match requester MAC" severity failure;

  elsif run("ignore_arp_request_for_different_ip") then
    send_rx_arp_request(clk, rx_axis_tdata, rx_axis_tvalid, rx_axis_tlast, x"112233445566", x"c0a80001", x"c0a80099");
    wait_clk(clk, 100);
    assert m_axis_tvalid = '0' or m_axis_tuser(0) = '0' report "No ARP reply should be generated for mismatched IP" severity failure;

  -- elsif run("receive_arp_request_during_tx_data") then
  --   for i in 0 to 99 loop
  --     s_axis_tdata  <= std_logic_vector(to_unsigned(i, s_axis_tdata'length));
  --     s_axis_tvalid <= '1';
  --     if i = 99 then
  --       axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '1');
  --       s_axis_tlast  <= '1';
  --     else
  --       axi_expect(net, payload_checker, std_logic_vector(to_unsigned(i, s_axis_tdata'length)), "0", '0');
  --       s_axis_tlast  <= '0';
  --     end if;

  --     if i = 5 then
  --       start_rx_arp_req <= '1';
  --     elsif i = 6 then
  --       start_rx_arp_req <= '0';
  --     end if;

  --     wait until rising_edge(clk) and s_axis_tready = '1';
  --   end loop;
  --   s_axis_tlast  <= '0';
  --   s_axis_tvalid <= '0';

  --   wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';
  --   assert eth_dest_mac = x"112233445566" report "Destination MAC of ARP reply should match requester MAC" severity failure;

  elsif run("interleaved_garp_and_arp_request") then
    send_arp <= '1';
    send_rx_arp_request(clk, rx_axis_tdata, rx_axis_tvalid, rx_axis_tlast, x"112233445566", x"c0a80001", ip_address);
    wait_clk(clk, 1);
    if send_arp_ready = '1' then
      send_arp <= '0';
    end if;

    -- Wait for both ARP packets to transmit
    wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';
    wait until m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1' and m_axis_tuser(0) = '1';

  end if;

  sim_finish <= '1';
  wait_clk(clk, 1);

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- DUT
----------------------------------------

  i_dut : entity work.arp
    port map (
      clk                    => clk,
      reset                  => reset,
      --------------------------------------------------------
      send_garp_in            => send_arp,
      send_garp_ready_out     => send_arp_ready,
      mac_address_in         => mac_address,
      ip_address_in          => ip_address,
      destination_mac_in     => destination_mac,
      --------------------------------------------------------
      rx_axis_tdata_in       => rx_axis_tdata,
      rx_axis_tvalid_in      => rx_axis_tvalid,
      rx_axis_tlast_in       => rx_axis_tlast,
      --------------------------------------------------------
      s_axis_tdata_in        => s_axis_tdata,
      s_axis_tvalid_in       => s_axis_tvalid,
      s_axis_tlast_in        => s_axis_tlast,
      s_axis_tready_out      => s_axis_tready,
      --------------------------------------------------------
      m_axis_tdata_out       => m_axis_tdata,
      m_axis_tuser_out       => m_axis_tuser,
      m_axis_tvalid_out      => m_axis_tvalid,
      m_axis_tlast_out       => m_axis_tlast,
      m_axis_tready_in       => m_axis_tready,
      --------------------------------------------------------
      eth_dest_mac_out       => eth_dest_mac
    );


  ----------------------------------------
  -- Generate ready signal
  ----------------------------------------

  p_read_rnd : process
    variable rnd : RandomPType;
    variable num_stall_cycles : natural := 0;
  begin
    rnd.InitSeed(rnd'instance_name);

    m_axis_tready <= '0';

    wait until reset = '0' and rising_edge(clk);

    while reset = '0' loop

      if rnd.RandReal(0.0, 1.0) < READ_STALL_PROB then
        num_stall_cycles := rnd.FavorSmall(C_READ_MIN_STALL, C_READ_MAX_STALL);
      end if;
      for stall in 0 to num_stall_cycles-1 loop
        wait until rising_edge(clk);
      end loop;
      m_axis_tready <= '1';

      wait until m_axis_tvalid = '1' and rising_edge(clk);
      
      m_axis_tready <= '0';
    end loop;

    wait_clk(clk, 10);

  end process;

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
    tvalid   => m_axis_tvalid and m_axis_tready and not m_axis_tuser(0),
    tlast    => m_axis_tlast
  );

  fifo_din <= m_axis_tuser(0) & m_axis_tlast & m_axis_tdata;
  fifo_write <= m_axis_tvalid and m_axis_tready and m_axis_tuser(0);

  i_tx_fifo : entity work.fifo
  generic map (
    G_DATA_WIDTH    => fifo_din'length,
    G_LOG2_DEPTH    => 8
  )
  port map (
    clk              => clk,
    sreset           => reset,
    --------------------------------------------------
    write_data       => fifo_din,
    write_en         => fifo_write,
    full             => fifo_full,
    --------------------------------------------------
    read_data        => fifo_dout,
    read_en          => axi_eth_tready,
    empty            => fifo_empty
  );

  axi_eth_tvalid <= not fifo_empty;
  axi_eth_tuser(0)  <= fifo_dout(9);
  axi_eth_tlast  <= fifo_dout(8);
  axi_eth_tdata  <= fifo_dout(7 downto 0);

  i_ethernet_framer : entity work.ethernet_framer
  port map (

    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => '1',
    idle_out               => open,
    source_mac_in          => mac_address,
    destination_mac_in     => eth_dest_mac,
    --------------------------------------------------------
    s_axis_tdata_in        => axi_eth_tdata,
    s_axis_tvalid_in       => axi_eth_tvalid,
    s_axis_tlast_in        => axi_eth_tlast,
    s_axis_tuser_in        => axi_eth_tuser,
    s_axis_tready_out      => axi_eth_tready,
    --------------------------------------------------------
    m_axis_tdata_out       => axi_pcap_tdata,
    m_axis_tvalid_out      => axi_pcap_tvalid,
    m_axis_tlast_out       => axi_pcap_tlast,
    m_axis_tready_in       => '1'
  );

  i_pcap_file_writer : entity work.pcap_file_writer
  generic map (
    G_LINK_TYPE         => 1,
    G_DATA_WIDTH_BYTES  => 1,
    G_FILENAME          => "arp_packet.pcap"
  )
  port map (
    clk                => clk,
    clk_en             => '1',
    
    s_axis_tdata_in    => axi_pcap_tdata,
    s_axis_tvalid_in   => axi_pcap_tvalid,
    s_axis_tlast_in    => axi_pcap_tlast,
    s_axis_tready_out  => open,
    finish_in          => sim_finish
  );


end architecture;