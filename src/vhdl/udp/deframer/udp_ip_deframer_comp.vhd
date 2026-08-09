library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.apb_data_types.all;

entity udp_ip_deframer_comp is
  port (

    clk                    : in std_logic;
    --------------------------------------------------------
    apb_cmd_in             : in apb_cmd_t;
    apb_rsp_out            : out apb_rsp_t;
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector(7 downto 0);
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector(7 downto 0);
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic
  );
end entity udp_ip_deframer_comp;

architecture rtl of udp_ip_deframer_comp is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_COMPONENT_ID                 : natural := 106;

  constant C_REG_NUM_CONTROL              : natural := 1;
  constant C_REG_NUM_SRC_PORT             : natural := 2;
  constant C_REG_NUM_DST_PORT             : natural := 3;
  constant C_REG_NUM_DST_ADDR             : natural := 4;
  constant C_REG_NUM_BROADCAST_ADDR       : natural := 5;
  constant C_REG_NUM_VALID_PKT_COUNT      : natural := 6;
  constant C_REG_NUM_DROPPED_PKT_COUNT    : natural := 7;
  constant C_REG_NUM_DROP_MASK            : natural := 8;

  constant C_UDP_IP_DEFRAMER_COMP_NUM_REGS          : natural := C_REG_NUM_DROP_MASK +1;

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  signal reg_rdata              : slv32_array_t(C_UDP_IP_DEFRAMER_COMP_NUM_REGS-1 downto 0) := (others => (others => '0'));
  signal reg_wdata              : slv32_array_t(C_UDP_IP_DEFRAMER_COMP_NUM_REGS-1 downto 0) := (others => (others => '0'));

  signal enable                 : std_logic := '0';
  signal idle                   : std_logic := '0';
  signal reset                  : std_logic := '0';
  signal source_port            : std_logic_vector(15 downto 0);
  signal destination_port       : std_logic_vector(15 downto 0);
  signal destination_address    : std_logic_vector(31 downto 0);
  signal broadcast_address      : std_logic_vector(31 downto 0);

  signal valid_packets_count    : std_logic_vector(15 downto 0);
  signal dropped_packets_count  : std_logic_vector(15 downto 0);
  signal drop_mask              : std_logic_vector(7 downto 0);

begin

----------------------------------------
-- Register interface
----------------------------------------

i_regsiter_block : entity work.component_register_block
  generic map (
    G_NUM_REGISTERS => C_UDP_IP_DEFRAMER_COMP_NUM_REGS
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
    reg_wen_out      => open
  );

  reg_rdata(0) <= std_logic_vector(to_unsigned(C_COMPONENT_ID, 32));

  reg_rdata(C_REG_NUM_CONTROL)           <= pad_slv32(reset & idle & enable);
  reg_rdata(C_REG_NUM_SRC_PORT)          <= pad_slv32(source_port);
  reg_rdata(C_REG_NUM_DST_PORT)          <= pad_slv32(destination_port);
  reg_rdata(C_REG_NUM_DST_ADDR)          <= pad_slv32(destination_address);
  reg_rdata(C_REG_NUM_BROADCAST_ADDR)    <= pad_slv32(broadcast_address);
  reg_rdata(C_REG_NUM_VALID_PKT_COUNT)   <= pad_slv32(valid_packets_count);
  reg_rdata(C_REG_NUM_DROPPED_PKT_COUNT) <= pad_slv32(dropped_packets_count);
  reg_rdata(C_REG_NUM_drop_mask)         <= pad_slv32(drop_mask);

  enable              <= reg_wdata(C_REG_NUM_CONTROL)(0);
  reset               <= reg_wdata(C_REG_NUM_CONTROL)(2);
  source_port         <= reg_wdata(C_REG_NUM_SRC_PORT)(source_port'range);
  destination_port    <= reg_wdata(C_REG_NUM_DST_PORT)(destination_port'range);
  destination_address <= reg_wdata(C_REG_NUM_DST_ADDR)(destination_address'range);
  broadcast_address   <= reg_wdata(C_REG_NUM_BROADCAST_ADDR)(broadcast_address'range);


----------------------------------------
-- UDP-IP deframer
----------------------------------------
i_udp_ip_deframer : entity work.udp_ip_deframer
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
  valid_packets_count    => valid_packets_count,
  dropped_packets_count  => dropped_packets_count,
  drop_mask              => drop_mask,
  --------------------------------------------------------
  s_axis_tdata_in        => s_axis_tdata_in,
  s_axis_tvalid_in       => s_axis_tvalid_in,
  s_axis_tlast_in        => s_axis_tlast_in,
  --------------------------------------------------------
  m_axis_tdata_out       => m_axis_tdata_out,
  m_axis_tvalid_out      => m_axis_tvalid_out,
  m_axis_tlast_out       => m_axis_tlast_out
);

end architecture;