library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity circular_buffer is
  generic (
    G_DATA_WIDTH              : natural := 8;
    G_LOG2_DEPTH              : natural := 2
  );
  port (
    clk              : in std_logic;
    sreset           : in std_logic;
    --------------------------------------------------
    write_data       : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    write_en         : in  std_logic;
    full             : out std_logic;
    used             : out std_logic_vector(G_LOG2_DEPTH-1 downto 0);
    --------------------------------------------------
    read_data        : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    read_en          : in  std_logic;
    empty            : out std_logic
  );
end entity circular_buffer;

architecture rtl of circular_buffer is

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  constant C_NUM_ROWS : natural := pow_2(G_LOG2_DEPTH);

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type buffer_t is array(0 to C_NUM_ROWS-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);

  ----------------------------------------------------
  -- SIGNALS
  ---------------------------------------------------
  signal buffers : buffer_t := (others => (others => '0'));

  signal read_pointer          : unsigned(G_LOG2_DEPTH downto 0) := (others => '0');
  signal write_pointer         : unsigned(G_LOG2_DEPTH downto 0) := (others => '0');
  signal read_address          : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');
  signal write_address         : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');

  signal empty_sig      : std_logic;
  signal full_sig       : std_logic;

begin

  full      <= full_sig;

  read_address  <= read_pointer(G_LOG2_DEPTH-1 downto 0);
  write_address <= write_pointer(G_LOG2_DEPTH-1 downto 0);

  empty_sig <= '1' when write_pointer = read_pointer else '0';
  full_sig <= '1'  when (read_address = write_address) and (read_pointer(G_LOG2_DEPTH) /= write_pointer(G_LOG2_DEPTH)) else '0';

  used <= std_logic_vector(write_address - read_address);

  p_write : process (clk)
  begin
    if rising_edge(clk) then

      if write_en = '1' then
        write_pointer                      <= write_pointer + 1;
        buffers(to_integer(write_address)) <= write_data;
      end if;

      if sreset = '1' then
        write_pointer <= (others => '0');
      end if;

    end if;
  end process;


  p_read : process (clk)
  begin
    if rising_edge(clk) then

      if read_en = '1' and empty_sig = '0' then
        read_pointer <= read_pointer + 1;
      end if;

      if sreset = '1' then
        read_pointer <= (others => '0');
      end if;

    end if;
  end process;



  empty     <= empty_sig;
  read_data <= buffers(to_integer(read_address));

end architecture;