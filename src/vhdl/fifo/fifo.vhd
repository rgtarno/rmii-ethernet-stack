library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity fifo is
  generic (
    G_DATA_WIDTH              : natural := 8;
    G_LOG2_DEPTH              : natural := 2;
    G_RAM_STYLE               : string := "auto"
  );
  port (
    clk              : in std_logic;
    sreset           : in std_logic;
    --------------------------------------------------
    write_data       : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    write_en         : in  std_logic;
    full             : out std_logic;
    --------------------------------------------------
    read_data        : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    read_en          : in  std_logic;
    empty            : out std_logic
  );
end entity fifo;

architecture rtl of fifo is

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  constant C_NUM_ROWS : natural := pow_2(G_LOG2_DEPTH);

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type ram_t is array(0 to C_NUM_ROWS-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);

  ----------------------------------------------------
  -- SIGNALS
  ---------------------------------------------------
  signal ram : ram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of ram : signal is G_RAM_STYLE;

  signal read_pointer   : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');
  signal write_pointer  : unsigned(G_LOG2_DEPTH-1 downto 0) := (others => '0');

  signal empty_sig      : std_logic;
  signal full_sig       : std_logic;

  signal data_out_r     : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal output_valid_r : std_logic := '0';
  signal fwft_read      : std_logic;


begin

  full      <= full_sig;
  empty_sig <= '1' when read_pointer = write_pointer else '0';
  full_sig  <= '1' when (write_pointer - read_pointer) = to_unsigned(C_NUM_ROWS-1, G_LOG2_DEPTH) else '0';

  p_write : process (clk)
  begin
    if rising_edge(clk) then

      if write_en = '1' and full_sig = '0' then
        write_pointer                 <= write_pointer + 1;
        ram(to_integer(write_pointer)) <= write_data;
      end if;

      if sreset = '1' then
        write_pointer <= (others => '0');
      end if;

    end if;
  end process;


  p_read : process (clk)
  begin
    if rising_edge(clk) then

      if fwft_read = '1' and empty_sig = '0' then
        read_pointer <= read_pointer + 1;
      end if;

      if sreset = '1' then
        read_pointer <= (others => '0');
      end if;

    end if;
  end process;

  p_fwft : process(clk)
  begin
    if rising_edge(clk) then
      if fwft_read = '1' then
        data_out_r     <= ram(to_integer(read_pointer));
        output_valid_r <= not empty_sig;
      end if;

      if sreset = '1' then
        output_valid_r <= '0';
      end if;

    end if;    
  end process;

  fwft_read <= read_en or not output_valid_r;
  empty     <= not output_valid_r;
  read_data <= data_out_r;

end architecture;