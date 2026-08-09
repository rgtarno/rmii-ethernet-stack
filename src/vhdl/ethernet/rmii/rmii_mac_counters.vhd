library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity rmii_mac_counters is
  port (
    clk                       : in std_logic;
    reset                     : in std_logic;
    --------------------------------------------------------
    tx_data_tvalid            : in std_logic;
    tx_data_tlast             : in std_logic;
    tx_data_tready            : in std_logic;
    --------------------------------------------------------
    rx_data_tvalid            : in std_logic;
    rx_data_tlast             : in std_logic;
    rx_bad_carrier            : in std_logic;
    --------------------------------------------------------
    num_tx_bytes              : out std_logic_vector(31 downto 0);
    num_tx_packets            : out std_logic_vector(31 downto 0);
    num_rx_bytes              : out std_logic_vector(31 downto 0);
    num_rx_packets            : out std_logic_vector(31 downto 0);
    num_rx_bad_carrier_events : out std_logic_vector(7 downto 0)
  );
end entity rmii_mac_counters;


architecture rtl of rmii_mac_counters is

  signal tx_bytes_counter_u        : unsigned(31 downto 0) := (others => '0');
  signal tx_packets_counter_u      : unsigned(31 downto 0) := (others => '0');

  signal rx_bytes_counter_u        : unsigned(31 downto 0) := (others => '0');
  signal rx_packets_counter_u      : unsigned(31 downto 0) := (others => '0');
  signal rx_bad_carrier_counter_u  : unsigned(7 downto 0) := (others => '0');

begin


  ----------------------------------------------------
  -- TRANSMIT COUNTERS
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if tx_data_tvalid = '1' and tx_data_tready = '1' then
        tx_bytes_counter_u <= tx_bytes_counter_u + 1;

        if tx_data_tlast = '1' then
          tx_packets_counter_u <= tx_packets_counter_u + 1;
        end if;
      end if;

      if reset = '1' then
        tx_bytes_counter_u    <= (others => '0');
        tx_packets_counter_u  <= (others => '0');
      end if;
    end if;
  end process;

  num_tx_bytes    <= std_logic_vector(tx_bytes_counter_u);
  num_tx_packets  <= std_logic_vector(tx_packets_counter_u);

  ----------------------------------------------------
  -- RECEIVE COUNTERS
  ----------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rx_data_tvalid = '1' then
        rx_bytes_counter_u <= rx_bytes_counter_u + 1;

        if rx_data_tlast = '1' then
          rx_packets_counter_u <= rx_packets_counter_u + 1;
        end if;
      end if;

      if rx_bad_carrier = '1' then
        rx_bad_carrier_counter_u <= rx_bad_carrier_counter_u + 1;
      end if;

      if reset = '1' then
        rx_bytes_counter_u        <= (others => '0');
        rx_packets_counter_u      <= (others => '0');
        rx_bad_carrier_counter_u  <= (others => '0');
      end if;
    end if;
  end process;

  num_rx_bytes              <= std_logic_vector(rx_bytes_counter_u);
  num_rx_packets            <= std_logic_vector(rx_packets_counter_u);
  num_rx_bad_carrier_events <= std_logic_vector(rx_bad_carrier_counter_u);

end architecture;