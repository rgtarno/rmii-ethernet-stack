library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity axi_uart_tx is
  generic (
    G_CLK_RATE_Hz      : natural := 100000000;
    G_BAUD_RATE_Hz     : natural := 115200;
    G_FRAME_LENGTH     : natural := 8
  );
  port (
    clk              : in std_logic;
    reset            : in std_logic;
    --------------------------------------------------------
    s_axi_tdata_in   : in std_logic_vector(G_FRAME_LENGTH - 1 downto 0);
    s_axi_tvalid_in  : in std_logic;
    s_axi_tready_out : out std_logic;
    --------------------------------------------------------
    tx_out           : out std_logic
  );
end entity axi_uart_tx;

architecture behavioural of axi_uart_tx is

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
  type t_state is (S_IDLE, S_START_BIT, S_DATA, S_STOP_BIT);

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal ready             : std_logic;
  signal tx_data           : std_logic_vector(G_FRAME_LENGTH - 1 downto 0) := (others => '0');
  signal tx_data_valid     : std_logic := '0';
  signal tx_done           : std_logic := '0';

  signal baud_counter_u    : unsigned(log2_ceil(C_BAUD_PERIOD_INT)-1 downto 0) := (others => '0');
  signal baud_en           : std_logic;

  signal state             : t_state := S_IDLE;
  signal tx_bit_count_u    : unsigned(log2_ceil(G_FRAME_LENGTH)-1 downto 0) := (others => '0');

begin

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

      if reset = '1'then
        baud_counter_u <= (others => '0');
        baud_en        <= '0';
      end if;

    end if;
  end process;


  --------------------------------------------
  -- Latch input data and generate ready signal
  --------------------------------------------

  ready            <= tx_done or not tx_data_valid;
  s_axi_tready_out <= ready;

  process (clk)
  begin
    if rising_edge(clk) then

      if ready = '1' then
        tx_data         <= s_axi_tdata_in;
        tx_data_valid   <= s_axi_tvalid_in;
      end if;
     
      if reset = '1' then
        tx_data_valid        <= '0';
      end if;

    end if;
  end process;

  
  --------------------------------------------
  -- TX FSM
  --------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then

      tx_done <= '0';

      case state is

        when S_IDLE =>
          tx_out         <= '1';
          tx_bit_count_u <= (others => '0');

          if baud_en = '1' and tx_data_valid = '1' then
            state <= S_START_BIT;
          end if;

        when S_START_BIT =>
          tx_out <= '0';

          if baud_en = '1' then
            state <= S_DATA;
          end if;

        when S_DATA =>
          tx_out <= tx_data(to_integer(tx_bit_count_u));
    
          if baud_en = '1' then
            tx_bit_count_u <= tx_bit_count_u + 1;
            if tx_bit_count_u = C_FRAME_LENGTH_MINUS_1_U then
              state   <= S_STOP_BIT;
              tx_done <= '1'; -- Ack now so that a new value can be accepted at the input, ready for the next frame.
            end if;
          end if;

        when S_STOP_BIT =>
          tx_out <= '1';
          if baud_en = '1' then
            state   <= S_IDLE;
          end if;

      end case;

      if reset = '1' then
        state   <= S_IDLE;
        tx_done <= '0';
      end if;

    end if;
  end process;


end architecture behavioural;