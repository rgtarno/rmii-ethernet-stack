library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

-- Buffer up an entire packet, the value of s_axis_tuser_in(0) that conicides with s_axis_tlast_in indicates whether the packet has failed FCS
-- and should be dropped.
entity rx_packet_buffer is
  generic (
    G_LOG2_DEPTH           : natural
  );
  port (
    clk                    : in std_logic;
    reset                  : in std_logic;
    --------------------------------------------------------
    overflowed_out         : out std_logic;
    dropped_packets_count  : out std_logic_vector(15 downto 0);
    --------------------------------------------------------
    s_axis_tdata_in        : in std_logic_vector;
    s_axis_tuser_in        : in std_logic_vector(0 downto 0);
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    --------------------------------------------------------
    m_axis_tdata_out       : out std_logic_vector;
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic;
    m_axis_tready_in       : in std_logic
  );
end entity rx_packet_buffer;

architecture rtl of rx_packet_buffer is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_NUM_ROWS   : natural := pow_2(G_LOG2_DEPTH);
  constant G_DATA_WIDTH : natural := s_axis_tdata_in'length + 1;

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type ram_t is array(0 to C_NUM_ROWS-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);

  ----------------------------------------------------
  -- SIGNAL
  ----------------------------------------------------

  signal ram : ram_t := (others => (others => '0'));

  -- Pointers are 1 bit larger than required to address all ram elements
  -- this alows us to distinguish full and empty cases, as 1 of the pointers will have wrapped and
  -- the most significant bit will be set compared to the other
  signal read_pointer          : unsigned(G_LOG2_DEPTH downto 0) := (others => '0');
  signal write_pointer         : unsigned(G_LOG2_DEPTH downto 0) := (others => '0');
  signal read_address          : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');
  signal write_address         : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');

  signal empty_sig             : std_logic;
  signal full_sig              : std_logic;


  signal packet_length_counter : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');

  signal fifo_din              : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal fifo_dout             : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');

  -- Pulses high when we receive the last word of a good packet
  signal packet_good           : std_logic := '0';
  signal read_packet           : std_logic := '0';

  signal fwft_read             : std_logic;
  signal output_valid_r        : std_logic := '0';

  -- Number of packets remaining in the fifo, waiting to be read out
  signal good_packets_remaining : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');

  signal dropped_packets_count_u : unsigned(15 downto 0) := (others => '0');

begin

  dropped_packets_count <= std_logic_vector(dropped_packets_count_u);

  ----------------------------------------------------
  -- Latch overflow case as we cannot recover from it
  ----------------------------------------------------
  p_overflow : process (clk)
  begin
    if rising_edge(clk) then

      if s_axis_tvalid_in = '1' and full_sig = '1' then
        overflowed_out <= '1';
      end if;

      if reset = '1' then
        overflowed_out <= '0';
      end if;

    end if;
  end process;


  ----------------------------------------------------
  -- Buffer entire packets
  ----------------------------------------------------

  read_address  <= read_pointer(G_LOG2_DEPTH-1 downto 0);
  write_address <= write_pointer(G_LOG2_DEPTH-1 downto 0);

  empty_sig <= '1' when write_pointer = read_pointer else '0';
  full_sig <= '1'  when (read_address = write_address) and (read_pointer(G_LOG2_DEPTH) /= write_pointer(G_LOG2_DEPTH)) else '0';

  fifo_din <= s_axis_tlast_in & s_axis_tdata_in;

  p_write : process (clk)
  begin
    if rising_edge(clk) then

      if s_axis_tvalid_in = '1' and full_sig = '0' then
        write_pointer                  <= write_pointer + 1;
        ram(to_integer(write_address)) <= fifo_din;
        packet_length_counter <= packet_length_counter + 1;

        if s_axis_tlast_in = '1' then
          packet_length_counter <= (others => '0');

          -- If the packet is bad, wind back the write_pointer
          if s_axis_tuser_in(0) = '1' then
            write_pointer <= write_pointer - ("0" & packet_length_counter);
            dropped_packets_count_u <= dropped_packets_count_u + 1;
          end if;
        end if;

      end if;

      if reset = '1' then
        write_pointer <= (others => '0');
        packet_length_counter <= (others => '0');
        dropped_packets_count_u <= (others => '0');
      end if;

    end if;
  end process;

  -- Signal to the read side to read out one more packet
  packet_good <= '1' when s_axis_tlast_in = '1' and s_axis_tvalid_in = '1' and s_axis_tuser_in(0) = '0' else '0';

  ----------------------------------------------------
  -- Read packets out of the FIFO
  ----------------------------------------------------

  p_read : process (clk)
  begin
    if rising_edge(clk) then

      if fwft_read = '1' and empty_sig = '0' then
        read_pointer <= read_pointer + 1;
      end if;

      if reset = '1' then
        read_pointer <= (others => '0');
      end if;

    end if;
  end process;

  p_fwft : process(clk)
  begin
    if rising_edge(clk) then
      if fwft_read = '1' then
        fifo_dout     <= ram(to_integer(read_address));
        output_valid_r <= not empty_sig;
      end if;

      if reset = '1' then
        output_valid_r <= '0';
      end if;

    end if;    
  end process;

  fwft_read  <= read_packet or packet_good;
  read_packet <= '1' when good_packets_remaining /= to_unsigned(0, good_packets_remaining'length) else '0';

  process(clk)
  begin
    if rising_edge(clk) then

      -- If a good packet was inserted and we didnt just finish reading out a packet
      if packet_good = '1' and (fifo_dout(G_DATA_WIDTH-1) = '0' or output_valid_r = '0') then
        good_packets_remaining <= good_packets_remaining + 1;
      -- If we just read out a packet and a new one was not added
      elsif packet_good = '0' and (fifo_dout(G_DATA_WIDTH-1) = '1' and output_valid_r = '1') then
        good_packets_remaining <= good_packets_remaining - 1;
      else
        good_packets_remaining <= good_packets_remaining;
      end if;

      if reset = '1' then
        good_packets_remaining <= (others => '0');
      end if;

    end if;
  end process;

  m_axis_tdata_out  <= fifo_dout(G_DATA_WIDTH-2 downto 0);
  m_axis_tvalid_out <= fwft_read and output_valid_r;
  m_axis_tlast_out  <= fifo_dout(G_DATA_WIDTH-1);


end architecture; 