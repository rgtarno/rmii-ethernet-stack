library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.apb_data_types.all;

entity rmii_mac_comp is
  port (
    clk_user                 : in std_logic;
    clk50                    : in std_logic;
    --------------------------------------------------------
    apb_cmd_in               : in apb_cmd_t;
    apb_rsp_out              : out apb_rsp_t;
    --------------------------------------------------------
    m_tx_axis_tdata          : in std_logic_vector(7 downto 0);
    m_tx_axis_tvalid         : in std_logic;
    m_tx_axis_tlast          : in std_logic;
    m_tx_axis_tready         : out std_logic;
    --------------------------------------------------------
    s_rx_axis_tdata          : out std_logic_vector(7 downto 0);
    s_rx_axis_tvalid         : out std_logic;
    s_rx_axis_tlast          : out std_logic;
    --------------------------------------------------------
    tx_en                    : out std_logic;
    txd                      : out std_logic_vector(1 downto 0);
    crs_dv                   : in std_logic;
    rxd                      : in std_logic_vector(1 downto 0);
    --------------------------------------------------------
    mdio_in                  : in std_logic;
    mdio_out                 : out std_logic;
    mdio_tristate_out        : out std_logic;
    mdc_out                  : out std_logic
  );
end entity rmii_mac_comp;

architecture rtl of rmii_mac_comp is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------

  constant C_COMPONENT_ID                 : natural := 102;

  constant C_REG_NUM_MDIO_CONTROL      : natural := 1;
  constant C_REG_NUM_MDIO_RESET        : natural := 2;
  constant C_REG_NUM_MDIO_PHY_ADDR     : natural := 3;
  constant C_REG_NUM_MDIO_REG_ADDR     : natural := 4;
  constant C_REG_NUM_MDIO_WRITE_DATA   : natural := 5;
  constant C_REG_NUM_MDIO_READ_DATA    : natural := 6;
  constant C_REG_NUM_ETH_CONTROL       : natural := 7;
  constant C_REG_NUM_SRC_MAC_UPPER     : natural := 8;
  constant C_REG_NUM_SRC_MAC_LOWER     : natural := 9;
  constant C_REG_NUM_DST_MAC_UPPER     : natural := 10;
  constant C_REG_NUM_DST_MAC_LOWER     : natural := 11;
  constant C_REG_NUM_SRC_IP            : natural := 12;
  constant C_REG_NUM_SEND_ARP          : natural := 13;

  constant C_REG_NUM_TX_BYTES          : natural := 14;
  constant C_REG_NUM_TX_PACKETS        : natural := 15;
  constant C_REG_NUM_RX_BYTES          : natural := 16;
  constant C_REG_NUM_RX_PACKETS        : natural := 17;
  constant C_REG_NUM_RX_BAD_CARRIERS   : natural := 18;
  constant C_REG_NUM_RX_ETH_DROPS      : natural := 19;
  constant C_REG_NUM_RX_ETH_FCS_FAILS  : natural := 20;
  constant C_REG_NUM_MDIO_SEND_COUNT   : natural := 21;
  constant C_REG_NUM_MDIO_RX_COUNT     : natural := 22;
  constant C_REG_NUM_MDIO_MAC_RX_COUNT : natural := 23;
  constant C_REG_NUM_DEBUG             : natural := 24;

  constant C_NUM_RMII_MAC_COMP_REGISTERS  : natural := C_REG_NUM_DEBUG +1;

  ----------------------------------------------------
  -- SIGNAL
  ----------------------------------------------------

  signal reg_rdata          : slv32_array_t(C_NUM_RMII_MAC_COMP_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_wdata          : slv32_array_t(C_NUM_RMII_MAC_COMP_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_wen            : std_logic_vector(C_NUM_RMII_MAC_COMP_REGISTERS-1 downto 0) := (others => '0');


  signal reset                 : std_logic := '0';

  signal mdio_ready            : std_logic := '0';
  signal send_msg              : std_logic := '0';
  signal write_not_read        : std_logic := '0';
  signal response_received     : std_logic := '0';
  signal phy_addr              : std_logic_vector(4 downto 0);
  signal reg_addr              : std_logic_vector(4 downto 0);
  signal write_data            : std_logic_vector(15 downto 0);

  signal mdio_read_data_r      : std_logic_vector(15 downto 0);
  signal mdio_op_done          : std_logic := '0';
  signal mdio_op_done_r        : std_logic := '0';

  signal mdio_send_counter     : unsigned(7 downto 0) := (others => '0');
  signal mdio_receive_counter  : unsigned(7 downto 0) := (others => '0');

  signal eth_framer_enable     : std_logic := '0';
  signal eth_framer_idle       : std_logic;
  signal source_mac            : std_logic_vector(47 downto 0);
  signal destination_mac       : std_logic_vector(47 downto 0);
  signal send_arp              : std_logic := '0';
  signal send_arp_ready        : std_logic;
  signal src_ip_address        : std_logic_vector(31 downto 0);

  signal eth_deframer_enable   : std_logic := '0';
  signal eth_deframer_idle     : std_logic;
  signal eth_deframer_drop_count : std_logic_vector(15 downto 0);

  signal num_tx_bytes          : std_logic_vector(31 downto 0);
  signal num_tx_packets        : std_logic_vector(31 downto 0);
  signal num_rx_bytes          : std_logic_vector(31 downto 0);
  signal num_rx_packets        : std_logic_vector(31 downto 0);
  signal num_mac_rx_packets    : std_logic_vector(31 downto 0);
  signal num_bad_carrier_events : std_logic_vector(7 downto 0);

  signal overflowed_out         : std_logic;
  signal dropped_packets_count  : std_logic_vector(15 downto 0);

begin

----------------------------------------
-- Register interface
----------------------------------------

i_regsiter_block : entity work.component_register_block
  generic map (
    G_NUM_REGISTERS => C_NUM_RMII_MAC_COMP_REGISTERS
  )
  port map (
    clk              => clk_user,
    --------------------------------------------------
    apb_cmd_in       => apb_cmd_in,
    apb_rsp_out      => apb_rsp_out,
    --------------------------------------------------
    reg_rdata_in     => reg_rdata,
    reg_wdata_out    => reg_wdata,
    reg_ren_out      => open,
    reg_wen_out      => reg_wen
  );

  reg_rdata(0) <= std_logic_vector(to_unsigned(C_COMPONENT_ID, 32));

  reset <= reg_wen(C_REG_NUM_MDIO_RESET);

  -- MDIO
  reg_rdata(C_REG_NUM_MDIO_CONTROL)    <= pad_slv32(mdio_ready & response_received & write_not_read);
  reg_rdata(C_REG_NUM_MDIO_PHY_ADDR)   <= pad_slv32(phy_addr);
  reg_rdata(C_REG_NUM_MDIO_REG_ADDR)   <= pad_slv32(reg_addr);
  reg_rdata(C_REG_NUM_MDIO_WRITE_DATA) <= pad_slv32(write_data);
  -- Ethernet framer
  reg_rdata(C_REG_NUM_ETH_CONTROL)     <= pad_slv32(overflowed_out & eth_deframer_idle & eth_deframer_enable & eth_framer_idle & eth_framer_enable);
  reg_rdata(C_REG_NUM_SRC_MAC_LOWER)   <= source_mac(31 downto 0);
  reg_rdata(C_REG_NUM_SRC_MAC_UPPER)   <= pad_slv32(source_mac(47 downto 32));
  reg_rdata(C_REG_NUM_DST_MAC_LOWER)   <= destination_mac(31 downto 0);
  reg_rdata(C_REG_NUM_DST_MAC_UPPER)   <= pad_slv32(destination_mac(47 downto 32));
  reg_rdata(C_REG_NUM_MDIO_SEND_COUNT) <= pad_slv32(std_logic_vector(mdio_send_counter));
  reg_rdata(C_REG_NUM_MDIO_RX_COUNT)   <= pad_slv32(std_logic_vector(mdio_receive_counter));
  reg_rdata(C_REG_NUM_TX_BYTES)        <= num_tx_bytes;
  reg_rdata(C_REG_NUM_TX_PACKETS)      <= num_tx_packets;
  reg_rdata(C_REG_NUM_SRC_IP)          <= src_ip_address;
  reg_rdata(C_REG_NUM_RX_BYTES)        <= num_rx_bytes;
  reg_rdata(C_REG_NUM_RX_PACKETS)      <= num_rx_packets;
  reg_rdata(C_REG_NUM_RX_BAD_CARRIERS) <= pad_slv32(num_bad_carrier_events);
  reg_rdata(C_REG_NUM_MDIO_MAC_RX_COUNT) <= num_mac_rx_packets;
  reg_rdata(C_REG_NUM_RX_ETH_DROPS)      <= pad_slv32(eth_deframer_drop_count);
  reg_rdata(C_REG_NUM_RX_ETH_FCS_FAILS)  <= pad_slv32(dropped_packets_count);
  reg_rdata(C_REG_NUM_DEBUG)             <= pad_slv32(send_arp & "000" & send_arp_ready);
  
  -- MDIO
  write_not_read                 <= reg_wdata(C_REG_NUM_MDIO_CONTROL)(0);
  phy_addr                       <= reg_wdata(C_REG_NUM_MDIO_PHY_ADDR)(phy_addr'length-1 downto 0);
  reg_addr                       <= reg_wdata(C_REG_NUM_MDIO_REG_ADDR)(reg_addr'length-1 downto 0);
  write_data                     <= reg_wdata(C_REG_NUM_MDIO_WRITE_DATA)(write_data'length-1 downto 0);
  -- Ethernet framer
  eth_framer_enable              <= reg_wdata(C_REG_NUM_ETH_CONTROL)(0);
  eth_deframer_enable            <= reg_wdata(C_REG_NUM_ETH_CONTROL)(2);
  source_mac(31 downto 0)        <= reg_wdata(C_REG_NUM_SRC_MAC_LOWER);
  source_mac(47 downto 32)       <= reg_wdata(C_REG_NUM_SRC_MAC_UPPER)(15 downto 0);
  destination_mac(31 downto 0)   <= reg_wdata(C_REG_NUM_DST_MAC_LOWER);
  destination_mac(47 downto 32)  <= reg_wdata(C_REG_NUM_DST_MAC_UPPER)(15 downto 0);
  src_ip_address                 <= reg_wdata(C_REG_NUM_SRC_IP);

  p_arp_go : process(clk_user)
  begin
    if rising_edge(clk_user) then
      if reg_wen(C_REG_NUM_SEND_ARP) = '1' then
        send_arp <= '1';
      end if;
      if (send_arp = '1' and send_arp_ready = '1') or reset = '1' then
        send_arp <= '0';
      end if;
    end if;
  end process;

  p_mdio_go : process(clk_user)
  begin
    if rising_edge(clk_user) then
      if reg_wen(C_REG_NUM_MDIO_CONTROL) = '1' then
        send_msg <= '1';
      end if;
      if (send_msg = '1' and mdio_ready = '1') or reset = '1' then
        send_msg <= '0';
      end if;
    end if;
  end process;

  p_mdio_response_latch : process(clk_user)
  begin
    if rising_edge(clk_user) then
      if mdio_op_done = '1' then
        response_received <= '1';
      end if;

      if send_msg = '1' or reset = '1' then
        response_received <= '0';
      end if;
    end if;
  end process;

  p_mdio_receive : process(clk_user)
  begin
    if rising_edge(clk_user) then
      if mdio_op_done = '1' then
        reg_rdata(C_REG_NUM_MDIO_READ_DATA) <= pad_slv32(mdio_read_data_r);
      end if;
    mdio_op_done_r <= mdio_op_done;
    end if;
  end process;


  p_mdio_stats : process(clk_user)
  begin
    if rising_edge(clk_user) then
      if mdio_op_done = '1' and mdio_op_done_r = '0' then
        mdio_receive_counter <= mdio_receive_counter + 1;
      end if;
      if send_msg = '1' and mdio_ready = '1' then
        mdio_send_counter <= mdio_send_counter + 1;
      end if;

      if reset = '1' then
        mdio_send_counter <= (others => '0');
        mdio_receive_counter <= (others => '0');
      end if;
    end if;
  end process;


----------------------------------------
-- MAC
----------------------------------------
  i_rmii_mac : entity work.rmii_mac
  port map (
    clk_user                 => clk_user,
    clk50                    => clk50,
    reset                    => reset,
    --------------------------------------------------------
    eth_framer_enable_in     => eth_framer_enable,
    eth_framer_idle_out      => eth_framer_idle,
    source_mac_in            => source_mac,
    destination_mac_in       => destination_mac,
    send_garp_in              => send_arp,
    send_garp_ready_out       => send_arp_ready,
    ip_address_in            => src_ip_address,
    eth_deframer_enable_in   => eth_deframer_enable,
    eth_deframer_idle_out    => eth_deframer_idle,
    eth_deframer_drop_count_out => eth_deframer_drop_count,
    --------------------------------------------------------
    mdio_ready_out           => mdio_ready,
    mdio_send_msg_in         => send_msg,
    mdio_write_enable_in     => write_not_read,
    mdio_phy_address_in      => phy_addr,
    mdio_reg_address_in      => reg_addr,
    mdio_write_data_in       => write_data,
    mdio_read_data_out       => mdio_read_data_r,
    mdio_op_done             => mdio_op_done,
    --------------------------------------------------------
    m_tx_axis_tdata          => m_tx_axis_tdata,
    m_tx_axis_tvalid         => m_tx_axis_tvalid,
    m_tx_axis_tlast          => m_tx_axis_tlast,
    m_tx_axis_tready         => m_tx_axis_tready,
    --------------------------------------------------------
    s_rx_axis_tdata          => s_rx_axis_tdata,
    s_rx_axis_tvalid         => s_rx_axis_tvalid,
    s_rx_axis_tlast          => s_rx_axis_tlast,
    --------------------------------------------------------
    num_tx_bytes             => num_tx_bytes,
    num_tx_packets           => num_tx_packets,
    num_rx_bytes             => num_rx_bytes,
    num_rx_packets           => num_rx_packets,
    num_bad_carrier_events   => num_bad_carrier_events,
    dropped_packets_count    => dropped_packets_count,
    rx_overflowed            => overflowed_out,
    --------------------------------------------------------
    tx_en                    => tx_en,
    txd                      => txd,
    crs_dv                   => crs_dv,
    rxd                      => rxd,
    --------------------------------------------------------
    mdio_in                  => mdio_in,
    mdio_out                 => mdio_out,
    mdio_tristate_out        => mdio_tristate_out,
    mdc_out                  => mdc_out
  );


end architecture;
