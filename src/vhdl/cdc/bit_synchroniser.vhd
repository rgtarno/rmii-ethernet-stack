library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bit_synchroniser is
  generic (
    G_NUM_STAGES        : natural := 2
  );
  port (
    clk                : in std_logic;
    async_in           : in std_logic;
    sync_out           : out std_logic
  );
end entity bit_synchroniser;

architecture rtl of bit_synchroniser is

  signal ffs  : std_logic_vector(G_NUM_STAGES-1 downto 0) := (others => '0');

  attribute SHREG_EXTRACT : string;
  attribute ASYNC_REG     : string;
  attribute SHREG_EXTRACT of ffs : signal is "no";
  attribute ASYNC_REG of ffs     : signal is "TRUE";

begin

  process(clk)
  begin
    if rising_edge(clk) then
      ffs(G_NUM_STAGES-1 downto 0) <= ffs(G_NUM_STAGES-2 downto 0) & async_in;
    end if;
  end process;

  sync_out <= ffs(G_NUM_STAGES-1);

end architecture;