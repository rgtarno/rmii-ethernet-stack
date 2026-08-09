library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity afifo_read_logic is
  generic (
    G_DATA_WIDTH     : natural;
    G_ADDR_WIDTH     : natural
  );
  port (
    rd_clk              : in std_logic;
    reset               : in std_logic;
    read_en_in          : in  std_logic;
    empty_out           : out std_logic;
    write_pointer_in    : in std_logic_vector(G_ADDR_WIDTH downto 0);
    read_addr_out       : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    read_pointer_out    : out std_logic_vector(G_ADDR_WIDTH downto 0)
  );
end entity afifo_read_logic;

architecture rtl of afifo_read_logic is

  signal empty_sig           : std_logic;
  signal empty_r             : std_logic := '1';

  signal read_addr_r         : unsigned(G_ADDR_WIDTH downto 0) := (others => '0');
  signal read_addr_next      : unsigned(G_ADDR_WIDTH downto 0) := (others => '0');
  signal read_pointer_r      : std_logic_vector(G_ADDR_WIDTH downto 0) := (others => '0');
  signal read_pointer_next   : std_logic_vector(G_ADDR_WIDTH downto 0) := (others => '0');

begin


  ----------------------------------------------------
  -- Generate empty signal and register
  ----------------------------------------------------

  -- Empty when the read and synchronised write pointers are equal
  empty_sig <= '1' when read_pointer_next = write_pointer_in else '0';

  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
      empty_r <= empty_sig;
      if reset = '1' then
        empty_r <= '1';
      end if;
    end if;
  end process;
  
  empty_out        <= empty_r;
  -- empty_out        <= empty_sig;

  ----------------------------------------------------
  -- Read address 
  ----------------------------------------------------
  -- Binary counter is used to access the RAM
  read_addr_next <= read_addr_r + 1 when (empty_r = '0' and read_en_in = '1') else
                    read_addr_r;
  
  -- Gray counter is sent to write side
  read_pointer_next <= std_logic_vector(shift_right(read_addr_next, 1)) xor std_logic_vector(read_addr_next);

  process(rd_clk)
  begin
    if rising_edge(rd_clk) then
        read_addr_r     <= read_addr_next;
        read_pointer_r  <= read_pointer_next;

      if reset = '1' then
        read_addr_r     <= (others => '0');
        read_pointer_r  <= (others => '0');
      end if;
    end if;
  end process;

  read_pointer_out <= read_pointer_r;
  read_addr_out    <= std_logic_vector(read_addr_r(G_ADDR_WIDTH-1 downto 0));

end architecture;