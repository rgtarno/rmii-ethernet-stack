library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.utils.all;
use work.apb_data_types.all;

-- Application to loopback all received UDP packets via RMII module

entity toplevel is
  port (
    clk            : in std_logic;
    ----------------------------
    led            : out std_logic_vector(15 downto 0);
    sw             : in std_logic_vector(0 downto 0);
    btnC           : in std_logic;
    RsRx           : in std_logic;
    RsTx           : out std_logic;
    RMII_REF_CLK   : in std_logic;
    RMII_RX0       : in std_logic;
    RMII_RX1       : in std_logic;
    RMII_CRS_DV    : in std_logic;
    RMII_TX0       : out std_logic;
    RMII_TX1       : out std_logic;
    RMII_TX_EN     : out std_logic;
    MDIO           : inout std_logic;
    MDC            : out std_logic
  );
end toplevel;

architecture rtl of toplevel is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------

  constant C_CLK_RATE_Hz            : natural := 100000000;
  constant C_UART_BAUD_RATE_Hz      : natural := 115200;

  constant C_COMP_NUM_PRBS_GEN      : natural := 0;
  constant C_COMP_NUM_UDP_FRAMER    : natural := 1;
  constant C_COMP_NUM_UDP_DEFRAMER  : natural := 2;
  constant C_COMP_NUM_RMII_ETHERNET : natural := 3;

  constant C_NUM_COMPS              : natural := C_COMP_NUM_RMII_ETHERNET+1;
  constant C_ADDR_BITS_PER_COMP     : natural := 8;

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal reset                          : std_logic := '0';

  signal sw_0_r                         : std_logic := '0';

  signal apb_cmd                        : apb_cmd_array_t(C_NUM_COMPS-1 downto 0) := (others => apb_cmd_0);
  signal apb_rsp                        : apb_rsp_array_t(C_NUM_COMPS-1 downto 0) := (others => apb_rsp_0);

  -- RMII
  signal rmii_ref_clk_50_bufg           : std_logic;
  signal rmii_ref_clk_50                : std_logic;
  signal rmii_mdc                       : std_logic;
  signal rmii_mdio_in                   : std_logic;
  signal rmii_mdio_out                  : std_logic;
  signal rmii_mdio_tristate             : std_logic;
  signal rmii_rx                        : std_logic_vector(1 downto 0);
  signal rmii_crs_dv_sig                : std_logic;
  signal rmii_tx                        : std_logic_vector(1 downto 0);
  signal rmii_tx_en_sig                 : std_logic;


  signal udp_tx_axis_tdata              : std_logic_vector(7 downto 0);
  signal udp_tx_axis_tvalid             : std_logic;
  signal udp_tx_axis_tlast              : std_logic;
  signal udp_tx_axis_tready             : std_logic;

  signal ethernet_tx_axis_tdata         : std_logic_vector(7 downto 0);
  signal ethernet_tx_axis_tvalid        : std_logic;
  signal ethernet_tx_axis_tlast         : std_logic;
  signal ethernet_tx_axis_tready        : std_logic;

  signal ethernet_rx_axis_tdata         : std_logic_vector(7 downto 0);
  signal ethernet_rx_axis_tvalid        : std_logic;
  signal ethernet_rx_axis_tlast         : std_logic;

  signal udp_rx_axis_tdata              : std_logic_vector(7 downto 0);
  signal udp_rx_axis_tvalid             : std_logic;
  signal udp_rx_axis_tlast              : std_logic;

  signal rx_fifo_din                    : std_logic_vector(8 downto 0);
  signal rx_fifo_dout                   : std_logic_vector(8 downto 0);
  signal rx_fifo_wen                    : std_logic;
  signal rx_fifo_empty                  : std_logic;
  signal rx_fifo_ren                    : std_logic;
begin

  reset <= '0';

----------------------------------------
-- UART - APB bridge
----------------------------------------

  i_uart_apb_bridge : entity work.uart_apb_bridge
  generic map (
    G_NUM_SLAVES          => C_NUM_COMPS,
    G_ADDR_BITS_PER_SLAVE => C_ADDR_BITS_PER_COMP,
    G_CLK_RATE_Hz         => C_CLK_RATE_Hz,
    G_BAUD_RATE_Hz        => C_UART_BAUD_RATE_Hz
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------
    uart_rx          => RsRx,
    uart_tx          => RsTx,
    --------------------------------------------------
    apb_cmd_out      => apb_cmd,
    apb_rsp_in       => apb_rsp
  );

------------------------------------------------------------
-- UDP-IP RX
------------------------------------------------------------

i_udp_ip_deframer : entity work.udp_ip_deframer_comp
  port map (
    clk                    => clk,
    --------------------------------------------------------
    apb_cmd_in             => apb_cmd(C_COMP_NUM_UDP_DEFRAMER),
    apb_rsp_out            => apb_rsp(C_COMP_NUM_UDP_DEFRAMER),
    --------------------------------------------------------
    s_axis_tdata_in        => ethernet_rx_axis_tdata,
    s_axis_tvalid_in       => ethernet_rx_axis_tvalid,
    s_axis_tlast_in        => ethernet_rx_axis_tlast,
    --------------------------------------------------------
    m_axis_tdata_out       => udp_rx_axis_tdata,
    m_axis_tvalid_out      => udp_rx_axis_tvalid,
    m_axis_tlast_out       => udp_rx_axis_tlast
  );


  rx_fifo_din   <= udp_rx_axis_tlast & udp_rx_axis_tdata;
  rx_fifo_wen   <= udp_rx_axis_tvalid;

  rx_fifo_fifo : entity work.fifo
  generic map (
    G_DATA_WIDTH              => rx_fifo_din'length,
    G_LOG2_DEPTH              => 10
  )
  port map (
    clk              => clk,
    sreset           => reset,
    --------------------------------------------------
    write_data       => rx_fifo_din,
    write_en         => rx_fifo_wen,
    full             => open,
    --------------------------------------------------
    read_data        => rx_fifo_dout,
    read_en          => rx_fifo_ren,
    empty            => rx_fifo_empty
  );

  rx_fifo_ren <= udp_tx_axis_tready;

  udp_tx_axis_tdata   <= rx_fifo_dout(7 downto 0);
  udp_tx_axis_tvalid  <= not rx_fifo_empty;
  udp_tx_axis_tlast   <= rx_fifo_dout(8);

------------------------------------------------------------
-- UDP-IP TX
------------------------------------------------------------

  i_udp_ip_framer : entity work.udp_ip_framer_comp
  port map (

    clk                    => clk,
    --------------------------------------------------------
    apb_cmd_in             => apb_cmd(C_COMP_NUM_UDP_FRAMER),
    apb_rsp_out            => apb_rsp(C_COMP_NUM_UDP_FRAMER),
    --------------------------------------------------------
    s_axis_tdata_in        => udp_tx_axis_tdata,
    s_axis_tvalid_in       => udp_tx_axis_tvalid,
    s_axis_tlast_in        => udp_tx_axis_tlast,
    s_axis_tready_out      => udp_tx_axis_tready,
    --------------------------------------------------------
    m_axis_tdata_out       => ethernet_tx_axis_tdata,
    m_axis_tvalid_out      => ethernet_tx_axis_tvalid,
    m_axis_tlast_out       => ethernet_tx_axis_tlast,
    m_axis_tready_in       => ethernet_tx_axis_tready
  );

------------------------------------------------------------
-- Ethernet
------------------------------------------------------------
i_rmii_mac_comp : entity work.rmii_mac_comp
  port map (
    clk_user                 => clk,
    clk50                    => rmii_ref_clk_50,
    --------------------------------------------------------
    apb_cmd_in               => apb_cmd(C_COMP_NUM_RMII_ETHERNET),
    apb_rsp_out              => apb_rsp(C_COMP_NUM_RMII_ETHERNET),
    --------------------------------------------------------
    m_tx_axis_tdata          => ethernet_tx_axis_tdata,
    m_tx_axis_tvalid         => ethernet_tx_axis_tvalid,
    m_tx_axis_tlast          => ethernet_tx_axis_tlast,
    m_tx_axis_tready         => ethernet_tx_axis_tready,
    --------------------------------------------------------
    s_rx_axis_tdata          => ethernet_rx_axis_tdata,
    s_rx_axis_tvalid         => ethernet_rx_axis_tvalid,
    s_rx_axis_tlast          => ethernet_rx_axis_tlast,
    --------------------------------------------------------
    tx_en                    => rmii_tx_en_sig,
    txd                      => rmii_tx,
    crs_dv                   => rmii_crs_dv_sig,
    rxd                      => rmii_rx,
    --------------------------------------------------------
    mdio_in                  => rmii_mdio_in,
    mdio_out                 => rmii_mdio_out,
    mdio_tristate_out        => rmii_mdio_tristate,
    mdc_out                  => rmii_mdc
  );

------------------------------------------------------------
-- RMII PINS
------------------------------------------------------------

MDIO_IOBUF : IOBUF
generic map (
   DRIVE => 12,
   IOSTANDARD => "DEFAULT",
   SLEW => "SLOW")
port map (
   O => rmii_mdio_in,       -- Buffer output
   IO => MDIO,              -- Buffer inout port (connect directly to top-level port)
   I => rmii_mdio_out,      -- Buffer input
   T => rmii_mdio_tristate  -- 3-state enable input, high=input, low=output
);

  MDC <= rmii_mdc;

  RMII_TX_EN <= rmii_tx_en_sig;
  RMII_TX0   <= rmii_tx(0);
  RMII_TX1   <= rmii_tx(1);

  rmii_crs_dv_sig <= RMII_CRS_DV;
  rmii_rx         <= RMII_RX1 & RMII_RX0;

  rmii_ref_clk_50 <= RMII_REF_CLK;



------------------------------------------------------------
-- Wire up switch to led via a register in the RMII clock domain to see if it is runing
------------------------------------------------------------

  process(RMII_REF_CLK)
  begin
    if rising_edge(RMII_REF_CLK) then
      sw_0_r <= sw(0);
      led(0) <= sw_0_r;
    end if;
  end process;


end architecture;
