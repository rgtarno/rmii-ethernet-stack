library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity udp_ip_deframer is
  port (
    clk                    : in std_logic;
    reset                  : in std_logic;
    --------------------------------------------------------
    enable_in              : in std_logic;
    idle_out               : out std_logic;
    source_port_in         : in std_logic_vector(15 downto 0);
    destination_port_in    : in std_logic_vector(15 downto 0);
    destination_address_in : in std_logic_vector(31 downto 0);
    broadcast_address_in   : in std_logic_vector(31 downto 0);
    --------------------------------------------------------
    valid_packets_count    : out std_logic_vector(15 downto 0);
    dropped_packets_count  : out std_logic_vector(15 downto 0);
    drop_mask              : out std_logic_vector(7 downto 0);
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector(7 downto 0);
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector(7 downto 0);
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic
  );
end entity udp_ip_deframer;

architecture rtl of udp_ip_deframer is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_IP_VERSION       : std_logic_vector(3 downto 0) := x"4";  -- Verison
  constant C_IP_UDP_PROTOCOL  : std_logic_vector(7 downto 0) := x"11"; -- Verison


  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       -- IP
                       S_IP_DSCP,
                       S_IP_LEN_1,
                       S_IP_LEN_2,
                       S_IP_ID_1,
                       S_IP_ID_2,
                       S_IP_FLAGS_1,
                       S_IP_FLAGS_2,
                       S_IP_TTL,
                       S_IP_PROTOCOL,
                       S_IP_HDR_CHECKSUM_1,
                       S_IP_HDR_CHECKSUM_2,
                       S_IP_SRC_IP_1,
                       S_IP_SRC_IP_2,
                       S_IP_SRC_IP_3,
                       S_IP_SRC_IP_4,
                       S_IP_DST_IP_1,
                       S_IP_DST_IP_2,
                       S_IP_DST_IP_3,
                       S_IP_DST_IP_4,
                       S_IP_OPTIONS,
                       -- UDP
                       S_SRC_PORT_1,
                       S_SRC_PORT_2,
                       S_DST_PORT_1,
                       S_DST_PORT_2,
                       S_LENGTH_1,
                       S_LENGTH_2,
                       S_CHECKSUM_1,
                       S_CHECKSUM_2,
                       S_DATA,
                       S_DISCARD
                       );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal dst_ip_address_rx      : std_logic_vector(31 downto 0);
  signal dst_ip_adddress_match  : std_logic;

  signal dst_port_rx            : std_logic_vector(15 downto 0);
  signal dst_port_match         : std_logic;

  signal deframer_state         : fsm_state_t := S_IDLE;
  signal words_remaining_count  : unsigned(5 downto 0);

  signal deframed_tdata         : std_logic_vector(7 downto 0);
  signal deframed_tvalid        : std_logic;
  signal deframed_tlast         : std_logic;

  signal valid_packets_count_u    : unsigned(15 downto 0) := (others => '0');
  signal dropped_packets_count_u  : unsigned(15 downto 0) := (others => '0');

begin

  valid_packets_count   <= std_logic_vector(valid_packets_count_u);
  dropped_packets_count <= std_logic_vector(dropped_packets_count_u);

  ----------------------------------------------------
  -- Destination IP address
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if s_axis_tvalid_in = '1' then

        case deframer_state is

          when S_IP_DST_IP_1 | S_IP_DST_IP_2 | S_IP_DST_IP_3 | S_IP_DST_IP_4 =>
            dst_ip_address_rx <= dst_ip_address_rx(23 downto 0) & s_axis_tdata_in;

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  dst_ip_adddress_match <= '1' when (dst_ip_address_rx = destination_address_in) or (dst_ip_address_rx = broadcast_address_in) else '0';

  ----------------------------------------------------
  -- Destination port
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if s_axis_tvalid_in = '1' then

        if deframer_state = S_DST_PORT_1 then
          dst_port_rx(15 downto 8) <= s_axis_tdata_in;
        elsif deframer_state = S_DST_PORT_2 then
          dst_port_rx(7 downto 0) <= s_axis_tdata_in;
        end if;

      end if;
    end if;
  end process;

  dst_port_match <= '1' when (dst_port_rx = destination_port_in) else '0';

  ----------------------------------------------------
  -- FSM
  ----------------------------------------------------

  idle_out <= '1' when deframer_state = S_IDLE else '0';

  process(clk)
    variable ip_header_bytes : unsigned(5 downto 0);
  begin
    if rising_edge(clk) then

      deframed_tdata  <= (others => '0');
      deframed_tvalid <= '0';
      deframed_tlast  <= '0';

      if s_axis_tvalid_in = '1' then

        case deframer_state is 
          when S_IDLE =>

            if enable_in = '1' then
              if s_axis_tdata_in(7 downto 4) = C_IP_VERSION then
                deframer_state <= S_IP_DSCP;
                -- Number of IP header bytes remaining after the mimimum of 20
                ip_header_bytes := unsigned(s_axis_tdata_in(3 downto 0)) & "00";
                words_remaining_count <= ip_header_bytes - to_unsigned(20, words_remaining_count'length);
              else
                deframer_state <= S_DISCARD;
                drop_mask(0) <= '1';
              end if;
            end if;

            when S_IP_DSCP =>
            deframer_state   <= S_IP_LEN_1;

          when S_IP_LEN_1 =>
            deframer_state <= S_IP_LEN_2;

          when S_IP_LEN_2 =>
            deframer_state <= S_IP_ID_1;

          when S_IP_ID_1 =>
            deframer_state <= S_IP_ID_2;

          when S_IP_ID_2 =>
            deframer_state <= S_IP_FLAGS_1;

          when S_IP_FLAGS_1 =>
            deframer_state <= S_IP_FLAGS_2;

          when S_IP_FLAGS_2 =>
            deframer_state <= S_IP_TTL;

          when S_IP_TTL =>
            deframer_state <= S_IP_PROTOCOL;

          when S_IP_PROTOCOL =>
            if s_axis_tdata_in = C_IP_UDP_PROTOCOL then
              deframer_state <= S_IP_HDR_CHECKSUM_1;
            else
              deframer_state <= S_DISCARD;
              drop_mask(1) <= '1';
            end if;

          when S_IP_HDR_CHECKSUM_1 =>
            deframer_state   <= S_IP_HDR_CHECKSUM_2;

          when S_IP_HDR_CHECKSUM_2 =>
            deframer_state   <= S_IP_SRC_IP_1;

          when S_IP_SRC_IP_1 =>
            deframer_state <= S_IP_SRC_IP_2;

          when S_IP_SRC_IP_2 =>
            deframer_state <= S_IP_SRC_IP_3;

          when S_IP_SRC_IP_3 =>
            deframer_state <= S_IP_SRC_IP_4;

          when S_IP_SRC_IP_4 =>
            deframer_state <= S_IP_DST_IP_1;

          when S_IP_DST_IP_1 =>
            deframer_state <= S_IP_DST_IP_2;

          when S_IP_DST_IP_2 =>
            deframer_state <= S_IP_DST_IP_3;

          when S_IP_DST_IP_3 =>
            deframer_state <= S_IP_DST_IP_4;

          when S_IP_DST_IP_4 =>
            deframer_state <= S_IP_OPTIONS;
            if words_remaining_count = to_unsigned(0, words_remaining_count'length) then
              deframer_state <= S_SRC_PORT_1;
            end if;

          when S_IP_OPTIONS => 
            words_remaining_count <= words_remaining_count - 1;
            if words_remaining_count = to_unsigned(1, words_remaining_count'length) then
              deframer_state <= S_SRC_PORT_1;
            end if;

          when S_SRC_PORT_1 =>
            if dst_ip_adddress_match = '1' then
              deframer_state  <= S_SRC_PORT_2;
            else
              deframer_state  <= S_DISCARD;
              drop_mask(2) <= '1';
            end if;
            
          when S_SRC_PORT_2 =>
            deframer_state  <= S_DST_PORT_1;

          when S_DST_PORT_1 =>
            deframer_state  <= S_DST_PORT_2;

          when S_DST_PORT_2 =>
            deframer_state  <= S_LENGTH_1;

          when S_LENGTH_1 =>
            if dst_port_match = '1' then
              deframer_state  <= S_LENGTH_2;
            else
              deframer_state  <= S_DISCARD;
              drop_mask(3) <= '1';
            end if;

          when S_LENGTH_2 =>
            deframer_state  <= S_CHECKSUM_1;

          when S_CHECKSUM_1 =>
            deframer_state  <= S_CHECKSUM_2;

          when S_CHECKSUM_2 =>
            if s_axis_tlast_in = '1' then
              deframer_state  <= S_IDLE;
            else
              deframer_state  <= S_DATA;
            end if;

          when S_DATA =>
            deframed_tdata  <= s_axis_tdata_in;
            deframed_tvalid <= s_axis_tvalid_in;
            deframed_tlast  <= s_axis_tlast_in;

            if s_axis_tlast_in = '1' then
              deframer_state  <= S_IDLE;
              valid_packets_count_u <= valid_packets_count_u + 1;
            end if;

          when S_DISCARD =>
              if s_axis_tlast_in = '1' then
                deframer_state  <= S_IDLE;
                dropped_packets_count_u <= dropped_packets_count_u + 1;
              end if;
          
          when others =>
            report "ERROR";

        end case;
      end if;
      
      if reset = '1' then
        deframer_state  <= S_IDLE;
        deframed_tdata  <= (others => '0');
        deframed_tvalid <= '0';
        deframed_tlast  <= '0';
        valid_packets_count_u <= (others => '0');
        dropped_packets_count_u <= (others => '0');
        drop_mask <= (others => '0');
      end if;

    end if;
  end process;


  m_axis_tdata_out  <= deframed_tdata;
  m_axis_tvalid_out <= deframed_tvalid;
  m_axis_tlast_out  <= deframed_tlast;

  
end architecture;