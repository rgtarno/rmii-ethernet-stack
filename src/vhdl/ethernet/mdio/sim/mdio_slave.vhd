
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
use vunit_lib.print_pkg.all;
use vunit_lib.logger_pkg.all;
context vunit_lib.vunit_context;

use work.utils.all;
use work.mdio_slave_pkg.all;

entity mdio_slave is
  generic (
    G_NUM_REGS    : natural
  );
  port (
    mdc                   : in std_logic;
    mdio                  : inout std_logic;
    --------------------------------------------------
    reset                 : in std_logic;
    expected_phy_address  : in std_logic_vector(4 downto 0);
    --------------------------------------------------
    data_read_regs_in     : in data_array_t(G_NUM_REGS-1 downto 0);
    reg_write_en          : out std_logic_vector(G_NUM_REGS-1 downto 0);
    data_write_regs_out   : out data_array_t(G_NUM_REGS-1 downto 0) := (others => (others => '0'))
  );
end entity mdio_slave;

architecture sim of mdio_slave is

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal mdio_rx_data : std_logic;
  signal mdio_tx_data : std_logic;
  signal mdio_tx_en   : std_logic := '0';

  signal number_of_consecutive_ones : natural := 0;

begin

process(mdc)
begin
  if rising_edge(mdc) then
    if mdio = '1' then
      number_of_consecutive_ones <= number_of_consecutive_ones + 1;
    else
      number_of_consecutive_ones <= 0;
    end if;

    if reset = '1' then
      number_of_consecutive_ones <= 0;
    end if;
  end if;
end process;


  mdio <= mdio_tx_data when mdio_tx_en = '1' else 'Z';
  mdio_rx_data <= mdio;

process
  variable is_read       : natural := 0;
  variable bit_counter_v : natural := 0;
  variable phy_address_v : std_logic_vector(4 downto 0);
  variable reg_address_v : std_logic_vector(4 downto 0);
begin
    reg_write_en <= (others => '0');
    mdio_tx_en <= '0';
    phy_address_v := (others => '0');
    reg_address_v := (others => '0');
    bit_counter_v := 0;

    -- Start bit 1
    wait until rising_edge(mdc) and mdio_rx_data = '0';
    if number_of_consecutive_ones < 32 then
      failure("No preamble");
    end if;
    -- Start bit 2
    wait until rising_edge(mdc) and mdio_rx_data = '1';

    -- Op 1
    wait until rising_edge(mdc);
    -- Op 2
    wait until rising_edge(mdc);
    if mdio_rx_data = '0' then
      info("Read OP");
      is_read := 1;
    else
      info("Write OP");
      is_read := 0;
    end if;

    -- PHY addr
    bit_counter_v := 0;
    while bit_counter_v < 5 loop
      wait until rising_edge(mdc);
      phy_address_v(4-bit_counter_v) := mdio_rx_data;
      bit_counter_v := bit_counter_v + 1;
    end loop;
    info("PHY addr = " & to_hstring(phy_address_v));
    check_equal(phy_address_v, expected_phy_address, "PHY address doesn't match");

    -- REG addr
    bit_counter_v := 0;
    while bit_counter_v < 5 loop
      wait until rising_edge(mdc);
      reg_address_v(4-bit_counter_v) := mdio_rx_data;
      bit_counter_v := bit_counter_v + 1;
    end loop;
    info("REG addr = " & to_hstring(reg_address_v));

    -- TA 1
    wait until rising_edge(mdc);
    if is_read = 0 then
      check_equal(mdio_rx_data, '1');
    end if;
    -- TA 2
    wait until rising_edge(mdc);
    if is_read = 0 then
      check_equal(mdio_rx_data, '0');
    end if;

    bit_counter_v := 0;
    if is_read = 1 then
      while bit_counter_v < 16 loop
        wait for 300 ns; -- MDIO spec says this is how long it is after rising edge when PHY's data is valid
        mdio_tx_en <= '1';
        mdio_tx_data <= data_read_regs_in(to_integer(unsigned(reg_address_v)))(15-bit_counter_v);
        info("Output bit = " & std_logic'Image(data_read_regs_in(to_integer(unsigned(reg_address_v)))(15-bit_counter_v)));
        bit_counter_v := bit_counter_v + 1;
        wait until rising_edge(mdc);
      end loop;
    else
      while bit_counter_v < 16 loop
        wait until rising_edge(mdc);
        data_write_regs_out(to_integer(unsigned(reg_address_v)))(15-bit_counter_v) <= mdio_rx_data;
        info("Input bit = " & std_logic'Image(mdio_rx_data));
        bit_counter_v := bit_counter_v + 1;
      end loop;
      reg_write_en(to_integer(unsigned(reg_address_v))) <= '1';
    end if;

    wait until rising_edge(mdc);
end process;

end architecture;
