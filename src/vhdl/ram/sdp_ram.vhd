library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdp_ram is
  generic(
    G_DATA_WIDTH  : positive := 16;
    G_ADDR_WIDTH  : positive := 3
  );
  port (
    -- Port A
    clk_a     : in  std_logic;
    clk_en_a  : in  std_logic;
    addr_a    : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    din_a     : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);

    -- Port B
    clk_b     : in  std_logic;
    clk_en_b  : in  std_logic;
    addr_b    : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    dout_b    : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of sdp_ram is

  type t_mem_type is array ((2**G_ADDR_WIDTH)-1 downto 0) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal r_memory : t_mem_type := (others=>(others=>'0'));

begin

  port_a : process(clk_a)
  begin
    if rising_edge(clk_a) then
      if clk_en_a = '1' then
        r_memory(to_integer(unsigned(addr_a))) <= din_a;
      end if;
    end if;
  end process;

  port_b : process(clk_b)
  begin
    if rising_edge(clk_b) then
      if clk_en_b = '1' then
        dout_b <= r_memory(to_integer(unsigned(addr_b)));
      end if;
    end if;
  end process;

end architecture;
