library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pulse_transfer is
  port (
    clk_a              : in std_logic;
    clk_b              : in std_logic;
    a_pulse_in         : in std_logic;
    a_ready_out        : out std_logic;

    b_pulse_out        : out std_logic
  );
end entity pulse_transfer;


architecture rtl of pulse_transfer is

  constant C_NUM_B_FF     : natural := 3;

  signal a_pulse_r        : std_logic := '0';
  signal ack_r            : std_logic := '0';

  signal b_ff             : std_logic_vector(C_NUM_B_FF-1 downto 0) := (others => '0');
  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of b_ff : signal is "no";

begin

  a_ready_out <= not (ack_r or a_pulse_r);

  process(clk_a)
  begin
    if rising_edge(clk_a) then
      
      if a_pulse_in = '1' then
        a_pulse_r <= '1';
      elsif ack_r = '1' then
        a_pulse_r <= '0';
      end if;

    end if;
  end process;

  i_ack_sync : entity work.bit_synchroniser
    generic map (
      G_NUM_STAGES        => 2
    )
    port map (
      clk                => clk_a,
      async_in           => b_ff(C_NUM_B_FF-2),
      sync_out           => ack_r
    );


  process(clk_b)
  begin
    if rising_edge(clk_b) then
      b_ff(C_NUM_B_FF-1 downto 0) <= b_ff(C_NUM_B_FF-2 downto 0) & a_pulse_r;
    end if;
  end process;

  b_pulse_out <= not b_ff(C_NUM_B_FF-1) and b_ff(C_NUM_B_FF-2);

end architecture;