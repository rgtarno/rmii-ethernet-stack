library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity udp_ip_framer_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of udp_ip_framer_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                 : time := 8 ns;

  constant C_NUM_PACKETS        : natural := 200;

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                    : std_logic := '0';
  signal reset                  : std_logic := '0';
  signal sim_finish             : std_logic := '0';


  signal enable_in              : std_logic;
  signal idle_out               : std_logic;
  signal source_port_in         : std_logic_vector(15 downto 0);
  signal destination_port_in    : std_logic_vector(15 downto 0);
  signal src_address_in         : std_logic_vector(31 downto 0);
  signal destination_address_in : std_logic_vector(31 downto 0);
  signal checksum_init_in       : std_logic_vector(15 downto 0);

  signal s_axis_tdata_in        : std_logic_vector(7 downto 0);
  signal s_axis_tvalid_in       : std_logic := '0';
  signal s_axis_tlast_in        : std_logic;
  signal s_axis_tready_out      : std_logic;

  signal axi_udp_tdata          : std_logic_vector(7 downto 0);
  signal axi_udp_tuser          : std_logic_vector(10 downto 0);
  signal axi_udp_tvalid         : std_logic := '0';
  signal axi_udp_tlast          : std_logic := '0';
  signal axi_udp_tready         : std_logic := '0';

  signal source_mac             : std_logic_vector(47 downto 0);
  signal destination_mac        : std_logic_vector(47 downto 0);

  signal axi_eth_tdata          : std_logic_vector(7 downto 0);
  signal axi_eth_tvalid         : std_logic := '0';
  signal axi_eth_tlast          : std_logic := '0';
  signal axi_eth_tready         : std_logic := '0';

  constant C_MIN_STALL          : natural := 1;
  constant C_MAX_STALL          : natural := 10;
  signal STALL_PROB             : real    := 0.73;

  signal packet_out_counter : std_logic_vector(9 downto 0) := (others => '0');

begin

  test_runner_watchdog(runner, 10 ms);

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
  variable counter : unsigned(7 downto 0) := (others => '0');
  variable rnd              : RandomPType;
  variable packet_length_bytes : integer;
begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 5 ms);

  rnd.InitSeed(rnd'instance_name);
  
  while test_suite loop

    s_axis_tdata_in   <= (others => '0');
    s_axis_tvalid_in  <= '0';
    s_axis_tlast_in   <= '0';

    reset <= '1';
    wait_clk(clk, 10);
    reset <= '0';
    wait_clk(clk, 10);

    if run("Dev") then
      source_port_in          <= x"0400";
      destination_port_in     <= x"0400";
      src_address_in          <= x"c0a8002c";
      destination_address_in  <= x"c0a80004";
      checksum_init_in        <= x"4693";

      source_mac              <= x"aabbccddeeff";
      destination_mac         <= x"112233445566";

      for p in 0 to C_NUM_PACKETS-1 loop

        packet_length_bytes := rnd.RandInt(1, 500);
        
        for i in 0 to packet_length_bytes-1 loop
          s_axis_tdata_in   <= std_logic_vector(to_unsigned(i, 8));
          s_axis_tvalid_in  <= '1';
          s_axis_tlast_in   <= '0';
          if i = packet_length_bytes-1 then
            s_axis_tlast_in   <= '1';
          end if;
          wait until rising_edge(clk) and s_axis_tready_out = '1';
        end loop;

      end loop;

      s_axis_tvalid_in  <= '0';
      s_axis_tlast_in   <= '0';

      wait until packet_out_counter = std_logic_vector(to_unsigned(C_NUM_PACKETS, packet_out_counter'length));

      wait_clk(clk, 10);
      sim_finish <= '1';
      wait_clk(clk, 1);

    end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here

end process;

enable_in <= not reset;

----------------------------------------
-- DUT
----------------------------------------
i_udp_ip_framer : entity work.udp_ip_framer
  port map(

    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => enable_in,
    idle_out               => idle_out,
    source_port_in         => source_port_in,
    destination_port_in    => destination_port_in,
    src_address_in         => src_address_in,
    destination_address_in => destination_address_in,
    ip_checksum_init_in    => checksum_init_in,
    --------------------------------------------------------
    s_axis_tdata_in        => s_axis_tdata_in,
    s_axis_tvalid_in       => s_axis_tvalid_in,
    s_axis_tlast_in        => s_axis_tlast_in,
    s_axis_tready_out      => s_axis_tready_out,
    --------------------------------------------------------
    m_axis_tdata_out       => axi_udp_tdata,
    m_axis_tvalid_out      => axi_udp_tvalid,
    m_axis_tlast_out       => axi_udp_tlast,
    m_axis_tready_in       => axi_udp_tready
  );

----------------------------------------
-- Ethernet framer
----------------------------------------
i_ethernet_framer : entity work.ethernet_framer
  port map (

    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => enable_in,
    idle_out               => open,
    source_mac_in          => source_mac,
    destination_mac_in     => destination_mac,
    --------------------------------------------------------
    s_axis_tdata_in        => axi_udp_tdata,
    s_axis_tvalid_in       => axi_udp_tvalid,
    s_axis_tlast_in        => axi_udp_tlast,
    s_axis_tready_out      => axi_udp_tready,
    --------------------------------------------------------
    m_axis_tdata_out       => axi_eth_tdata,
    m_axis_tvalid_out      => axi_eth_tvalid,
    m_axis_tlast_out       => axi_eth_tlast,
    m_axis_tready_in       => axi_eth_tready
  );

----------------------------------------
-- Write output to .pcap file
----------------------------------------

i_pcap_file_writer : entity work.pcap_file_writer
  generic map (
    G_LINK_TYPE         => 1,
    G_DATA_WIDTH_BYTES  => 1,
    G_FILENAME          => "packet_data.pcap"
  )
  port map (
    clk                => clk,
    clk_en             => axi_eth_tready,
    
    s_axis_tdata_in    => axi_eth_tdata,
    s_axis_tvalid_in   => axi_eth_tvalid,
    s_axis_tlast_in    => axi_eth_tlast,
    s_axis_tready_out  => open,
    finish_in          => sim_finish
  );


----------------------------------------
-- Generate random backpressure pattern
----------------------------------------
process
  variable rnd              : RandomPType;
  variable num_stall_cycles : natural := 0;
begin
  rnd.InitSeed(rnd'instance_name);

  wait until enable_in = '1' and rising_edge(clk);

  while sim_finish /= '1' loop
    
    if rnd.Uniform(0.0, 1.0) < STALL_PROB then
      num_stall_cycles := rnd.FavorSmall(C_MIN_STALL, C_MAX_STALL);
    end if;
    for stall in 0 to num_stall_cycles-1 loop
       wait until rising_edge(clk);
    end loop;

    axi_eth_tready <= '1';
    wait until axi_eth_tvalid = '1' and rising_edge(clk);
    axi_eth_tready <= '0';
  end loop;

  wait_clk(clk, 10);

end process;


i_last_counter : entity work.pulse_counter
port map (
  clk              => clk,
  reset            => reset,
  --------------------------------------------------
  enable_in        => axi_eth_tready and axi_eth_tvalid and axi_eth_tlast,
  --------------------------------------------------
  count_out        => packet_out_counter
);

end architecture;
