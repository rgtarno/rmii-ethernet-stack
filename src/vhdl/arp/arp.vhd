library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;

-- Send a gratuitous ARP (GARP) or respond to ARP requests for our IP.
-- GARP: Sent opcode 1 (request), TPA == SPA (Our IP), SHA == Our MAC, THA == 0, Dest MAC == FF:FF:FF:FF:FF:FF
-- ARP Reply: Sent opcode 2 (reply), TPA == Requester IP, SPA == Our IP, SHA == Our MAC, THA == Requester MAC, Dest MAC == Requester MAC

entity arp is
  port (

    clk                    : in std_logic;
    reset                  : in std_logic;
    --------------------------------------------------------
    send_garp_in           : in std_logic;
    send_garp_ready_out    : out std_logic;
    mac_address_in         : in std_logic_vector(47 downto 0);
    ip_address_in          : in std_logic_vector(31 downto 0);
    destination_mac_in     : in std_logic_vector(47 downto 0) := (others => '1');
    --------------------------------------------------------
    rx_axis_tdata_in       : in std_logic_vector(7 downto 0) := (others => '0');
    rx_axis_tvalid_in      : in std_logic := '0';
    rx_axis_tlast_in       : in std_logic := '0';
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector(7 downto 0);
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    s_axis_tready_out      : out std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector(7 downto 0);
    m_axis_tuser_out       : out std_logic_vector(0 downto 0);
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic;
    m_axis_tready_in       : in  std_logic;
    --------------------------------------------------------
    eth_dest_mac_out       : out std_logic_vector(47 downto 0)
  );
end entity arp;

architecture rtl of arp is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       S_HW_TYPE_1,
                       S_HW_TYPE_2,
                       S_PROTOCOL_TYPE_1,
                       S_PROTOCOL_TYPE_2,
                       HW_LENGTH,
                       PROTOCOL_LENGTH,
                       OPERATION_1,
                       OPERATION_2,
                       SHA_1,
                       SHA_2,
                       SHA_3,
                       SHA_4,
                       SHA_5,
                       SHA_6,
                       SPA_1,
                       SPA_2,
                       SPA_3,
                       SPA_4,
                       THA,
                       TPA_1,
                       TPA_2,
                       TPA_3,
                       TPA_4,
                       S_PAD
                       );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal ready_to_send        : std_logic := '0';
  signal garp_pending         : std_logic := '0';
  signal reply_pending        : std_logic := '0';
  signal reply_started        : std_logic := '0';

  signal active_arp_is_reply  : std_logic := '0';
  signal sending_target_mac   : std_logic_vector(47 downto 0) := (others => '0');
  signal sending_target_ip    : std_logic_vector(31 downto 0) := (others => '0');

  signal in_data_packet       : std_logic := '0';

  signal fsm_state            : fsm_state_t := S_IDLE;

  signal pad_counter          : unsigned(4 downto 0) := (others => '0');

  signal framed_tdata         : std_logic_vector(7 downto 0) := (others => '0');
  signal framed_tuser         : std_logic_vector(m_axis_tuser_out'range) := (others => '0');
  signal framed_tvalid        : std_logic := '0';
  signal framed_tlast         : std_logic := '0';

  signal output_tdata         : std_logic_vector(7 downto 0) := (others => '0');
  signal output_tuser         : std_logic_vector(m_axis_tuser_out'range) := (others => '0');
  signal output_tvalid        : std_logic := '0';
  signal output_tlast         : std_logic := '0';
  signal output_tready        : std_logic := '0';

  -- RX parsing signals
  signal rx_byte_cnt          : unsigned(6 downto 0) := (others => '0');
  signal rx_dest_mac_match    : std_logic := '0';
  signal rx_ethertype_match   : std_logic := '0';
  signal rx_hw_proto_match    : std_logic := '0';
  signal rx_opcode_is_req     : std_logic := '0';

  signal rx_sha_shift         : std_logic_vector(47 downto 0) := (others => '0');
  signal rx_spa_shift         : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_tpa_shift         : std_logic_vector(31 downto 0) := (others => '0');

  signal req_sha              : std_logic_vector(47 downto 0) := (others => '0');
  signal req_spa              : std_logic_vector(31 downto 0) := (others => '0');

begin

  ----------------------------------------------------
  -- Register start signal and indicate ready to send
  ----------------------------------------------------

  ready_to_send      <= not garp_pending;
  send_garp_ready_out <= ready_to_send;

  process(clk)
  begin
    if rising_edge(clk) then
      if send_garp_in = '1' and garp_pending = '0' then
        garp_pending <= '1';
      end if;

      if reset = '1' or (fsm_state = S_IDLE and garp_pending = '1' and reply_pending = '0' and ((s_axis_tlast_in = '1' and s_axis_tvalid_in = '1') or (in_data_packet = '0'))) then
        garp_pending <= '0';
      end if;

    end if;
  end process;

  ----------------------------------------------------
  -- RX ARP Request Parser
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rx_axis_tvalid_in = '1' then
        if rx_axis_tlast_in = '1' then
          rx_byte_cnt <= (others => '0');
        else
          rx_byte_cnt <= rx_byte_cnt + 1;
        end if;

        -- Dest MAC check (bytes 0..5)
        case to_integer(rx_byte_cnt) is
          when 0 =>
            if rx_axis_tdata_in = mac_address_in(47 downto 40) or rx_axis_tdata_in = x"FF" then
              rx_dest_mac_match <= '1';
            else
              rx_dest_mac_match <= '0';
            end if;
          when 1 =>
            if rx_axis_tdata_in /= mac_address_in(39 downto 32) and rx_axis_tdata_in /= x"FF" then
              rx_dest_mac_match <= '0';
            end if;
          when 2 =>
            if rx_axis_tdata_in /= mac_address_in(31 downto 24) and rx_axis_tdata_in /= x"FF" then
              rx_dest_mac_match <= '0';
            end if;
          when 3 =>
            if rx_axis_tdata_in /= mac_address_in(23 downto 16) and rx_axis_tdata_in /= x"FF" then
              rx_dest_mac_match <= '0';
            end if;
          when 4 =>
            if rx_axis_tdata_in /= mac_address_in(15 downto 8) and rx_axis_tdata_in /= x"FF" then
              rx_dest_mac_match <= '0';
            end if;
          when 5 =>
            if rx_axis_tdata_in /= mac_address_in(7 downto 0) and rx_axis_tdata_in /= x"FF" then
              rx_dest_mac_match <= '0';
            end if;

          -- Ethertype (bytes 12..13)
          when 12 =>
            if rx_axis_tdata_in = x"08" then
              rx_ethertype_match <= '1';
            else
              rx_ethertype_match <= '0';
            end if;
          when 13 =>
            if rx_axis_tdata_in /= x"06" then
              rx_ethertype_match <= '0';
            end if;

          -- HW & Protocol fields (bytes 14..19)
          when 14 =>
            if rx_axis_tdata_in = x"00" then
              rx_hw_proto_match <= '1';
            else
              rx_hw_proto_match <= '0';
            end if;
          when 15 =>
            if rx_axis_tdata_in /= x"01" then
              rx_hw_proto_match <= '0';
            end if;
          when 16 =>
            if rx_axis_tdata_in /= x"08" then
              rx_hw_proto_match <= '0';
            end if;
          when 17 =>
            if rx_axis_tdata_in /= x"00" then
              rx_hw_proto_match <= '0';
            end if;
          when 18 =>
            if rx_axis_tdata_in /= x"06" then
              rx_hw_proto_match <= '0';
            end if;
          when 19 =>
            if rx_axis_tdata_in /= x"04" then
              rx_hw_proto_match <= '0';
            end if;

          -- Opcode (bytes 20..21)
          when 20 =>
            if rx_axis_tdata_in = x"00" then
              rx_opcode_is_req <= '1';
            else
              rx_opcode_is_req <= '0';
            end if;
          when 21 =>
            if rx_axis_tdata_in /= x"01" then
              rx_opcode_is_req <= '0';
            end if;

          when others =>
            null;
        end case;

        -- Shift registers for SHA, SPA, TPA
        if rx_byte_cnt >= to_unsigned(22, rx_byte_cnt'length) and rx_byte_cnt <= to_unsigned(27, rx_byte_cnt'length) then
          rx_sha_shift <= rx_sha_shift(39 downto 0) & rx_axis_tdata_in;
        end if;

        if rx_byte_cnt >= to_unsigned(28, rx_byte_cnt'length) and rx_byte_cnt <= to_unsigned(31, rx_byte_cnt'length) then
          rx_spa_shift <= rx_spa_shift(23 downto 0) & rx_axis_tdata_in;
        end if;

        if rx_byte_cnt >= to_unsigned(38, rx_byte_cnt'length) and rx_byte_cnt <= to_unsigned(41, rx_byte_cnt'length) then
          rx_tpa_shift <= rx_tpa_shift(23 downto 0) & rx_axis_tdata_in;
        end if;

        -- At byte 41, evaluate match for ARP Request for our IP
        if rx_byte_cnt = to_unsigned(41, rx_byte_cnt'length) then
          if rx_dest_mac_match = '1' and rx_ethertype_match = '1' and rx_hw_proto_match = '1' and rx_opcode_is_req = '1' and (rx_tpa_shift(23 downto 0) & rx_axis_tdata_in) = ip_address_in then
            req_sha <= rx_sha_shift;
            req_spa <= rx_spa_shift;
            reply_pending <= '1';
          end if;
        end if;

      end if;

      if reply_started = '1' then
        reply_pending <= '0';
      end if;

      if reset = '1' then
        rx_byte_cnt <= (others => '0');
        rx_dest_mac_match <= '0';
        rx_ethertype_match <= '0';
        rx_hw_proto_match <= '0';
        rx_opcode_is_req <= '0';
        rx_sha_shift <= (others => '0');
        rx_spa_shift <= (others => '0');
        rx_tpa_shift <= (others => '0');
        req_sha <= (others => '0');
        req_spa <= (others => '0');
        reply_pending <= '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------
  -- Track TX data packet state
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if s_axis_tvalid_in = '1' and output_tready = '1' and in_data_packet = '0' then
        in_data_packet <= '1';
      end if;

      if s_axis_tvalid_in = '1' and output_tready = '1' and s_axis_tlast_in = '1' then
        in_data_packet <= '0';
      end if;

      if reset = '1' then
        in_data_packet <= '0';
      end if;

    end if;
  end process;

  ----------------------------------------------------
  -- FSM
  ----------------------------------------------------

  s_axis_tready_out <= output_tready when fsm_state = S_IDLE else '0';

  process(clk)
  begin
    if rising_edge(clk) then

      reply_started <= '0';

      if output_tready = '1' then 

        framed_tdata  <= (others => '0');
        framed_tuser  <= "1";
        framed_tvalid <= '0';
        framed_tlast  <= '0';

        pad_counter <= pad_counter - 1;
      
        case fsm_state is

          when S_IDLE => 
            framed_tdata  <= s_axis_tdata_in;
            framed_tvalid <= s_axis_tvalid_in;
            framed_tlast  <= s_axis_tlast_in;
            framed_tuser  <= "0";

            if (s_axis_tvalid_in = '0' and in_data_packet = '0') or (s_axis_tvalid_in = '1' and s_axis_tlast_in = '1') then
              if reply_pending = '1' then
                active_arp_is_reply <= '1';
                sending_target_mac  <= req_sha;
                sending_target_ip   <= req_spa;
                reply_started       <= '1';
                fsm_state           <= S_HW_TYPE_1;
              elsif garp_pending = '1' then
                active_arp_is_reply <= '0';
                sending_target_mac  <= (others => '0');
                sending_target_ip   <= ip_address_in;
                fsm_state           <= S_HW_TYPE_1;
              end if;
            end if;

          when S_HW_TYPE_1 =>
            framed_tdata  <= (others => '0');
            framed_tvalid <= '1';
            fsm_state <= S_HW_TYPE_2;

          when S_HW_TYPE_2 =>
            framed_tdata  <= x"01";
            framed_tvalid <= '1';
            fsm_state <= S_PROTOCOL_TYPE_1;

          when S_PROTOCOL_TYPE_1 =>
            framed_tdata  <= x"08";
            framed_tvalid <= '1';
            fsm_state <= S_PROTOCOL_TYPE_2;

          when S_PROTOCOL_TYPE_2 =>
            framed_tdata  <= x"00";
            framed_tvalid <= '1';
            fsm_state <= HW_LENGTH;

          when HW_LENGTH =>
            framed_tdata  <= x"06";
            framed_tvalid <= '1';
            fsm_state <= PROTOCOL_LENGTH;

          when PROTOCOL_LENGTH =>
            framed_tdata  <= x"04";
            framed_tvalid <= '1';
            fsm_state <= OPERATION_1;

          when OPERATION_1 =>
            framed_tdata  <= x"00";
            framed_tvalid <= '1';
            fsm_state <= OPERATION_2;

          when OPERATION_2 =>
            if active_arp_is_reply = '1' then
              framed_tdata <= x"02"; -- Reply
            else
              framed_tdata <= x"01"; -- Request (GARP)
            end if;
            framed_tvalid <= '1';
            fsm_state <= SHA_1;

          when SHA_1 =>
            framed_tdata  <= mac_address_in(47 downto 40);
            framed_tvalid <= '1';
            fsm_state <= SHA_2;

          when SHA_2 =>
            framed_tdata  <= mac_address_in(39 downto 32);
            framed_tvalid <= '1';
            fsm_state <= SHA_3;

          when SHA_3 =>
            framed_tdata  <= mac_address_in(31 downto 24);
            framed_tvalid <= '1';
            fsm_state <= SHA_4;

          when SHA_4 =>
            framed_tdata  <= mac_address_in(23 downto 16);
            framed_tvalid <= '1';
            fsm_state <= SHA_5;

          when SHA_5 =>
            framed_tdata  <= mac_address_in(15 downto 8);
            framed_tvalid <= '1';
            fsm_state <= SHA_6;

          when SHA_6 =>
            framed_tdata  <= mac_address_in(7 downto 0);
            framed_tvalid <= '1';
            fsm_state <= SPA_1;

          when SPA_1 =>
            framed_tdata  <= ip_address_in(31 downto 24);
            framed_tvalid <= '1';
            fsm_state <= SPA_2;

          when SPA_2 =>
            framed_tdata  <= ip_address_in(23 downto 16);
            framed_tvalid <= '1';
            fsm_state <= SPA_3;

          when SPA_3 =>
            framed_tdata  <= ip_address_in(15 downto 8);
            framed_tvalid <= '1';
            fsm_state <= SPA_4;

          when SPA_4 =>
            framed_tdata  <= ip_address_in(7 downto 0);
            framed_tvalid <= '1';
            fsm_state <= THA;
            pad_counter <= to_unsigned(5, pad_counter'length);

          when THA =>
            if active_arp_is_reply = '1' then
              case to_integer(pad_counter) is
                when 5 => framed_tdata <= sending_target_mac(47 downto 40);
                when 4 => framed_tdata <= sending_target_mac(39 downto 32);
                when 3 => framed_tdata <= sending_target_mac(31 downto 24);
                when 2 => framed_tdata <= sending_target_mac(23 downto 16);
                when 1 => framed_tdata <= sending_target_mac(15 downto 8);
                when 0 => framed_tdata <= sending_target_mac(7 downto 0);
                when others => framed_tdata <= (others => '0');
              end case;
            else
              framed_tdata <= x"00";
            end if;
            framed_tvalid <= '1';
            if pad_counter = to_unsigned(0, pad_counter'length) then
              fsm_state <= TPA_1;
            end if;
            
          when TPA_1 =>
            framed_tdata  <= sending_target_ip(31 downto 24);
            framed_tvalid <= '1';
            fsm_state <= TPA_2;

          when TPA_2 =>
            framed_tdata  <= sending_target_ip(23 downto 16);
            framed_tvalid <= '1';
            fsm_state <= TPA_3;

          when TPA_3 =>
            framed_tdata  <= sending_target_ip(15 downto 8);
            framed_tvalid <= '1';
            fsm_state <= TPA_4;

          when TPA_4 =>
            framed_tdata  <= sending_target_ip(7 downto 0);
            framed_tvalid <= '1';
            fsm_state <= S_PAD;
            pad_counter <= to_unsigned(18, pad_counter'length);

          when S_PAD =>
            framed_tdata  <= (others => '0');
            framed_tvalid <= '1';
            if pad_counter = to_unsigned(0, pad_counter'length) then
              fsm_state <= S_IDLE;
              framed_tlast <= '1';
            end if;
          
        end case;
      end if;

      if reset = '1' then
        fsm_state        <= S_IDLE;
        framed_tdata     <= (others => '0');
        framed_tuser     <= (others => '0');
        framed_tvalid    <= '0';
        framed_tlast     <= '0';
      end if;

    end if;
  end process;

  ----------------------------------------------------
  -- Output reg
  ----------------------------------------------------

  output_tready <= m_axis_tready_in or not output_tvalid;

  process(clk)
  begin
    if rising_edge(clk) then

      if output_tready = '1' then
        output_tdata  <= framed_tdata;
        output_tuser  <= framed_tuser;
        output_tvalid <= framed_tvalid;
        output_tlast  <= framed_tlast;
      end if;

      if reset = '1' then
        output_tdata  <= (others => '0');
        output_tuser  <= (others => '0');
        output_tvalid <= '0';
        output_tlast  <= '0';
      end if;

    end if;
  end process;

  m_axis_tdata_out  <= output_tdata;
  m_axis_tuser_out  <= output_tuser;
  m_axis_tvalid_out <= output_tvalid;
  m_axis_tlast_out  <= output_tlast;

  ----------------------------------------------------
  -- Drive Ethernet Destination MAC output
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if fsm_state /= S_IDLE or output_tuser(0) = '1' then
        if active_arp_is_reply = '1' then
          -- Set to request sender's MAC
          eth_dest_mac_out <= sending_target_mac;
        else
          -- GARP -> Broadcast
          eth_dest_mac_out <= (others => '1');
        end if;
      else
        -- Set to software set value
        eth_dest_mac_out <= destination_mac_in;
      end if;

      if reset = '1' then
        eth_dest_mac_out <= (others => '1');
      end if;
    end if;
  end process;

end architecture;

