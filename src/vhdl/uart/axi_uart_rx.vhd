library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity axi_uart_rx is
  generic (
    G_CLK_RATE_Hz      : natural := 100000000;
    G_BAUD_RATE_Hz     : natural := 115200;
    G_FRAME_LENGTH     : natural := 8
  );
  port (
    clk              : in std_logic;
    reset            : in std_logic;
    --------------------------------------------------------
    rx_in            : in std_logic;
    --------------------------------------------------------
    s_axi_tdata_out  : out std_logic_vector(G_FRAME_LENGTH - 1 downto 0);
    s_axi_tvalid_out : out std_logic
  );
end entity axi_uart_rx;

architecture behavioural of axi_uart_rx is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_BAUD_PERIOD_INT        : integer := G_CLK_RATE_Hz / G_BAUD_RATE_Hz;
  constant C_BAUD_HALF_PERIOD_INT   : integer := C_BAUD_PERIOD_INT / 2;
  constant C_BAUD_PERIOD_U          : unsigned(log2_ceil(C_BAUD_PERIOD_INT)-1 downto 0) := to_unsigned(C_BAUD_PERIOD_INT, log2_ceil(C_BAUD_PERIOD_INT));
  constant C_BAUD_HALF_PERIOD_U     : unsigned(log2_ceil(C_BAUD_HALF_PERIOD_INT)-1 downto 0) := to_unsigned(C_BAUD_HALF_PERIOD_INT, log2_ceil(C_BAUD_HALF_PERIOD_INT));
  constant C_FRAME_LENGTH_MINUS_1_U : unsigned(log2_ceil(G_FRAME_LENGTH-1)-1 downto 0) := to_unsigned(G_FRAME_LENGTH-1, log2_ceil(G_FRAME_LENGTH-1));


  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type t_state is (S_IDLE, S_DATA, S_STOP_BIT);

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  signal rx_in_r           : std_logic := '0';
  signal rx_in_rr          : std_logic := '0';
  signal rx_in_rrr         : std_logic := '0';

  signal baud_counter_u    : unsigned(log2_ceil(C_BAUD_PERIOD_INT)-1 downto 0) := (others => '0');
  signal baud_en           : std_logic;
  signal baud_reset        : std_logic;

  signal state             : t_state := S_IDLE;
  signal start_counter_u   : unsigned(log2_ceil(C_BAUD_HALF_PERIOD_INT)-1 downto 0) := (others => '0');
  signal rx_bit_count_u    : unsigned(log2_ceil(G_FRAME_LENGTH)-1 downto 0) := (others => '0');

  signal rx_buffer         : std_logic_vector(G_FRAME_LENGTH - 1 downto 0) := (others => '0');

begin


  --------------------------------------------
  -- Synchronise input
  --------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      rx_in_r   <= rx_in;
      rx_in_rr  <= rx_in_r;
      rx_in_rrr <= rx_in_rr;
    end if;
  end process;

  --------------------------------------------
  -- Generate baud enable
  --------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then

      baud_counter_u <= baud_counter_u + 1;
      baud_en        <= '0';

      if baud_counter_u = C_BAUD_PERIOD_U then
        baud_counter_u <= (others => '0');
        baud_en        <= '1';
      end if;

      if (reset = '1') or (baud_reset = '1') then
        baud_counter_u <= (others => '0');
        baud_en        <= '0';
      end if;

    end if;
  end process;


  --------------------------------------------
  -- Rx FSM
  --------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      s_axi_tvalid_out <= '0';

      case state is

        when S_IDLE =>
          baud_reset      <= '1';
          start_counter_u <= (others => '0');
          rx_bit_count_u  <= (others => '0');

          if rx_in_rrr = '0' then
            start_counter_u <= start_counter_u + 1;

            -- Synchronise baud generator with middle of the bit period
            if start_counter_u = C_BAUD_HALF_PERIOD_U then
              baud_reset      <= '0';
              state           <= S_DATA;
            end if;
          end if;

        when S_DATA =>
          baud_reset <= '0';

          if baud_en = '1' then
            rx_bit_count_u <= rx_bit_count_u + 1;
            if rx_bit_count_u = C_FRAME_LENGTH_MINUS_1_U then
              state <= S_STOP_BIT;
              s_axi_tvalid_out <= '1';
            end if;
          end if;

        when S_STOP_BIT =>
          baud_reset <= '0';
          if baud_en = '1' then
            state <= S_IDLE;
          end if;

      end case;

      if reset = '1' then
        state            <= S_IDLE;
        s_axi_tvalid_out <= '0';
      end if;

    end if;
  end process;


  --------------------------------------------
  -- Rx shift register
  --------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if (baud_en = '1') and (state = S_DATA) then
        rx_buffer     <= rx_in_rrr & rx_buffer(G_FRAME_LENGTH-1 downto 1);
      end if;
    end if;
  end process;

  s_axi_tdata_out <= rx_buffer;

end architecture behavioural;