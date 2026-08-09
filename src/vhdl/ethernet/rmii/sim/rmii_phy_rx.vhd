
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
use vunit_lib.print_pkg.all;
use vunit_lib.logger_pkg.all;
context vunit_lib.vunit_context;

use work.utils.all;

entity rmii_phy_rx is
  port (
    clk50               : in std_logic;
    reset               : in std_logic;
    --------------------------------------------------------
    tx_en               : in std_logic;
    txd                 : in std_logic_vector(1 downto 0);
    --------------------------------------------------------
    payload_data_out    : out std_logic_vector(7 downto 0);
    payload_valid_out   : out std_logic
  );
end entity rmii_phy_rx;

architecture sim of rmii_phy_rx is

  constant C_PREAMBLE_BYTE : std_logic_vector(7 downto 0) := x"55";
  constant C_SFD_BYTE      : std_logic_vector(7 downto 0) := x"D5";

  type fsm_state_t is (S_IDLE,
                      S_PREAMBLE,
                      S_SFD,
                      S_DATA,
                      S_IPG
                      );

  signal tx_en_r        : std_logic := '0';
  
  signal rx_byte_last   : std_logic := '0';
  signal rx_byte_valid  : std_logic := '0';
  signal rx_shift_reg   : std_logic_vector(7 downto 0);
  signal rx_index       : natural := 0;

begin

  process(clk50)
  begin
    if rising_edge(clk50) then

      tx_en_r <= tx_en;

      rx_byte_valid <= '0';
      rx_byte_last  <= '0';

      if tx_en = '1' then
        rx_shift_reg((2*(rx_index+1))-1 downto (2*rx_index)) <= txd;
        rx_index <= rx_index + 1;
        if rx_index = 3 then
          rx_index <= 0;
          rx_byte_valid <= '1';
        end if;
      end if;

      if tx_en_r = '1' and tx_en = '0' then
        rx_byte_last  <= '1';
      end if;

      if reset = '1' then
        rx_index      <= 0;
        rx_shift_reg  <= (others => '0');
        rx_byte_valid <= '0';
        rx_byte_last  <= '0';
      end if;
    end if;
  end process;


process
  variable rx_state       : fsm_state_t := S_IDLE;
  variable counter        : natural := 0;
begin

  payload_data_out  <= (others => '0');
  payload_valid_out <= '0';

  while reset /= '1' loop

    case rx_state is
      when S_IDLE =>
        wait until rising_edge(clk50) and rx_byte_valid = '1';
        info("Preamble start");
        rx_state := S_PREAMBLE;
        counter := 1;
        check_equal(rx_shift_reg, C_PREAMBLE_BYTE, "Expected preamble byte");
      when S_PREAMBLE =>
        wait until rising_edge(clk50) and rx_byte_valid = '1';
        check_equal(rx_shift_reg, C_PREAMBLE_BYTE, "Expected preamble byte");
        counter := counter + 1;
        if counter = 7 then
          rx_state := S_SFD;
        end if;

      when S_SFD =>
        wait until rising_edge(clk50) and rx_byte_valid = '1';
        info("SFD");
        check_equal(rx_shift_reg, C_SFD_BYTE, "Expected SFD byte");
        rx_state := S_DATA;

      when S_DATA =>
        wait until rising_edge(clk50) and rx_byte_valid = '1';
        payload_data_out  <= rx_shift_reg;
        payload_valid_out <= '1';
        wait until rising_edge(clk50);
        payload_valid_out <= '0';
        if rx_byte_last = '1' then
          info("Last data");
          rx_state := S_IPG;
        end if;

      when S_IPG =>
        wait until rising_edge(clk50);
        payload_valid_out <= '0';
        for i in 0 to 46 loop
          check_equal(rx_byte_valid, '0', "No data should be recieved during IPG");
          wait_clk(clk50, 1);
        end loop;
        info("IPG DONE");

        rx_state := S_IDLE;

    end case;
  end loop;

  rx_state := S_IDLE;
  payload_data_out  <= (others => '0');
  payload_valid_out <= '0';
  wait_clk(clk50, 1);

end process;

end architecture;
