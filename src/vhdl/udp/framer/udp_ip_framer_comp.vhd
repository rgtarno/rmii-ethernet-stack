library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.apb_data_types.all;

entity udp_ip_framer_comp is
  port (

    clk                    : in std_logic;
    --------------------------------------------------------
    apb_cmd_in             : in apb_cmd_t;
    apb_rsp_out            : out apb_rsp_t;
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector(7 downto 0);
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    s_axis_tready_out      : out std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector(7 downto 0);
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic;
    m_axis_tready_in       : in  std_logic
  );
end entity udp_ip_framer_comp;

architecture rtl of udp_ip_framer_comp is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_COMPONENT_ID                 : natural := 106;

  constant C_REG_NUM_CONTROL              : natural := 1;
  constant C_REG_NUM_SRC_PORT             : natural := 2;
  constant C_REG_NUM_DST_PORT             : natural := 3;
  constant C_REG_NUM_SRC_ADDR             : natural := 4;
  constant C_REG_NUM_DST_ADDR             : natural := 5;
  constant C_REG_NUM_IP_CHECKSUM_SEED     : natural := 6;

  constant C_UDP_IP_FRAMER_COMP_NUM_REGS          : natural := C_REG_NUM_IP_CHECKSUM_SEED +1;

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  signal reg_rdata              : slv32_array_t(C_UDP_IP_FRAMER_COMP_NUM_REGS-1 downto 0) := (others => (others => '0'));
  signal reg_wdata              : slv32_array_t(C_UDP_IP_FRAMER_COMP_NUM_REGS-1 downto 0) := (others => (others => '0'));
  signal reg_wen                : std_logic_vector(C_UDP_IP_FRAMER_COMP_NUM_REGS-1 downto 0) := (others => '0');


  signal enable                 : std_logic := '0';
  signal idle                   : std_logic := '0';
  signal reset                  : std_logic := '0';
  signal source_port            : std_logic_vector(15 downto 0);
  signal destination_port       : std_logic_vector(15 downto 0);
  signal src_address            : std_logic_vector(31 downto 0);
  signal destination_address    : std_logic_vector(31 downto 0);
  signal ip_checksum_init       : std_logic_vector(15 downto 0);

begin

----------------------------------------
-- Register interface
----------------------------------------

i_regsiter_block : entity work.component_register_block
  generic map (
    G_NUM_REGISTERS => C_UDP_IP_FRAMER_COMP_NUM_REGS
  )
  port map (
    clk              => clk,
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

  reg_rdata(C_REG_NUM_CONTROL)          <= pad_slv32(reset & idle & enable);
  reg_rdata(C_REG_NUM_SRC_PORT)         <= pad_slv32(source_port);
  reg_rdata(C_REG_NUM_DST_PORT)         <= pad_slv32(destination_port);
  reg_rdata(C_REG_NUM_SRC_ADDR)         <= pad_slv32(src_address);
  reg_rdata(C_REG_NUM_DST_ADDR)         <= pad_slv32(destination_address);
  reg_rdata(C_REG_NUM_IP_CHECKSUM_SEED) <= pad_slv32(ip_checksum_init);

  enable <= reg_wdata(C_REG_NUM_CONTROL)(0);
  reset  <= reg_wdata(C_REG_NUM_CONTROL)(2);

  source_port           <= reg_wdata(C_REG_NUM_SRC_PORT)(source_port'range);
  destination_port      <= reg_wdata(C_REG_NUM_DST_PORT)(destination_port'range);
  src_address           <= reg_wdata(C_REG_NUM_SRC_ADDR)(src_address'range);
  destination_address   <= reg_wdata(C_REG_NUM_DST_ADDR)(destination_address'range);
  ip_checksum_init      <= reg_wdata(C_REG_NUM_IP_CHECKSUM_SEED)(ip_checksum_init'range);

----------------------------------------
-- UDP-IP framer
----------------------------------------
i_udp_ip_framer : entity work.udp_ip_framer
  port map(

    clk                    => clk,
    reset                  => reset,
    --------------------------------------------------------
    enable_in              => enable,
    idle_out               => idle,
    source_port_in         => source_port,
    destination_port_in    => destination_port,
    src_address_in         => src_address,
    destination_address_in => destination_address,
    ip_checksum_init_in    => ip_checksum_init,
    --------------------------------------------------------
    s_axis_tdata_in        => s_axis_tdata_in,
    s_axis_tvalid_in       => s_axis_tvalid_in,
    s_axis_tlast_in        => s_axis_tlast_in,
    s_axis_tready_out      => s_axis_tready_out,
    --------------------------------------------------------
    m_axis_tdata_out       => m_axis_tdata_out,
    m_axis_tvalid_out      => m_axis_tvalid_out,
    m_axis_tlast_out       => m_axis_tlast_out,
    m_axis_tready_in       => m_axis_tready_in
  );

end architecture;
