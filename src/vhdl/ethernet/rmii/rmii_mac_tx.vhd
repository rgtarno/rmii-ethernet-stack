library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

-- NOTE: In Ethernet, within each octet the least significant bit is transmitted first.
-- In the RMII Spec http://ebook.pldworld.com/_eBook/-Telecommunications,Networks-/TCPIP/RMII/rmii_rev12.pdf
-- txd[0] is the least significant bit of the dibit

entity rmii_mac_tx is
  port (
    clk50               : in std_logic;
    reset               : in std_logic;
    --------------------------------------------------------
    s_axis_tdata        : in std_logic_vector(7 downto 0);
    s_axis_tvalid       : in std_logic;
    s_axis_tlast        : in std_logic;
    s_axis_tready       : out std_logic;
    --------------------------------------------------------
    tx_en               : out std_logic;
    txd                 : out std_logic_vector(1 downto 0)
  );
end entity rmii_mac_tx;

architecture rtl of rmii_mac_tx is

  ----------------------------------------------------
  -- CONSTANTS
  ----------------------------------------------------
  constant C_COUNTER_BITS_N           : natural := 12;
  constant C_PREAMBLE_LENGTH_DIBITS_N : natural := 31; -- (7 * 8 / 2) + 2. 7 bytes of 0x55 then 0xD5 --> 31 di bits of 10 then 11
  constant C_PREAMBLE_LENGTH_DIBITS_U : unsigned(C_COUNTER_BITS_N-1 downto 0) := to_unsigned(C_PREAMBLE_LENGTH_DIBITS_N, C_COUNTER_BITS_N);
  constant C_IPG_LENGTH_N             : natural := 56; -- IPG is 0.96us --> 48 50MHz periods, add on extra for safety
  constant C_IPG_LENGTH_U             : unsigned(C_COUNTER_BITS_N-1 downto 0) := to_unsigned(C_IPG_LENGTH_N, C_COUNTER_BITS_N);


  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_IDLE,
                       S_PREAMBLE,
                       S_SFD,
                       S_DATA,
                       S_IPG
                       );
  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal di_bit_select  : unsigned(1 downto 0);
  signal cycle_counter  : unsigned(C_COUNTER_BITS_N-1 downto 0);

  signal fsm_state : fsm_state_t := S_IDLE;

begin

process(clk50)
begin
  if rising_edge(clk50) then
    tx_en <= '0';
    txd   <= "00";

    s_axis_tready <= '0';

    cycle_counter <= cycle_counter - 1;

    case fsm_state is

      when S_IDLE =>

        if s_axis_tvalid = '1' then
          fsm_state     <= S_PREAMBLE;
          cycle_counter <= C_PREAMBLE_LENGTH_DIBITS_U-1;
          di_bit_select <= (others => '0');
        end if;

      when S_PREAMBLE =>

        tx_en <= '1';
        txd   <= "01";
        if cycle_counter = (cycle_counter'range => '0') then
          fsm_state     <= S_SFD;
        end if;

      when S_SFD =>
        tx_en     <= '1';
        txd       <= "11";
        fsm_state <= S_DATA;

      when S_DATA =>
        di_bit_select <= di_bit_select + 1;
        tx_en     <= '1';

        if di_bit_select = "10" then
          s_axis_tready <= '1';
        end if;

        if s_axis_tlast = '1' and di_bit_select = "11" then
          fsm_state     <= S_IPG;
          cycle_counter <= C_IPG_LENGTH_U;
        end if;

        case di_bit_select is
          when "00" =>
            txd <= s_axis_tdata(1 downto 0);
          when "01" =>
            txd <= s_axis_tdata(3 downto 2);
          when "10" =>
            txd <= s_axis_tdata(5 downto 4);
          when "11" =>
            txd <= s_axis_tdata(7 downto 6);
          when others =>
            null;
        end case;

      when S_IPG =>
        tx_en     <= '0';
        if cycle_counter = (cycle_counter'range => '0') then
          fsm_state     <= S_IDLE;
        end if;

    end case;

    if reset = '1' then
      fsm_state     <= S_IDLE;
      tx_en         <= '0';
      txd           <= (others => '0');
      di_bit_select <= (others => '0');
    end if;

  end if;
end process;

end architecture;