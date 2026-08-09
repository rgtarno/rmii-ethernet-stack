library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;

use work.utils.all;

-- This module is an Ethernet Data link layer deframer. It expects the receive Ethernet packets at its s_axis_* interface, with the preamble and SFD removed.
-- Only Ethertype IPv4 (0x0800) is allowed through. Everything else is dropped.
-- Bit 0 of tuser is used to indicate an FCS fail, and will be output aligned with tlast.
-- Input packets do not have to be on contiguous clock cycles.
-- There are no tready signals as this component is expected to be placed immediatley after a MAC, which cannot backpressure the PHY

entity ethernet_deframer is
  port (

    clk                       : in std_logic;
    reset                     : in std_logic;
    --------------------------------------------------------
    enable_in                 : in std_logic;
    idle_out                  : out std_logic;
    filter_source_mac_in      : in std_logic;
    source_mac_in             : in std_logic_vector(47 downto 0);
    destination_mac_in        : in std_logic_vector(47 downto 0);
    dropped_packet_count_out  : out std_logic_vector(15 downto 0);
    --------------------------------------------------------
    s_axis_tdata_in           : in std_logic_vector(7 downto 0);
    s_axis_tvalid_in          : in std_logic;
    s_axis_tlast_in           : in std_logic;
    --------------------------------------------------------
    m_axis_tdata_out          : out std_logic_vector(7 downto 0);
    m_axis_tuser_out          : out std_logic_vector(0 downto 0);
    m_axis_tvalid_out         : out std_logic;
    m_axis_tlast_out          : out std_logic
  );
end entity ethernet_deframer;

architecture rtl of ethernet_deframer is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_ETHERTYPE_IP_UPPER       : std_logic_vector(7 downto 0) := x"08";
  constant C_ETHERTYPE_IP_LOWER       : std_logic_vector(7 downto 0) := x"00";
  constant C_MAC_BYTES_MINUS_1        : natural := 5;

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                      --  S_DEST_MAC_1, -- The upper byte of the DEST MAC is received whilst we are in S_IDLE
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
                       S_PAYLOAD_AND_FCS,
                       S_DISCARD
                       );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  signal fcs_reset             : std_logic;
  signal fcs_din_valid         : std_logic;
  signal fcs_en                : std_logic;
  signal fcs_matches           : std_logic;

  signal deframer_state        : fsm_state_t := S_IDLE;

  signal src_mac               : std_logic_vector(47 downto 0);
  signal src_mac_match         : std_logic := '0';

  signal dst_mac               : std_logic_vector(47 downto 0);
  signal dst_mac_match         : std_logic := '0';

  signal payload_finished      : std_logic := '0';

  signal dropped_packet_count_u : unsigned(15 downto 0) := (others => '0');

  signal deframed_tdata_r1     : std_logic_vector(m_axis_tdata_out'range);
  signal deframed_tvalid_r1    : std_logic := '0';
  signal deframed_tlast_r1     : std_logic := '0';

  signal deframed_tdata_r6     : std_logic_vector(m_axis_tdata_out'range);
  signal deframed_tvalid_r6    : std_logic := '0';
  signal deframed_tlast_r6     : std_logic := '0';
  signal deframed_tuser_r6     : std_logic_vector(m_axis_tuser_out'range);

  signal fifo_full            : std_logic := '0';
  signal fifo_empty           : std_logic := '0';
  signal fifo_reset           : std_logic := '0';
  signal fifo_q               : std_logic_vector(m_axis_tdata_out'range);

begin

  dropped_packet_count_out <= std_logic_vector(dropped_packet_count_u);
 
  ----------------------------------------------------
  -- Verify MAC addressed
  ----------------------------------------------------

  process(clk)
  begin
    if rising_edge(clk) then

      if s_axis_tvalid_in = '1' then

        case deframer_state is

          when S_SOURCE_MAC_1 | S_SOURCE_MAC_2 | S_SOURCE_MAC_3 | S_SOURCE_MAC_4 | S_SOURCE_MAC_5 | S_SOURCE_MAC_6 =>
            src_mac <= src_mac(39 downto 0) & s_axis_tdata_in;
          
          when S_IDLE | S_DEST_MAC_2 | S_DEST_MAC_3 | S_DEST_MAC_4 | S_DEST_MAC_5 | S_DEST_MAC_6 =>
            dst_mac <= dst_mac(39 downto 0) & s_axis_tdata_in;

          when others =>
            null;

        end case;
      end if;

      if reset = '1' then
        src_mac  <= (others => '0');
        dst_mac  <= (others => '0');
      end if;

    end if;
  end process;

  src_mac_match <= '1' when (src_mac = source_mac_in) or (and_reduce(src_mac) = '1') else '0'; -- Handles broadcast
  dst_mac_match <= '1' when (dst_mac = destination_mac_in) or (and_reduce(dst_mac) = '1') else '0'; -- Handles broadcast

  ----------------------------------------------------
  -- FCS calculation
  ----------------------------------------------------

  fcs_din_valid <= s_axis_tvalid_in;
  fcs_en        <= s_axis_tvalid_in;

  i_ethernet_fcs_gen : entity work.ethernet_fcs
  generic map (
    G_USER_INIT_VAL_PORT => false
  )
  port map (

    clk            => clk,
    reset          => fcs_reset or reset,
    --------------------------------------------------------
    data_in        => s_axis_tdata_in,
    valid_in       => fcs_din_valid,
    en_calc_in     => fcs_en,
    --------------------------------------------------------
    verify_out     => fcs_matches,
    fcs_byte_out   => open,
    crc_reg_out    => open
  );

  ----------------------------------------------------
  -- FSM
  ----------------------------------------------------

  idle_out <= '1' when deframer_state = S_IDLE else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      
      fcs_reset          <= '0';
      deframed_tvalid_r1 <= '0';
      deframed_tlast_r1  <= '0';
      deframed_tdata_r1  <= (others => '0');

      if s_axis_tvalid_in = '1' then

        case deframer_state is
          when S_IDLE =>
            payload_finished <= '0';
            if enable_in = '1' then
              deframer_state <= S_DEST_MAC_2;
            end if;

          when S_DEST_MAC_2 =>
            deframer_state  <= S_DEST_MAC_3;

          when S_DEST_MAC_3 =>
            deframer_state  <= S_DEST_MAC_4;

          when S_DEST_MAC_4 =>
            deframer_state  <= S_DEST_MAC_5;

          when S_DEST_MAC_5 =>
            deframer_state <= S_DEST_MAC_6;

          when S_DEST_MAC_6 =>
            deframer_state <= S_SOURCE_MAC_1;

          when S_SOURCE_MAC_1 =>
            if dst_mac_match = '0' then
              deframer_state  <= S_DISCARD;
            else
              deframer_state  <= S_SOURCE_MAC_2;
            end if;

          when S_SOURCE_MAC_2 =>
            deframer_state  <= S_SOURCE_MAC_3;

          when S_SOURCE_MAC_3 =>
            deframer_state  <= S_SOURCE_MAC_4;

          when S_SOURCE_MAC_4 =>
            deframer_state  <= S_SOURCE_MAC_5;

          when S_SOURCE_MAC_5 =>
            deframer_state  <= S_SOURCE_MAC_6;

          when S_SOURCE_MAC_6 =>
            deframer_state  <= S_ETHERTYPE_1;

          when S_ETHERTYPE_1 =>
            if (src_mac_match = '0' and filter_source_mac_in = '1') or (s_axis_tdata_in /= C_ETHERTYPE_IP_UPPER) then
              deframer_state  <= S_DISCARD;
            else
              deframer_state  <= S_ETHERTYPE_2;
            end if;
            
          when S_ETHERTYPE_2 =>
            if s_axis_tdata_in /= C_ETHERTYPE_IP_LOWER then
              deframer_state  <= S_DISCARD;
            else
              deframer_state  <= S_PAYLOAD_AND_FCS;
            end if;

          when S_PAYLOAD_AND_FCS =>
            deframed_tdata_r1   <= s_axis_tdata_in;
            deframed_tvalid_r1  <= s_axis_tvalid_in;
            deframed_tlast_r1   <= s_axis_tlast_in;
            if s_axis_tvalid_in = '1' and s_axis_tlast_in = '1' then
              deframer_state <= S_IDLE;
              fcs_reset      <= '1';
              payload_finished <= '1';
            end if;
          
          when S_DISCARD =>
            if s_axis_tvalid_in = '1' and s_axis_tlast_in = '1' then
              deframer_state <= S_IDLE;
              fcs_reset      <= '1';
              dropped_packet_count_u <= dropped_packet_count_u + 1;
            end if;
        end case;

      end if;

      if reset = '1' then
        deframer_state  <= S_IDLE;
        deframed_tvalid_r1 <= '0';
        deframed_tdata_r1  <= (others => '0');
        payload_finished <= '0';
        dropped_packet_count_u <= (others => '0');
      end if;

    end if;
  end process;


  ----------------------------------------------------
  -- Maintain a 4 byte buffer so the final payload byte can be marked
  -- as tlast and have the FCS pass/fail marked in the tuser field
  ----------------------------------------------------

i_data_fifo : entity work.circular_buffer
  generic map (
    G_DATA_WIDTH              => deframed_tdata_r1'length,
    G_LOG2_DEPTH              => 2
  )
  port map (
    clk              => clk,
    sreset           => fifo_reset,
    --------------------------------------------------
    write_data       => deframed_tdata_r1,
    write_en         => deframed_tvalid_r1,
    full             => fifo_full,
    used             => open,
    --------------------------------------------------
    read_data        => fifo_q,
    read_en          => fifo_full and deframed_tvalid_r1,
    empty            => fifo_empty
  );

  fifo_reset <= payload_finished;

  deframed_tdata_r6     <= fifo_q;
  deframed_tvalid_r6    <= fifo_full and not fifo_empty and deframed_tvalid_r1;
  deframed_tlast_r6     <= payload_finished;
  deframed_tuser_r6(0)  <= payload_finished and not fcs_matches;


  process(clk)
  begin
    if rising_edge(clk) then
      m_axis_tdata_out  <= deframed_tdata_r6;
      m_axis_tvalid_out <= deframed_tvalid_r6;
      m_axis_tlast_out  <= deframed_tlast_r6;
      m_axis_tuser_out  <= deframed_tuser_r6;

      if reset = '1' then
        m_axis_tvalid_out <= '0';
        m_axis_tlast_out  <= '0';
        m_axis_tdata_out  <= (others => '0');
        m_axis_tuser_out  <= (others => '0');
      end if;
    end if;
  end process;



end architecture;
