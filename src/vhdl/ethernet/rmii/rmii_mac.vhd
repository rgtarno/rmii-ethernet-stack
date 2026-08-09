library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity rmii_mac is
  generic (
    G_USER_CLK_FREQ_Hz          : natural := 125000000;
    G_MDC_FREQ_Hz               : natural := 50000;
    G_RX_FIFO_LOG2_DEPTH        : natural := 11;
    G_TX_FIFO_LOG2_DEPTH        : natural := 11
  );
  port (
    clk_user                    : in std_logic;
    clk50                       : in std_logic;
    reset                       : in std_logic;
    --------------------------------------------------------
    source_mac_in               : in std_logic_vector(47 downto 0);
    destination_mac_in          : in std_logic_vector(47 downto 0);
    eth_framer_enable_in        : in std_logic;
    eth_framer_idle_out         : out std_logic;
    send_garp_in                : in std_logic;
    send_garp_ready_out         : out std_logic;
    ip_address_in               : in std_logic_vector(31 downto 0);
    eth_deframer_enable_in      : in std_logic;
    eth_deframer_idle_out       : out std_logic;
    eth_deframer_drop_count_out : out std_logic_vector(15 downto 0);
    --------------------------------------------------------
    mdio_ready_out              : out std_logic;
    mdio_send_msg_in            : in std_logic;
    mdio_write_enable_in        : in std_logic;
    mdio_phy_address_in         : in std_logic_vector(4 downto 0);
    mdio_reg_address_in         : in std_logic_vector(4 downto 0);
    mdio_write_data_in          : in std_logic_vector(15 downto 0);
    mdio_read_data_out          : out std_logic_vector(15 downto 0);
    mdio_read_data_valid_out    : out std_logic;
    mdio_op_done                : out std_logic;
    --------------------------------------------------------
    m_tx_axis_tdata             : in std_logic_vector(7 downto 0);
    m_tx_axis_tvalid            : in std_logic;
    m_tx_axis_tlast             : in std_logic;
    m_tx_axis_tready            : out std_logic;
    --------------------------------------------------------
    s_rx_axis_tdata             : out std_logic_vector(7 downto 0);
    s_rx_axis_tvalid            : out std_logic;
    s_rx_axis_tlast             : out std_logic;
    --------------------------------------------------------
    num_tx_bytes                : out std_logic_vector(31 downto 0);
    num_tx_packets              : out std_logic_vector(31 downto 0);
    num_rx_bytes                : out std_logic_vector(31 downto 0);
    num_rx_packets              : out std_logic_vector(31 downto 0);
    num_bad_carrier_events      : out std_logic_vector(7 downto 0);
    dropped_packets_count       : out std_logic_vector(15 downto 0);
    rx_overflowed               : out std_logic;
    --------------------------------------------------------
    tx_en                       : out std_logic;
    txd                         : out std_logic_vector(1 downto 0);
    crs_dv                      : in std_logic;
    rxd                         : in std_logic_vector(1 downto 0);
    --------------------------------------------------------
    mdio_in                     : in std_logic;
    mdio_out                    : out std_logic;
    mdio_tristate_out           : out std_logic;
    mdc_out                     : out std_logic
  );
end entity rmii_mac;

architecture rtl of rmii_mac is

  ----------------------------------------------------
  -- SIGNAL
  ----------------------------------------------------
  signal reset_clk50      : std_logic;

  signal arp_tx_axis_tdata         : std_logic_vector(7 downto 0);
  signal arp_tx_axis_tuser         : std_logic_vector(0 downto 0);
  signal arp_tx_axis_tvalid        : std_logic;
  signal arp_tx_axis_tlast         : std_logic;
  signal arp_tx_axis_tready        : std_logic;

  signal eth_tx_axis_tdata         : std_logic_vector(7 downto 0);
  signal eth_tx_axis_tvalid        : std_logic;
  signal eth_tx_axis_tlast         : std_logic;
  signal eth_tx_axis_tready        : std_logic;

  signal clk50_tx_axis_tdata       : std_logic_vector(7 downto 0);
  signal clk50_tx_axis_tvalid      : std_logic;
  signal clk50_tx_axis_tlast       : std_logic;
  signal clk50_tx_axis_tready      : std_logic;

  signal clk50_rx_axis_tdata       : std_logic_vector(7 downto 0);
  signal clk50_rx_axis_tvalid      : std_logic;
  signal clk50_rx_axis_tlast       : std_logic;

  signal rx_afifo_read             : std_logic;
  signal rx_afifo_empty            : std_logic;
  signal rx_afifo_din              : std_logic_vector(8 downto 0);
  signal rx_afifo_dout             : std_logic_vector(8 downto 0);

  signal clk_user_rx_axis_tdata    : std_logic_vector(7 downto 0);
  signal clk_user_rx_axis_tvalid   : std_logic;
  signal clk_user_rx_axis_tlast    : std_logic;

  signal eth_rx_axis_tdata         : std_logic_vector(7 downto 0);
  signal eth_tx_axis_tuser         : std_logic_vector(0 downto 0);
  signal eth_rx_axis_tvalid        : std_logic;
  signal eth_rx_axis_tlast         : std_logic;

  signal eth_dest_mac_from_arp     : std_logic_vector(47 downto 0);
  signal false_carrier             : std_logic;

begin

  ----------------------------------------------------
  -- Transfer reset from clk_user to clk50
  ----------------------------------------------------
  i_reset_pulse_transfer : entity work.pulse_transfer
    port map (
      clk_a              => clk_user,
      clk_b              => clk50,
      a_pulse_in         => reset,
      a_ready_out        => open,
  
      b_pulse_out        => reset_clk50
    );

  ----------------------------------------------------
  -- MDIO
  ----------------------------------------------------
  i_mdio : entity work.mdio
  generic map (
    G_CLK_FREQ_Hz       => G_USER_CLK_FREQ_Hz,
    G_MDC_FREQ_Hz       => G_MDC_FREQ_Hz
  )
  port map (
    clk                 => clk_user,
    reset               => reset,
    --------------------------------------------------------
    ready_out           => mdio_ready_out,
    send_msg_in         => mdio_send_msg_in,
    write_enable_in     => mdio_write_enable_in,
    phy_address_in      => mdio_phy_address_in,
    reg_address_in      => mdio_reg_address_in,
    write_data_in       => mdio_write_data_in,
    --------------------------------------------------------
    read_data_out       => mdio_read_data_out,
    op_done             => mdio_op_done,
    --------------------------------------------------------
    mdio_in             => mdio_in,
    mdio_out            => mdio_out,
    mdio_tristate_out   => mdio_tristate_out,
    mdc_out             => mdc_out
  );

  ----------------------------------------------------
  -- TRANSMIT
  ----------------------------------------------------

  i_arp_transmit : entity work.arp
  port map (
    clk                    => clk_user,
    reset                  => reset,
    --------------------------------------------------------
    send_garp_in           => send_garp_in,
    send_garp_ready_out    => send_garp_ready_out,
    mac_address_in         => source_mac_in,
    ip_address_in          => ip_address_in,
    destination_mac_in     => destination_mac_in,
    --------------------------------------------------------
    rx_axis_tdata_in       => clk_user_rx_axis_tdata,
    rx_axis_tvalid_in      => clk_user_rx_axis_tvalid,
    rx_axis_tlast_in       => clk_user_rx_axis_tlast,
    --------------------------------------------------------
    s_axis_tdata_in        => m_tx_axis_tdata,
    s_axis_tvalid_in       => m_tx_axis_tvalid,
    s_axis_tlast_in        => m_tx_axis_tlast,
    s_axis_tready_out      => m_tx_axis_tready,
    --------------------------------------------------------
    m_axis_tdata_out       => arp_tx_axis_tdata,
    m_axis_tuser_out       => arp_tx_axis_tuser,
    m_axis_tvalid_out      => arp_tx_axis_tvalid,
    m_axis_tlast_out       => arp_tx_axis_tlast,
    m_axis_tready_in       => arp_tx_axis_tready,
    --------------------------------------------------------
    eth_dest_mac_out       => eth_dest_mac_from_arp
  );

  i_ethernet_framer : entity work.ethernet_framer
  port map (

    clk                    => clk_user,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => eth_framer_enable_in,
    idle_out               => eth_framer_idle_out,
    source_mac_in          => source_mac_in,
    destination_mac_in     => eth_dest_mac_from_arp,
    --------------------------------------------------------
    s_axis_tdata_in        => arp_tx_axis_tdata,
    s_axis_tuser_in        => arp_tx_axis_tuser,
    s_axis_tvalid_in       => arp_tx_axis_tvalid,
    s_axis_tlast_in        => arp_tx_axis_tlast,
    s_axis_tready_out      => arp_tx_axis_tready,
    --------------------------------------------------------
    m_axis_tdata_out       => eth_tx_axis_tdata,
    m_axis_tvalid_out      => eth_tx_axis_tvalid,
    m_axis_tlast_out       => eth_tx_axis_tlast,
    m_axis_tready_in       => eth_tx_axis_tready
  );

  i_tx_packet_afifo : entity work.packet_afifo
  generic map (
    G_LOG2_DEPTH          => G_TX_FIFO_LOG2_DEPTH
  )
  port map (
    reset                  => reset,
    --------------------------------------------------------
    wr_clk                 => clk_user,
    s_axis_tdata_in        => eth_tx_axis_tdata,
    s_axis_tvalid_in       => eth_tx_axis_tvalid,
    s_axis_tlast_in        => eth_tx_axis_tlast,
    s_axis_tready_out      => eth_tx_axis_tready,
    --------------------------------------------------------
    rd_clk                 => clk50,
    m_axis_tdata_out       => clk50_tx_axis_tdata,
    m_axis_tvalid_out      => clk50_tx_axis_tvalid,
    m_axis_tlast_out       => clk50_tx_axis_tlast,
    m_axis_tready_in       => clk50_tx_axis_tready
  );


  i_rmii_mac_tx : entity work.rmii_mac_tx
  port map (
    clk50               => clk50,
    reset               => reset_clk50,
    --------------------------------------------------------
    s_axis_tdata        => clk50_tx_axis_tdata,
    s_axis_tvalid       => clk50_tx_axis_tvalid,
    s_axis_tlast        => clk50_tx_axis_tlast,
    s_axis_tready       => clk50_tx_axis_tready,
    --------------------------------------------------------
    tx_en               => tx_en,
    txd                 => txd
  );

  ----------------------------------------------------
  -- RECEIVE
  ----------------------------------------------------

  i_rmii_mac_rx : entity work.rmii_mac_rx
  port map (
    clk50               => clk50,
    reset               => reset_clk50,
    --------------------------------------------------------
    m_axis_tdata_out    => clk50_rx_axis_tdata,
    m_axis_tvalid_out   => clk50_rx_axis_tvalid,
    m_axis_tlast_out    => clk50_rx_axis_tlast,
    --------------------------------------------------------
    false_carrier_out   => false_carrier,
    --------------------------------------------------------
    crs_dv              => crs_dv,
    rxd                 => rxd
  );

  ----------------------------------------------------
  -- Cross clock domains
  ----------------------------------------------------
  rx_afifo_din <= clk50_rx_axis_tlast & clk50_rx_axis_tdata;

  i_afifo : entity work.afifo
  generic map (
    G_DATA_WIDTH     => 9,
    G_LOG2_DEPTH     => 11,
    G_FWFT           => true
  )
  port map (
    wr_clk           => clk50,
    reset            => reset_clk50,
    reset_busy       => open,
    write_data       => rx_afifo_din,
    write_en         => clk50_rx_axis_tvalid,
    full             => open,
    --------------------------------------------------
    rd_clk           => clk_user,
    read_data        => rx_afifo_dout,
    read_en          => rx_afifo_read,
    empty            => rx_afifo_empty
  );

  rx_afifo_read <= '1';

  clk_user_rx_axis_tdata  <= rx_afifo_dout(7 downto 0);
  clk_user_rx_axis_tvalid <= not rx_afifo_empty;
  clk_user_rx_axis_tlast  <= rx_afifo_dout(8);

  ----------------------------------------------------
  -- Ethernet deframer
  ----------------------------------------------------

  i_ethernet_deframer : entity work.ethernet_deframer
  port map (
    clk                       => clk_user,
    reset                     => reset,
    --------------------------------------------------------
    enable_in                 => eth_deframer_enable_in,
    idle_out                  => eth_deframer_idle_out,
    filter_source_mac_in      => '0',
    source_mac_in             => (others => '0'),
    destination_mac_in        => source_mac_in,
    dropped_packet_count_out  => eth_deframer_drop_count_out,
    --------------------------------------------------------
    s_axis_tdata_in           => clk_user_rx_axis_tdata,
    s_axis_tvalid_in          => clk_user_rx_axis_tvalid,
    s_axis_tlast_in           => clk_user_rx_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out          => eth_rx_axis_tdata,
    m_axis_tuser_out          => eth_tx_axis_tuser,
    m_axis_tvalid_out         => eth_rx_axis_tvalid,
    m_axis_tlast_out          => eth_rx_axis_tlast
  );

  ----------------------------------------------------
  -- Buffer to discard bad frames
  ----------------------------------------------------

  i_rx_packet_buffer : entity work.rx_packet_buffer
  generic map (
    G_LOG2_DEPTH           => G_RX_FIFO_LOG2_DEPTH
  )
  port map (
    clk                    => clk_user,
    reset                  => reset,
    --------------------------------------------------------
    overflowed_out         => rx_overflowed,
    dropped_packets_count  => dropped_packets_count,
    --------------------------------------------------------
    s_axis_tdata_in        => eth_rx_axis_tdata,
    s_axis_tuser_in        => eth_tx_axis_tuser,
    s_axis_tvalid_in       => eth_rx_axis_tvalid,
    s_axis_tlast_in        => eth_rx_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out       => s_rx_axis_tdata,
    m_axis_tvalid_out      => s_rx_axis_tvalid,
    m_axis_tlast_out       => s_rx_axis_tlast,
    m_axis_tready_in       => '1'
  );

  ----------------------------------------------------
  -- STATS COUNTERS
  ---------------------------------------------------
  i_rmii_mac_counters : entity work.rmii_mac_counters
  port map (
    clk                 => clk_user,
    reset               => reset,
    --------------------------------------------------------
    tx_data_tvalid      => eth_tx_axis_tvalid,
    tx_data_tlast       => eth_tx_axis_tlast,
    tx_data_tready      => eth_tx_axis_tready,
    rx_data_tvalid      => clk_user_rx_axis_tvalid,
    rx_data_tlast       => clk_user_rx_axis_tlast,
    rx_bad_carrier      => false_carrier,
    --------------------------------------------------------
    num_tx_bytes        => num_tx_bytes,
    num_tx_packets      => num_tx_packets,
    num_rx_bytes              => num_rx_bytes,
    num_rx_packets            => num_rx_packets,
    num_rx_bad_carrier_events => num_bad_carrier_events
  );

end architecture;
