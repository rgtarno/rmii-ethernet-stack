library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.utils.all;

-- MDIO interface
-- MDIO is a 2 wire inteface between MAC's and PHYS for management and config.
-- It is comprised of 2 lines:
-- - MDC : Clock signal @ max freq of 2.5 MHz
-- - MDIO : Bidirectional data line
--
-- See https://en.wikipedia.org/wiki/Management_Data_Input/Output for more info and timing diagram
-- Note, when the MAC writes to the PHY data is launched on the falling edge of MDC. There is a 10ns setup time requirement,
-- so even @ 2.5 MHz (400ns period) there is 190ns for the pulse to travel to and settle at the PHY and a 200ns hold time.
-- 
-- When reading from the PHY, data is sampled on the rising edge. The PHY has to output the read data a max of 300ns after the rising edge,
-- so there is a 100-10 ns time for the signal to arrive at the MAC.

entity mdio is
  generic (
  G_CLK_FREQ_Hz : natural;
  G_MDC_FREQ_Hz : natural
  );
  port (
  clk               : in std_logic;
  reset             : in std_logic;
  --------------------------------------------------------
  ready_out         : out std_logic;
  send_msg_in       : in std_logic;
  write_enable_in   : in std_logic;
  phy_address_in    : in std_logic_vector(4 downto 0);
  reg_address_in    : in std_logic_vector(4 downto 0);
  write_data_in     : in std_logic_vector(15 downto 0);
  --------------------------------------------------------
  read_data_out     : out std_logic_vector(15 downto 0);
  op_done           : out std_logic;
  --------------------------------------------------------
  mdio_in           : in std_logic;
  mdio_out          : out std_logic;
  mdio_tristate_out : out std_logic;
  mdc_out           : out std_logic
  );
end entity mdio;

architecture rtl of mdio is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_CLK_DIV_COUNT_N        : natural := G_CLK_FREQ_Hz / G_MDC_FREQ_Hz; -- CLK periods per MDC
  constant C_CLK_DIV_COUNT_HALF_N   : natural := C_CLK_DIV_COUNT_N / 2;         -- MDC half period
  constant C_CLK_DIV_COUNT_U        : unsigned(log2_ceil(C_CLK_DIV_COUNT_N-1)-1 downto 0) := to_unsigned(C_CLK_DIV_COUNT_N, log2_ceil(C_CLK_DIV_COUNT_N-1));
  constant C_CLK_DIV_COUNT_HALF_U   : unsigned(log2_ceil(C_CLK_DIV_COUNT_N-1)-1 downto 0) := to_unsigned(C_CLK_DIV_COUNT_HALF_N, log2_ceil(C_CLK_DIV_COUNT_N-1));
  
  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       S_PREAMBLE,
                       S_START_1,
                       S_START_2,
                       S_OP_1,
                       S_OP_2,
                       S_PHY_ADDRESS,
                       S_REG_ADDRESS,
                       S_TURN_AROUND_1,
                       S_TURN_AROUND_2,
                       S_WRITE_DATA,
                       S_READ_DATA,
                       S_DONE
                      );
  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------
  
  signal clk_div_counter  : unsigned(C_CLK_DIV_COUNT_U'range) := (others => '0');
  signal mdc              : std_logic := '0';
  signal mdc_rising       : std_logic := '0';
  signal mdc_falling      : std_logic := '0';

  signal fsm_state        : fsm_state_t := S_IDLE;
  signal next_state       : fsm_state_t;

  signal phy_address_r    : std_logic_vector(4 downto 0);
  signal reg_address_r    : std_logic_vector(4 downto 0);
  signal write_data_r     : std_logic_vector(15 downto 0);
  signal op_is_write_r    : std_logic;
  signal op_in_progress   : std_logic := '0';
  signal op_finished_comb : std_logic := '0';
  signal op_finished_r    : std_logic := '0';
  signal ready            : std_logic := '0';


  signal mdio_tristate_comb : std_logic;
  signal mdio_output_comb   : std_logic;

  signal bit_counter                : unsigned(4 downto 0) := (others => '0');
  signal load_bit_counter           : std_logic := '0';
  signal load_bit_counter_data      : unsigned(4 downto 0) := (others => '0');
  signal load_bit_counter_data_comb : unsigned(4 downto 0) := (others => '0');
  signal load_bit_counter_comb      : std_logic := '0';

  signal read_data_en               : std_logic_vector(15 downto 0) := (others => '0');
  
begin


----------------------------------------------------
-- Latch input data
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then

    if send_msg_in = '1' and ready = '1' then
      op_is_write_r  <= write_enable_in;
      phy_address_r  <= phy_address_in;
      reg_address_r  <= reg_address_in;
      write_data_r   <= write_data_in;
      op_in_progress <= '1';
    end if;
    
    if op_finished_comb = '1' then
      op_in_progress <= '0';
    end if;

    if reset = '1' then
      op_in_progress <= '0';
      op_is_write_r  <= '0';
      phy_address_r  <= (others => '0');
      reg_address_r  <= (others => '0');
      write_data_r   <= (others => '0');
    end if;
  end if;
end process;

ready <= '1' when (op_in_progress = '0') and (fsm_state = S_IDLE) else '0';
ready_out <= ready;

process(clk)
begin
  if rising_edge(clk) then
    op_done <= '0';

    op_finished_r <= op_finished_comb;
    if op_finished_comb = '1' and op_finished_r = '0' then
      op_done <= '1';
    end if;
  end if;
end process;

----------------------------------------------------
-- Generate MDC
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then
    clk_div_counter <= clk_div_counter + 1;
    if clk_div_counter = C_CLK_DIV_COUNT_U or reset = '1' then
      clk_div_counter <= (others => '0');
    end if;
  end if;
end process;
  

process(clk)
begin
  if rising_edge(clk) then

    mdc_rising  <= '0';
    mdc_falling <= '0';

    if clk_div_counter = C_CLK_DIV_COUNT_U then
      mdc_falling <= '1';
      mdc         <= '0';
    end if;

    if clk_div_counter = C_CLK_DIV_COUNT_HALF_U then
      mdc_rising <= '1';
      mdc        <= '1';
    end if;
    
    if reset = '1' then
      mdc         <= '0';
      mdc_rising  <= '0';
      mdc_falling <= '0';
    end if;

  end if;
end process;

mdc_out <= mdc and op_in_progress;

----------------------------------------------------
-- Drive the tri-state enable
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then

    if mdc_falling = '1' then
      mdio_tristate_out <= mdio_tristate_comb;
    end if;

    if  reset = '1' then
      mdio_tristate_out <= '1';
    end if;
  end if;
end process;

----------------------------------------------------
-- Register output data on falling edge of MDC
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then
    if mdc_falling = '1' then
      mdio_out <= mdio_output_comb;
    end if;

    if reset = '1' then
      mdio_out <= '0';
    end if;
  end if;
end process;

----------------------------------------------------
-- Sample incomming data on rising edge
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then

    if mdc_rising = '1' then
      for i in 0 to 15 loop
        if read_data_en(i) = '1' then
          read_data_out(i) <= mdio_in;
        end if;
      end loop;
    end if;

    if reset = '1' then
      read_data_out <= (others => '0');
    end if;
  end if;
end process;

----------------------------------------------------
-- Bit counter
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then
   
    load_bit_counter_data <= load_bit_counter_data_comb;
    load_bit_counter <= load_bit_counter_comb;

    if reset = '1' then
      load_bit_counter_data <= (others => '0');
      load_bit_counter <= '0';
    end if;
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
   
    if mdc_rising = '1' then
      bit_counter <= bit_counter - 1;

      if load_bit_counter = '1' then
        bit_counter <= load_bit_counter_data;
      end if;
    end if;

    if reset = '1' then
      bit_counter           <= (others => '0');
    end if;
  end if;
end process;

----------------------------------------------------
-- Register next state
----------------------------------------------------
process(clk)
begin
  if rising_edge(clk) then
    if mdc_rising = '1' then
      fsm_state <= next_state;
    end if;

    if  reset = '1' then
      fsm_state <= S_IDLE;
    end if;
  end if;
end process;

----------------------------------------------------
-- Combinatorial logic
----------------------------------------------------
process(fsm_state, op_in_progress, bit_counter, phy_address_r, reg_address_r, write_data_r, op_is_write_r)
begin
  next_state                 <= fsm_state;
  op_finished_comb           <= '0';
  mdio_tristate_comb         <= '0';
  mdio_output_comb           <= '1';
  load_bit_counter_data_comb <= (others => '0');
  load_bit_counter_comb      <= '0';
  read_data_en               <= (others => '0');

  case fsm_state is
    when S_IDLE =>
      if op_in_progress = '1' then
        next_state <= S_PREAMBLE;
        load_bit_counter_comb <= '1';
        load_bit_counter_data_comb <= (others => '1');
      end if;

    when S_PREAMBLE =>
        mdio_output_comb    <= '1';
        if bit_counter = (bit_counter'range => '0') then
          next_state <= S_START_1;
        end if;

    when S_START_1 =>
      mdio_output_comb    <= '0';
      next_state          <= S_START_2;

    when S_START_2 =>
      mdio_output_comb    <= '1';
      next_state          <= S_OP_1;

    when S_OP_1 =>
      mdio_output_comb    <= not op_is_write_r;
      next_state          <= S_OP_2;

    when S_OP_2 =>
      next_state            <= S_PHY_ADDRESS;
      mdio_output_comb      <= op_is_write_r;
      load_bit_counter_comb <= '1';
      load_bit_counter_data_comb <= to_unsigned(4, load_bit_counter_data_comb'length);

    when S_PHY_ADDRESS =>
      mdio_output_comb  <= phy_address_r(to_integer(bit_counter));
      if bit_counter = (bit_counter'range => '0') then
        next_state <= S_REG_ADDRESS;
        load_bit_counter_comb <= '1';
        load_bit_counter_data_comb <= to_unsigned(4, load_bit_counter_data_comb'length);
      end if;

    when S_REG_ADDRESS =>
      mdio_output_comb    <= reg_address_r(to_integer(bit_counter));
        if bit_counter = (bit_counter'range => '0') then
          next_state <= S_TURN_AROUND_1;
        end if;

    when S_TURN_AROUND_1 =>
      mdio_tristate_comb  <= not op_is_write_r;
      mdio_output_comb    <= '1';
      next_state          <= S_TURN_AROUND_2;
          

    when S_TURN_AROUND_2 =>
      mdio_tristate_comb    <= not op_is_write_r;
      mdio_output_comb      <= '0';
      load_bit_counter_comb <= '1';
      load_bit_counter_data_comb <= to_unsigned(15, load_bit_counter_data_comb'length);
      if op_is_write_r = '1' then
        next_state  <= S_WRITE_DATA;
      else
        next_state  <= S_READ_DATA;
      end if;

    when S_WRITE_DATA =>
      mdio_output_comb <= write_data_r(to_integer(bit_counter));
      if bit_counter = (bit_counter'range => '0') then
        next_state  <= S_DONE;
      end if;

    when S_READ_DATA =>
      mdio_tristate_comb <= '1';
      read_data_en(to_integer(bit_counter)) <= '1';
      if bit_counter = (bit_counter'range => '0') then
        next_state  <= S_DONE;
      end if;

    when S_DONE =>
      mdio_tristate_comb <= '1';
      op_finished_comb <= '1';
      next_state  <= S_IDLE;
  end case;
  
end process;

end architecture;
