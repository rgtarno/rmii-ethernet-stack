library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity grey_pointer_sync is
  generic(
    G_ADDR_WIDTH  : positive := 3
  );
  port (
    clk       : in  std_logic;
    reset     : in std_logic;
    --------------------------------------------------------
    din       : in std_logic_vector(G_ADDR_WIDTH downto 0);
    --------------------------------------------------------
    dout      : out std_logic_vector(G_ADDR_WIDTH downto 0)
  );
end entity;

architecture rtl of grey_pointer_sync is

  signal din_r  : std_logic_vector(G_ADDR_WIDTH downto 0) := (others => '0');
  signal din_r2 : std_logic_vector(G_ADDR_WIDTH downto 0) := (others => '0');

  attribute ASYNC_REG     : string;
  attribute ASYNC_REG of din_r     : signal is "TRUE";
  attribute ASYNC_REG of din_r2    : signal is "TRUE";

begin

process(clk)
begin
  if rising_edge(clk) then
    if reset = '1' then
      din_r   <= (others => '0');
      din_r2  <= (others => '0');
    else
      din_r   <= din;
      din_r2  <= din_r;
    end if;
  end if;
end process;

dout <= din_r2;

end architecture;