library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.apb_data_types.all;

-- Drive a APB bus from a UART interface.
-- Read transcation:
--  Send address in 4 bytes. Sent least significant byte first. Top bit of the last byte must be 0, giving 32 bits of address space
--  4 byte response is sent least significant byte first
-- Write transactions:
--  Send address in 4 bytes. Sent least significant byte first. Top bit of the last byte must be 1, giving 32 bits of address space
--  Send write payload in 4 bytes. Sent least significant byte first
--  4 byte response (writen data echoed back) is sent least significant byte first


entity uart_apb_bridge is
  generic (
    G_NUM_SLAVES          : natural;
    G_ADDR_BITS_PER_SLAVE : natural;
    G_CLK_RATE_Hz         : natural := 100000000;
    G_BAUD_RATE_Hz        : natural := 115200
  );
  port (
    clk              : in std_logic;
    reset            : in std_logic;
    --------------------------------------------------
    uart_rx          : in std_logic;
    uart_tx          : out std_logic;
    --------------------------------------------------
    apb_cmd_out      : out apb_cmd_array_t(G_NUM_SLAVES-1 downto 0);
    apb_rsp_in       : in apb_rsp_array_t(G_NUM_SLAVES-1 downto 0)
  );
end entity uart_apb_bridge;

architecture rtl of uart_apb_bridge is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_LOG2_NUM_SLAVES   : natural := log2_ceil(G_NUM_SLAVES);
  constant C_UART_FRAME_LENGTH : natural := 8;

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type state_t is (S_IDLE,
                    S_START,
                    S_WAIT_FOR_WRITE_DATA,
                    S_WAIT_FOR_RESPONSE
                    );
  
  type apb_state_t is (S_IDLE,
                        S_SETUP,
                        S_ACCESS
                        );
  
  type slave_response_data_t is array (natural range <>) of std_logic_vector(31 downto 0) ;

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal uart_rx_data   : std_logic_vector(7 downto 0);
  signal uart_rx_valid  : std_logic;
  signal uart_tx_data   : std_logic_vector(7 downto 0);
  signal uart_tx_valid  : std_logic := '0';
  signal uart_tx_ready  : std_logic := '0';

  signal rx_counter_u   : unsigned(1 downto 0) := (others => '0');
  signal rx_buffer      : std_logic_vector(31 downto 0);
  signal rx_valid       : std_logic;

  signal tx_counter_u   : unsigned(1 downto 0) := (others => '0');
  signal tx_data        : std_logic_vector(31 downto 0);
  signal tx_data_r      : std_logic_vector(31 downto 0);
  signal tx_valid       : std_logic := '0';
  signal tx_valid_l     : std_logic := '0';

  signal slave_sel_int  : integer range 0 to G_NUM_SLAVES-1;
  signal active_slave_r : integer range 0 to G_NUM_SLAVES-1;
  signal slave_addr_r   : std_logic_vector(G_ADDR_BITS_PER_SLAVE-1 downto 0) := (others => '0');
  signal write_data     : std_logic_vector(31 downto 0);

  signal slave_do_read          : std_logic_vector(G_NUM_SLAVES-1 downto 0) := (others => '0');
  signal slave_do_write         : std_logic_vector(G_NUM_SLAVES-1 downto 0) := (others => '0');
  signal slave_response_pending : std_logic_vector(G_NUM_SLAVES-1 downto 0) := (others => '0');
  signal slave_response_data    : slave_response_data_t(G_NUM_SLAVES-1 downto 0) := (others => (others => '0'));
  signal clear_response_pending : std_logic;


  signal fsm_state      : state_t := S_IDLE;
  signal is_write_op_r  : std_logic;

begin
  
---------------------------------------------------------
-- UART RX
---------------------------------------------------------
  i_axi_uart_rx : entity work.axi_uart_rx
  generic map(
    G_CLK_RATE_Hz      => G_CLK_RATE_Hz,
    G_BAUD_RATE_Hz     => G_BAUD_RATE_Hz,
    G_FRAME_LENGTH     => C_UART_FRAME_LENGTH
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------------
    rx_in            => uart_rx,
    --------------------------------------------------------
    s_axi_tdata_out  => uart_rx_data,
    s_axi_tvalid_out => uart_rx_valid
  );

  process(clk)
  begin
    if rising_edge(clk) then
      rx_valid      <= '0';

      if uart_rx_valid = '1' then
        rx_counter_u <= rx_counter_u + 1;

        case rx_counter_u is
          when "00" =>
            rx_buffer(7 downto 0) <= uart_rx_data(7 downto 0);
          when "01" =>
            rx_buffer(15 downto 8) <= uart_rx_data(7 downto 0);
          when "10" =>
            rx_buffer(23 downto 16) <= uart_rx_data(7 downto 0);
          when "11" =>
            rx_buffer(31 downto 24) <= uart_rx_data(7 downto 0);
            rx_valid   <= '1';
          when others =>
            null;
        end case;

      end if;

      if reset = '1' then
        rx_counter_u  <= (others => '0');
        rx_valid      <= '0';
      end if;

    end if;
  end process;

---------------------------------------------------------
-- UART TX
---------------------------------------------------------
i_axi_uart_tx : entity work.axi_uart_tx
  generic map (
    G_CLK_RATE_Hz      => G_CLK_RATE_Hz,
    G_BAUD_RATE_Hz     => G_BAUD_RATE_Hz,
    G_FRAME_LENGTH     => C_UART_FRAME_LENGTH
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------------
    s_axi_tdata_in   => uart_tx_data,
    s_axi_tvalid_in  => uart_tx_valid,
    s_axi_tready_out => uart_tx_ready,
    --------------------------------------------------------
    tx_out           => uart_tx
  );

  process(clk)
  begin
    if rising_edge(clk) then

      if tx_valid = '1' then
        tx_valid_l <= '1';
        tx_data_r  <= tx_data;
      end if;

      if tx_valid_l = '1' then
        uart_tx_valid <= '1';
        case tx_counter_u is
          when "00" =>
            uart_tx_data <= tx_data_r(7 downto 0);
          when "01" =>
            uart_tx_data <= tx_data_r(15 downto 8);
          when "10" =>
            uart_tx_data <= tx_data_r(23 downto 16);
          when "11" =>
            uart_tx_data <= tx_data_r(31 downto 24);
          when others =>
            null;
        end case;

        if uart_tx_ready = '1' and uart_tx_valid = '1' then
          tx_counter_u <= tx_counter_u + 1;
          if tx_counter_u = "11" then
            uart_tx_valid <= '0';
            tx_valid_l <= '0';
          end if;
        end if;
      end if;

      if reset = '1' then
        tx_counter_u  <= (others => '0');
        uart_tx_valid <= '0';
        tx_valid_l    <= '0';
      end if;
    end if;
  end process;

---------------------------------------------------------
-- FSM
---------------------------------------------------------

slave_sel_int <= to_integer(unsigned(rx_buffer(C_LOG2_NUM_SLAVES+G_ADDR_BITS_PER_SLAVE-1 downto G_ADDR_BITS_PER_SLAVE)));

process(clk)
begin
  if rising_edge(clk) then

    clear_response_pending   <= '1';
    slave_do_read            <= (others => '0');
    slave_do_write           <= (others => '0');
    tx_valid                 <= '0';

    case fsm_state is
      
      when S_IDLE =>

        if rx_valid = '1' then
          is_write_op_r         <= rx_buffer(31);
          slave_addr_r          <= rx_buffer(G_ADDR_BITS_PER_SLAVE-1 downto 0);
          active_slave_r        <= slave_sel_int;
          fsm_state             <= S_START;
        end if;

      when S_START => 

        if is_write_op_r = '1' then
          fsm_state <= S_WAIT_FOR_WRITE_DATA;
        else
          slave_do_read(active_slave_r) <= '1';
          fsm_state                     <= S_WAIT_FOR_RESPONSE;
        end if;

      when S_WAIT_FOR_WRITE_DATA =>
        if rx_valid = '1' then
          slave_do_write(active_slave_r) <= '1';
          write_data                     <= rx_buffer;
          fsm_state                      <= S_WAIT_FOR_RESPONSE;
        end if;
          

      when S_WAIT_FOR_RESPONSE =>
        clear_response_pending   <= '1';
        
        if slave_response_pending(active_slave_r) = '1' then
          tx_valid  <= '1';
          fsm_state <= S_IDLE;

          if is_write_op_r = '1' then
            tx_data <= write_data;
          else
            tx_data <= slave_response_data(active_slave_r);
          end if;
        end if;

    end case;
  
    if reset = '1' then
      fsm_state <= S_IDLE;
    end if;
    
  end if;
end process;

---------------------------------------------------------
-- APB MASTERS
---------------------------------------------------------
g_slaves : for i in 0 to G_NUM_SLAVES-1 generate
  signal apb_master_state : apb_state_t := S_IDLE;
begin

  process(clk)
  begin
    if rising_edge(clk) then
      apb_cmd_out(i).paddr      <= slave_addr_r;

      if clear_response_pending = '1' then
        slave_response_pending(i) <= '0';
      end if;

      case apb_master_state is

        when S_IDLE =>
          apb_cmd_out(i).psel    <= '0';
          apb_cmd_out(i).penable <= '0';
          apb_cmd_out(i).pwrite  <= slave_do_write(i);
          apb_cmd_out(i).pwdata  <= write_data;

          if slave_do_read(i) = '1' or slave_do_write(i) = '1' then
            apb_cmd_out(i).psel <= '1';  
            apb_master_state    <= S_SETUP;
          end if;

        when S_SETUP =>
          apb_master_state       <= S_ACCESS;
          apb_cmd_out(i).penable <= '1';

        when S_ACCESS =>
          if apb_rsp_in(i).pready = '1' then
            apb_master_state          <= S_IDLE;
            apb_cmd_out(i).penable    <= '0';
            apb_cmd_out(i).psel       <= '0';
            slave_response_pending(i) <= '1';
            slave_response_data(i)    <= apb_rsp_in(i).prdata;
          end if;

      end case;

      if reset = '1' then
        apb_master_state <= S_IDLE;
      end if;
      
    end if;

  end process;
end generate;

end architecture;