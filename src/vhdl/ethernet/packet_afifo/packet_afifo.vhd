library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity packet_afifo is
  generic (
    G_LOG2_DEPTH           : natural
  );
  port (
    reset                  : in std_logic;
    --------------------------------------------------------
    wr_clk                 : in std_logic;
    s_axis_tdata_in        : in std_logic_vector;
    s_axis_tvalid_in       : in std_logic;
    s_axis_tlast_in        : in std_logic;
    s_axis_tready_out      : out std_logic;
    --------------------------------------------------------
    rd_clk                 : in std_logic;
    m_axis_tdata_out       : out std_logic_vector;
    m_axis_tvalid_out      : out std_logic;
    m_axis_tlast_out       : out std_logic;
    m_axis_tready_in       : in std_logic
  );
end entity packet_afifo;

architecture rtl of packet_afifo is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------

  ----------------------------------------------------
  -- SIGNAL
  ----------------------------------------------------

  signal reset_rd_clk        : std_logic;
  
  signal afifo_reset_busy    : std_logic;
  signal afifo_din           : std_logic_vector(8 downto 0);
  signal afifo_we            : std_logic;
  signal afifo_full          : std_logic;
  signal afifo_dout          : std_logic_vector(8 downto 0);
  signal afifo_re            : std_logic;
  signal afifo_empty         : std_logic;


  signal fifo_din            : std_logic_vector(8 downto 0);
  signal fifo_we             : std_logic;
  signal fifo_full           : std_logic;
  signal fifo_dout           : std_logic_vector(8 downto 0);
  signal fifo_re             : std_logic;
  signal fifo_empty          : std_logic;

  signal num_packets_in_fifo : unsigned(4 downto 0) := (others => '0');
  signal packet_available    : std_logic;

  signal read_packet         :  std_logic := '0';


begin

  s_axis_tready_out <= not afifo_full;

  afifo_din <= s_axis_tlast_in & s_axis_tdata_in;
  afifo_we  <= s_axis_tvalid_in and not afifo_reset_busy;

  ----------------------------------------------------
  -- Transfer reset from wr_clk to rd_clk
  ----------------------------------------------------
  i_reset_pulse_transfer : entity work.pulse_transfer
    port map (
      clk_a              => wr_clk,
      clk_b              => rd_clk,
      a_pulse_in         => reset,
      a_ready_out        => open,
  
      b_pulse_out        => reset_rd_clk
    );

  ----------------------------------------------------
  -- Cross clock domains
  ----------------------------------------------------
  i_afifo : entity work.afifo
    generic map (
      G_DATA_WIDTH     => 9,
      G_LOG2_DEPTH     => G_LOG2_DEPTH,
      G_FWFT           => true
    )
    port map (
      wr_clk           => wr_clk,
      reset            => reset,
      reset_busy       => afifo_reset_busy,
      write_data       => afifo_din,
      write_en         => afifo_we,
      full             => afifo_full,
      --------------------------------------------------
      rd_clk           => rd_clk,
      read_data        => afifo_dout,
      read_en          => afifo_re,
      empty            => afifo_empty
    );

  ----------------------------------------------------
  -- Buffer entire packets
  ----------------------------------------------------


  i_skid_buffer : entity work.skid_buffer_single
  generic map (
    G_DATA_WIDTH           => 9
  )
  port map (
    clk             => rd_clk,
    reset           => reset_rd_clk,
    --------------------------------------------------------
    data_in        => afifo_dout,
    valid_in       => not afifo_empty,
    ready_out      => afifo_re,
    --------------------------------------------------------
    data_out       => fifo_din,
    valid_out      => fifo_we,
    ready_in       => not fifo_full
  );

  i_fifo : entity work.fifo
  generic map (
    G_DATA_WIDTH              => 9,
    G_LOG2_DEPTH              => G_LOG2_DEPTH
  )
  port map (
    clk              => rd_clk,
    sreset           => reset_rd_clk,
    --------------------------------------------------
    write_data       => fifo_din,
    write_en         => fifo_we,
    full             => fifo_full,
    --------------------------------------------------
    read_data        => fifo_dout,
    read_en          => fifo_re,
    empty            => fifo_empty
  );

  ----------------------------------------------------
  -- Keep track of how many packets are contained within the FIFO
  ----------------------------------------------------

  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      
      if (fifo_we = '1' and fifo_full = '0' and fifo_din(8) = '1') and (fifo_re = '0' or fifo_dout(8) = '0' or fifo_empty = '1') then
        num_packets_in_fifo <= num_packets_in_fifo + 1;
      elsif (fifo_we = '0' or fifo_full = '1' or fifo_din(8) = '0') and (fifo_re = '1' and fifo_dout(8) = '1' and fifo_empty = '0') then
        num_packets_in_fifo <= num_packets_in_fifo - 1;
      end if;

      if reset_rd_clk = '1' then
        num_packets_in_fifo <= (others => '0');
      end if;

    end if;
  end process;

  packet_available <= '1' when num_packets_in_fifo /= (num_packets_in_fifo'range => '0') else '0';

  fifo_re <= m_axis_tready_in when read_packet = '1' else '0';

  process(rd_clk)
  begin
    if rising_edge(rd_clk) then

      if packet_available = '1' then
        read_packet <= '1';
      end if;

      if fifo_re = '1' and fifo_dout(8) = '1' and fifo_empty = '0' then
        read_packet <= '0';
      end if;
      
      if reset_rd_clk = '1' then
        read_packet <= '0';
      end if;

    end if;
  end process;

  m_axis_tdata_out  <= fifo_dout(7 downto 0);
  m_axis_tvalid_out <= read_packet and not fifo_empty;
  m_axis_tlast_out  <= fifo_dout(8);


end architecture; 