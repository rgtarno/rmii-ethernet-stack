library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity afifo_write_logic is
  generic (
    G_DATA_WIDTH     : natural;
    G_ADDR_WIDTH     : natural
  );
  port (
    wr_clk              : in std_logic;
    reset               : in std_logic;
    write_en_in         : in  std_logic;
    full_out            : out std_logic;
    read_pointer_in     : in std_logic_vector(G_ADDR_WIDTH downto 0);
    write_addr_out      : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    write_pointer_out   : out std_logic_vector(G_ADDR_WIDTH downto 0)
  );
end entity afifo_write_logic;

architecture rtl of afifo_write_logic is

  signal full_sig           : std_logic := '0';
  signal full_r             : std_logic := '0';

  signal write_addr_r       : unsigned(G_ADDR_WIDTH downto 0) := (others => '0');
  signal write_addr_next    : unsigned(G_ADDR_WIDTH downto 0) := (others => '0');
  signal write_pointer_r    : std_logic_vector(G_ADDR_WIDTH downto 0) := (others =>'0');
  signal write_pointer_next : std_logic_vector(G_ADDR_WIDTH downto 0) := (others =>'0');

begin

  ----------------------------------------------------
  -- Generate full signal
  -- See http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf p11
  -- The top bits must be different:
  --  Top bit: Tells us if we have wrapped. If the write pointer has wrapped and the read pointer hasn't (MSB different, all other bits equal),
  --           that means we have "caught up with" the read pointer and are full
  --  2nd top bit : The gray code counter is symetrical about its midpoint for bits below the MSB. As the gray code counter has 1 more bit
  --                 than the binary counter we use to address the ram. Across the 4 bit counters midpoint, the 3 LSBs don't change. 
  ----------------------------------------------------
  process(write_pointer_next, read_pointer_in)
  begin
    full_sig <= '0';
    if write_pointer_next(G_ADDR_WIDTH) /= read_pointer_in(G_ADDR_WIDTH) then
      if write_pointer_next(G_ADDR_WIDTH-1) /= read_pointer_in(G_ADDR_WIDTH-1) then
        if write_pointer_next(G_ADDR_WIDTH-2 downto 0) = read_pointer_in(G_ADDR_WIDTH-2 downto 0) then
          full_sig <= '1';
        end if;
      end if;
    end if;
  end process;

  process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      full_r <= full_sig;
      if reset = '1' then
        full_r <= '0';
      end if;
    end if;
  end process;

  full_out        <= full_r;

  ----------------------------------------------------
  -- Write address 
  ----------------------------------------------------
  -- Binary counter is used to access the RAM
  write_addr_next <= write_addr_r + 1 when (full_r = '0' and write_en_in = '1') else
                     write_addr_r;
  
  -- Gray counter is sent to write side
  write_pointer_next <= std_logic_vector(shift_right(write_addr_next, 1)) xor std_logic_vector(write_addr_next);

  process(wr_clk)
  begin
    if rising_edge(wr_clk) then
      write_addr_r     <= write_addr_next;
      write_pointer_r  <= write_pointer_next;

      if reset = '1' then
        write_addr_r      <= (others => '0');
        write_pointer_r   <= (others => '0');
      end if;
    end if;
  end process;

  write_addr_out    <= std_logic_vector(write_addr_r(G_ADDR_WIDTH-1 downto 0));
  write_pointer_out <= write_pointer_r;

end architecture;