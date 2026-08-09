library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

-- This module is an Ethernet Data link layer framer. It accepts a packet payload on its s_axis_* interface
-- and inserts the Ethernet data link layer headers (dest and source MAC addresses, Ethertype) and calculates and appends the FCS.

entity ethernet_framer is
  port (

    clk                    : in std_logic;
    reset                  : in std_logic;
    --------------------------------------------------------
    enable_in              : in std_logic;
    idle_out               : out std_logic;
    source_mac_in          : in std_logic_vector(47 downto 0);
    destination_mac_in     : in std_logic_vector(47 downto 0);
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector(7 downto 0);
    s_axis_tuser_in        : in std_logic_vector(0 downto 0) := (others => '0'); -- Used to select the Ethertype to apply. '1' = ARP, '0' = IPV4
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    s_axis_tready_out      : out std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector(7 downto 0);
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic;
    m_axis_tready_in       : in  std_logic
  );
end entity ethernet_framer;

architecture rtl of ethernet_framer is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_ETHERTYPE_UPPER      : std_logic_vector(7 downto 0) := x"08";
  constant C_ETHERTYPE_LOWER_IPV4 : std_logic_vector(7 downto 0) := x"00";
  constant C_ETHERTYPE_LOWER_ARP  : std_logic_vector(7 downto 0) := x"06";

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       S_DEST_MAC_1,
                       S_DEST_MAC_2,
                       S_DEST_MAC_3,
                       S_DEST_MAC_4,
                       S_DEST_MAC_5,
                       S_DEST_MAC_6,
                       S_SOURCE_MAC_1,
                       S_SOURCE_MAC_2,
                       S_SOURCE_MAC_3,
                       S_SOURCE_MAC_4,
                       S_SOURCE_MAC_5,
                       S_SOURCE_MAC_6,
                       S_ETHERTYPE_1,
                       S_ETHERTYPE_2,
                       S_PAYLOAD,
                       S_FCS_1,
                       S_FCS_2,
                       S_FCS_3,
                       S_FCS_4
                       );

  type fcs_state_t is (S_DATA,
                       S_FCS_1,
                       S_FCS_2,
                       S_FCS_3,
                       S_FCS_4
  );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal framer_state       : fsm_state_t := S_IDLE;
  signal fcs_state          : fcs_state_t := S_DATA;

  signal fcs_reset          : std_logic;
  signal fcs_din_valid      : std_logic;
  signal fcs_en             : std_logic;
  signal fcs_byte_out       : std_logic_vector(7 downto 0);

  signal ethertype_select   : std_logic;
  signal dest_mac_r         : std_logic_vector(47 downto 0);

  signal framed_tdata       : std_logic_vector(m_axis_tdata_out'range);
  signal framed_tvalid      : std_logic := '0';
  signal framed_tlast       : std_logic;

  signal output_tdata       : std_logic_vector(m_axis_tdata_out'range);
  signal output_tvalid      : std_logic := '0';
  signal output_tlast       : std_logic;
  signal output_ready       : std_logic;

begin

  ----------------------------------------------------
  -- FSM
  ----------------------------------------------------

  idle_out <= '1' when framer_state = S_IDLE else '0';

  s_axis_tready_out <= output_ready when framer_state = S_PAYLOAD else '0';

  process(clk)
  begin
    if rising_edge(clk) then

      if output_ready = '1' then
        framed_tvalid <= '0';
        framed_tlast  <= '0';

        case framer_state is
          when S_IDLE =>
            if s_axis_tvalid_in = '1' and enable_in = '1' then
              framer_state <= S_DEST_MAC_1;
              ethertype_select <= s_axis_tuser_in(0);
              dest_mac_r       <= destination_mac_in;
            end if;

          when S_DEST_MAC_1 =>
            framer_state  <= S_DEST_MAC_2;
            framed_tdata  <= dest_mac_r(47 downto 40);
            framed_tvalid <= '1';

          when S_DEST_MAC_2 =>
            framer_state  <= S_DEST_MAC_3;
            framed_tdata  <= dest_mac_r(39 downto 32);
            framed_tvalid <= '1';

          when S_DEST_MAC_3 =>
            framer_state  <= S_DEST_MAC_4;
            framed_tdata  <= dest_mac_r(31 downto 24);
            framed_tvalid <= '1';

          when S_DEST_MAC_4 =>
            framer_state  <= S_DEST_MAC_5;
            framed_tdata  <= dest_mac_r(23 downto 16);
            framed_tvalid <= '1';

          when S_DEST_MAC_5 =>
            framer_state <= S_DEST_MAC_6;
            framed_tdata  <= dest_mac_r(15 downto 8);
            framed_tvalid <= '1';

          when S_DEST_MAC_6 =>
            framer_state <= S_SOURCE_MAC_1;
            framed_tdata  <= dest_mac_r(7 downto 0);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_1 =>
            framer_state  <= S_SOURCE_MAC_2;
            framed_tdata  <= source_mac_in(47 downto 40);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_2 =>
            framer_state  <= S_SOURCE_MAC_3;
            framed_tdata  <= source_mac_in(39 downto 32);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_3 =>
            framer_state  <= S_SOURCE_MAC_4;
            framed_tdata  <= source_mac_in(31 downto 24);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_4 =>
            framer_state  <= S_SOURCE_MAC_5;
            framed_tdata  <= source_mac_in(23 downto 16);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_5 =>
            framer_state  <= S_SOURCE_MAC_6;
            framed_tdata  <= source_mac_in(15 downto 8);
            framed_tvalid <= '1';

          when S_SOURCE_MAC_6 =>
            framer_state  <= S_ETHERTYPE_1;
            framed_tdata  <= source_mac_in(7 downto 0);
            framed_tvalid <= '1';

          when S_ETHERTYPE_1 =>
            framer_state  <= S_ETHERTYPE_2;
            framed_tdata  <= C_ETHERTYPE_UPPER;
            framed_tvalid <= '1';
            

          when S_ETHERTYPE_2 =>
            framer_state   <= S_PAYLOAD;
            if ethertype_select = '1' then
              framed_tdata   <= C_ETHERTYPE_LOWER_ARP;
            else
              framed_tdata   <= C_ETHERTYPE_LOWER_IPV4;
            end if;
            framed_tvalid  <= '1';

          when S_PAYLOAD =>
            framed_tdata   <= s_axis_tdata_in;
            framed_tvalid  <= s_axis_tvalid_in;
            if s_axis_tvalid_in = '1' and s_axis_tlast_in = '1' then
              framer_state <= S_FCS_1;
              framed_tlast  <= '1';
            end if;

          when S_FCS_1 =>
            framer_state  <= S_FCS_2;

          when S_FCS_2 =>
            framer_state  <= S_FCS_3;

          when S_FCS_3 =>
            framer_state  <= S_FCS_4;

          when S_FCS_4 =>
            framer_state  <= S_IDLE;
        end case;

      end if;

      if reset = '1' then
        framer_state  <= S_IDLE;
        framed_tvalid <= '0';
        framed_tlast  <= '0';
        framed_tdata  <= (others => '0');
        ethertype_select <= '0';
      end if;

    end if;
  end process;



  ----------------------------------------------------
  -- FCS calculation
  ----------------------------------------------------

  i_ethernet_fcs_gen : entity work.ethernet_fcs
  generic map (
    G_USER_INIT_VAL_PORT => false
  )
  port map (

    clk            => clk,
    reset          => fcs_reset,
    --------------------------------------------------------
    data_in        => framed_tdata,
    valid_in       => fcs_din_valid and output_ready,
    en_calc_in     => fcs_en and output_ready,
    --------------------------------------------------------
    fcs_byte_out   => fcs_byte_out,
    crc_reg_out    => open
  );

  ----------------------------------------------------
  -- Add FCS
  ----------------------------------------------------
  output_ready <= m_axis_tready_in or not output_tvalid;

  fcs_en        <= output_ready and framed_tvalid when fcs_state = S_DATA else '0';
  fcs_din_valid <= output_ready and framed_tvalid when fcs_state = S_DATA else 
                  '1';
  process(clk)
  begin
    if rising_edge(clk) then
  
      if output_ready = '1' then
        fcs_reset     <= '0';

        case fcs_state is
          when S_DATA =>
            output_tdata  <= framed_tdata;
            output_tvalid <= framed_tvalid;
            output_tlast  <= '0';

            if framed_tlast = '1' then
              fcs_state <= S_FCS_1;
            end if;

          when S_FCS_1 =>
            fcs_state     <= S_FCS_2;
            output_tdata  <= fcs_byte_out;
            output_tvalid <= '1';
            output_tlast  <= '0';

          when S_FCS_2 =>
            fcs_state     <= S_FCS_3;
            output_tdata  <= fcs_byte_out;
            output_tvalid <= '1';
            output_tlast  <= '0';

          when S_FCS_3 =>
            fcs_state     <= S_FCS_4;
            output_tdata  <= fcs_byte_out;
            output_tvalid <= '1';
            output_tlast  <= '0';

          when S_FCS_4 =>
            fcs_state     <= S_DATA;
            output_tdata  <= fcs_byte_out;
            output_tvalid <= '1';
            output_tlast  <= '1';
            fcs_reset     <= '1';

        end case;
      end if;

      if reset = '1' then
        output_tdata  <= (others => '0');
        output_tvalid <= '0';
        output_tlast  <= '0';
        fcs_state     <= S_DATA;
        fcs_reset     <= '1';
      end if;
    end if;
  end process;

  m_axis_tdata_out  <= output_tdata;
  m_axis_tvalid_out <= output_tvalid;
  m_axis_tlast_out  <= output_tlast;

end architecture;