library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity udp_ip_framer is
  port (

    clk                    : in std_logic;
    reset                  : in std_logic;
    --------------------------------------------------------
    enable_in              : in std_logic;
    idle_out               : out std_logic;
    source_port_in         : in std_logic_vector(15 downto 0);
    destination_port_in    : in std_logic_vector(15 downto 0);
    src_address_in         : in std_logic_vector(31 downto 0);
    destination_address_in : in std_logic_vector(31 downto 0);
    ip_checksum_init_in    : in std_logic_vector(15 downto 0);
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
end entity udp_ip_framer;

architecture rtl of udp_ip_framer is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_FIFO_LOG2_DEPTH              : natural := 12;
  constant C_UDP_HEADER_LENGTH_BYTES      : natural := 8;
  constant C_IP_HEADER_LENGTH_BYTES       : natural := 20;
  constant C_IP_HEADER_LENGTH_BYTES_U     : unsigned(10 downto 0) := to_unsigned(C_IP_HEADER_LENGTH_BYTES, 11);
  constant C_UDP_HEADER_LENGTH_BYTES_U    : unsigned(10 downto 0) := to_unsigned(C_UDP_HEADER_LENGTH_BYTES, 11);
  constant C_IP_UDP_HEADER_LENGTH_BYTES_U : unsigned(10 downto 0) := to_unsigned(C_IP_HEADER_LENGTH_BYTES + C_UDP_HEADER_LENGTH_BYTES, 11);

  constant C_IP_HDR_WORD_1  : std_logic_vector(7 downto 0) := x"4" & -- Verison
                                                              x"5";  -- Internet header length

  constant C_IP_HDR_WORD_2    : std_logic_vector(7 downto 0) := "000000" & -- Differentiated Services Code Point
                                                                "00";   -- Explicit Congestion Notification
  constant C_IP_HDR_WORD_5    : std_logic_vector(7 downto 0) := (others => '0'); -- Identification
  constant C_IP_HDR_WORD_6    : std_logic_vector(7 downto 0) := (others => '0'); -- Identification
  constant C_IP_HDR_WORD_7    : std_logic_vector(7 downto 0) := (others => '0'); -- Flags and Fragment offset
  constant C_IP_HDR_WORD_8    : std_logic_vector(7 downto 0) := (others => '0'); -- Fragment offset

  constant C_IP_HDR_WORD_9    : std_logic_vector(7 downto 0) := x"80"; -- TTL
  constant C_IP_HDR_WORD_10   : std_logic_vector(7 downto 0) := x"11"; -- Protocol (set to UDP)
  constant C_IP_HDR_WORD_11   : std_logic_vector(7 downto 0) := (others => '0'); -- Header checksum
  constant C_IP_HDR_WORD_12   : std_logic_vector(7 downto 0) := (others => '0'); -- Header checksum

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       -- IP
                       S_IP_VERSION,
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
                       -- UDP
                       S_SRC_PORT_1,
                       S_SRC_PORT_2,
                       S_DST_PORT_1,
                       S_DST_PORT_2,
                       S_LENGTH_1,
                       S_LENGTH_2,
                       S_CHECKSUM_1,
                       S_CHECKSUM_2,
                       S_DATA
                       );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  signal ready            : std_logic;
 
  signal first_word       : std_logic := '1';

  signal data_fifo_din    : std_logic_vector(s_axis_tdata_in'range);
  signal data_fifo_we     : std_logic;
  signal data_fifo_dout   : std_logic_vector(s_axis_tdata_in'range);
  signal data_fifo_re     : std_logic;
  signal data_fifo_full   : std_logic;
  signal data_fifo_empty  : std_logic;

  signal payload_length_counter : unsigned(10 downto 0);
  signal packet_length_valid : std_logic;

  signal length_fifo_din    : std_logic_vector(payload_length_counter'length-1 downto 0);
  signal length_fifo_we     : std_logic;
  signal length_fifo_dout   : std_logic_vector(payload_length_counter'length-1 downto 0);
  signal length_fifo_re     : std_logic;
  signal length_fifo_full   : std_logic;
  signal length_fifo_empty  : std_logic;


  signal packet_available   : std_logic;
  signal framer_state       : fsm_state_t := S_IDLE;

  signal payload_data    : std_logic_vector(7 downto 0);
  signal payload_words_remaining : unsigned(payload_length_counter'range);

  signal ip_length       : std_logic_vector(15 downto 0);
  signal ip_checksum_go     : std_logic;
  signal ip_checksum_c1     : std_logic_vector(15 downto 0);
  signal ip_checksum_c2     : std_logic_vector(15 downto 0);
  signal udp_length      : std_logic_vector(15 downto 0);

  signal framed_tdata    : std_logic_vector(7 downto 0);
  signal framed_tvalid   : std_logic;
  signal framed_tlast    : std_logic;

  signal output_ready    : std_logic;
  signal output_tdata    : std_logic_vector(7 downto 0);
  signal output_tvalid   : std_logic;
  signal output_tlast    : std_logic;

begin

  ----------------------------------------------------
  -- Buffer words and count packet length
  ----------------------------------------------------

  ready             <= not (data_fifo_full or length_fifo_full) or not data_fifo_we;
  s_axis_tready_out <= ready;

  process(clk)
  begin
    if rising_edge(clk) then

      if ready = '1' and enable_in = '1' then

        packet_length_valid <= s_axis_tlast_in;

        data_fifo_we  <= s_axis_tvalid_in;
        data_fifo_din <= s_axis_tdata_in;

        if s_axis_tvalid_in = '1' then
          payload_length_counter <= payload_length_counter + 1;

          if first_word = '1' then
            payload_length_counter <= to_unsigned(1, payload_length_counter'length);
          end if;

          first_word <= '0';

          if s_axis_tlast_in = '1' then
            first_word <= '1';
          end if;
          
        end if;

      end if;

      if reset = '1' then
        packet_length_valid   <= '0';
        data_fifo_we          <= '0';
        first_word            <= '1';
      end if;

    end if;
  end process;

  i_data_fifo : entity work.fifo
  generic map (
    G_DATA_WIDTH              => s_axis_tdata_in'length,
    G_LOG2_DEPTH              => C_FIFO_LOG2_DEPTH
  )
  port map (
    clk              => clk,
    sreset           => reset,
    --------------------------------------------------
    write_data       => data_fifo_din,
    write_en         => data_fifo_we and ready,
    full             => data_fifo_full,
    --------------------------------------------------
    read_data        => data_fifo_dout,
    read_en          => data_fifo_re,
    empty            => data_fifo_empty
  );

  payload_data <= data_fifo_dout;
  data_fifo_re <= output_ready when framer_state = S_DATA else '0';

  ----------------------------------------------------
  -- Store packet lengths
  ----------------------------------------------------

  length_fifo_we  <= packet_length_valid and ready;
  length_fifo_din <= std_logic_vector(payload_length_counter);

  i_length_fifo : entity work.fifo
  generic map (
    G_DATA_WIDTH              => payload_length_counter'length,
    G_LOG2_DEPTH              => 10
  )
  port map (
    clk              => clk,
    sreset           => reset,
    --------------------------------------------------
    write_data       => length_fifo_din,
    write_en         => length_fifo_we and ready,
    full             => length_fifo_full,
    --------------------------------------------------
    read_data        => length_fifo_dout,
    read_en          => length_fifo_re,
    empty            => length_fifo_empty
  );

  length_fifo_re    <= output_ready when framer_state = S_LENGTH_2 else '0';

  ----------------------------------------------------
  -- FSM
  ----------------------------------------------------

  ip_checksum_go <= output_ready when framer_state = S_IP_TTL else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if ip_checksum_go = '1' then
        ip_checksum_c1 <= std_logic_vector(unsigned(ip_checksum_init_in) + unsigned( ip_length));
      end if;

      ip_checksum_c2 <= not ip_checksum_c1;
    end if;
  end process;


  packet_available <= not length_fifo_empty;

  idle_out <= '1' when framer_state = S_IDLE else '0';

  process(clk)
  begin
    if rising_edge(clk) then

      if output_ready = '1' then

        framed_tvalid  <= '0';
        framed_tlast   <= '0';

        case framer_state is 
          when S_IDLE =>

            if packet_available = '1' and enable_in = '1' then
              framer_state            <= S_IP_VERSION;
              payload_words_remaining <= unsigned(length_fifo_dout) - 1;
              udp_length              <= std_logic_vector(unsigned(extend(length_fifo_dout, 16)) + ("00000" & C_UDP_HEADER_LENGTH_BYTES_U));
              ip_length               <= std_logic_vector(unsigned(extend(length_fifo_dout, 16)) + ("00000" & C_IP_UDP_HEADER_LENGTH_BYTES_U));
            end if;

          when S_IP_VERSION =>
            framer_state   <= S_IP_DSCP;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_1;

          when S_IP_DSCP =>
            framer_state   <= S_IP_LEN_1;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_2;

          when S_IP_LEN_1 =>
            framer_state <= S_IP_LEN_2;
            framed_tvalid  <= '1';
            framed_tdata   <= ip_length(15 downto 8);

          when S_IP_LEN_2 =>
            framer_state <= S_IP_ID_1;
            framed_tvalid  <= '1';
            framed_tdata   <= ip_length(7 downto 0);

          when S_IP_ID_1 =>
            framer_state <= S_IP_ID_2;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_5;

          when S_IP_ID_2 =>
            framer_state <= S_IP_FLAGS_1;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_6;

          when S_IP_FLAGS_1 =>
            framer_state <= S_IP_FLAGS_2;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_7;

          when S_IP_FLAGS_2 =>
            framer_state <= S_IP_TTL;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_8;

          when S_IP_TTL =>
            framer_state <= S_IP_PROTOCOL;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_9;

          when S_IP_PROTOCOL =>
            framer_state <= S_IP_HDR_CHECKSUM_1;
            framed_tvalid  <= '1';
            framed_tdata   <= C_IP_HDR_WORD_10;

          when S_IP_HDR_CHECKSUM_1 =>
            framer_state   <= S_IP_HDR_CHECKSUM_2;
            framed_tvalid  <= '1';
            framed_tdata   <= ip_checksum_c2(15 downto 8);

          when S_IP_HDR_CHECKSUM_2 =>
            framer_state   <= S_IP_SRC_IP_1;
            framed_tvalid  <= '1';
            framed_tdata   <= ip_checksum_c2(7 downto 0);

          when S_IP_SRC_IP_1 =>
            framer_state <= S_IP_SRC_IP_2;
            framed_tvalid  <= '1';
            framed_tdata   <= src_address_in(31 downto 24);

          when S_IP_SRC_IP_2 =>
            framer_state <= S_IP_SRC_IP_3;
            framed_tvalid  <= '1';
            framed_tdata   <= src_address_in(23 downto 16);

          when S_IP_SRC_IP_3 =>
            framer_state <= S_IP_SRC_IP_4;
            framed_tvalid  <= '1';
            framed_tdata   <= src_address_in(15 downto 8);

          when S_IP_SRC_IP_4 =>
            framer_state <= S_IP_DST_IP_1;
            framed_tvalid  <= '1';
            framed_tdata   <= src_address_in(7 downto 0);

          when S_IP_DST_IP_1 =>
            framer_state <= S_IP_DST_IP_2;
            framed_tvalid  <= '1';
            framed_tdata   <= destination_address_in(31 downto 24);

          when S_IP_DST_IP_2 =>
            framer_state <= S_IP_DST_IP_3;
            framed_tvalid  <= '1';
            framed_tdata   <= destination_address_in(23 downto 16);

          when S_IP_DST_IP_3 =>
            framer_state <= S_IP_DST_IP_4;
            framed_tvalid  <= '1';
            framed_tdata   <= destination_address_in(15 downto 8);

          when S_IP_DST_IP_4 =>
            framer_state <= S_SRC_PORT_1;
            framed_tvalid  <= '1';
            framed_tdata   <= destination_address_in(7 downto 0);


          when S_SRC_PORT_1 =>
            framed_tvalid <= '1';
            framed_tdata  <= source_port_in(15 downto 8);
            framer_state  <= S_SRC_PORT_2;
            
          when S_SRC_PORT_2 =>
            framed_tvalid <= '1';
            framed_tdata  <= source_port_in(7 downto 0);
            framer_state  <= S_DST_PORT_1;

          when S_DST_PORT_1 =>
            framed_tvalid <= '1';
            framed_tdata  <= destination_port_in(15 downto 8);
            framer_state  <= S_DST_PORT_2;

          when S_DST_PORT_2 =>
            framed_tvalid <= '1';
            framed_tdata  <= destination_port_in(7 downto 0);
            framer_state  <= S_LENGTH_1;

          when S_LENGTH_1 =>
            framed_tvalid <= '1';
            framed_tdata  <= udp_length(15 downto 8);
            framer_state  <= S_LENGTH_2;

          when S_LENGTH_2 =>
            framed_tvalid <= '1';
            framed_tdata  <= udp_length(7 downto 0);
            framer_state  <= S_CHECKSUM_1;

          when S_CHECKSUM_1 =>
            framed_tvalid <= '1';
            framed_tdata  <= (others => '0'); -- Indicates the checksum is not used
            framer_state  <= S_CHECKSUM_2;

          when S_CHECKSUM_2 =>
            framed_tvalid <= '1';
            framed_tdata  <= (others => '0'); -- Indicates the checksum is not used
            framer_state  <= S_DATA;

          when S_DATA =>
            framed_tvalid <= '1';
            framed_tdata  <= payload_data;

            payload_words_remaining <= payload_words_remaining - 1;
            if payload_words_remaining = (payload_words_remaining'range => '0') then
              framer_state  <= S_IDLE;
              framed_tlast  <= '1';
            end if;
          
          when others =>
            report "ERROR";

        end case;

      end if;

    
      if reset = '1' then
        framer_state  <= S_IDLE;
        framed_tvalid <= '0';
        framed_tlast  <= '0';
      end if;

    end if;
  end process;

  ----------------------------------------------------
  -- Output reg
  ----------------------------------------------------

  output_ready <= m_axis_tready_in or not output_tvalid;

  process(clk)
  begin
    if rising_edge(clk) then
      if output_ready = '1' then
        output_tdata  <= framed_tdata;
        output_tvalid <= framed_tvalid;
        output_tlast  <= framed_tlast;
      end if;

      if reset = '1' then
        output_tvalid <= '0';
        output_tlast  <= '0';
        output_tdata  <= (others => '0');
      end if;
    end if;
  end process;

  m_axis_tdata_out  <= output_tdata;
  m_axis_tvalid_out <= output_tvalid;
  m_axis_tlast_out  <= output_tlast;
  
end architecture;