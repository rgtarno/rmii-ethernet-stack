library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo_fwft is
  generic (
    G_DATA_WIDTH     : natural := 8
  );
  port (
    rd_clk           : in std_logic;
    reset            : in std_logic;
    fifo_q           : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    data_out         : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    read_en_in       : in  std_logic;
    fifo_read_en_out : out  std_logic;
    fifo_empty_in    : in std_logic;
    empty_out        : out std_logic
  );
end entity fifo_fwft;

architecture rtl of fifo_fwft is
  signal fifo_read_en_sig : std_logic;

  signal fifo_valid     : std_logic := '0';
  signal buffer_valid   : std_logic := '0';
  signal output_valid   : std_logic := '0';

  signal update_buffer  : std_logic;
  signal update_output  : std_logic;

  signal buffer_r       : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal output_r       : std_logic_vector(G_DATA_WIDTH-1 downto 0);

begin

  update_buffer <= '1' when fifo_valid = '1' and (buffer_valid = update_output) else '0';
  update_output <= '1' when (buffer_valid = '1' or fifo_valid = '1') and (read_en_in = '1' or output_valid = '0') else '0';

  fifo_read_en_sig <= '0' when reset = '1' else
                      not fifo_empty_in and not(fifo_valid and buffer_valid and output_valid);
  fifo_read_en_out <= fifo_read_en_sig;

  empty_out <= not output_valid;
  data_out  <= output_r;


process(rd_clk)
begin
  if rising_edge(rd_clk) then

    if reset = '1' then
      fifo_valid    <= '0';
      buffer_valid  <= '0';
      output_valid  <= '0';
      buffer_r      <= (others => '0');
      output_r      <= (others => '0');
    else

      if update_buffer = '1' then
        buffer_r <= fifo_q;
      end if;

      if update_output = '1' then
        if buffer_valid = '1' then
          output_r <= buffer_r;
        else
          output_r <= fifo_q;
        end if;
      end if;

      if fifo_read_en_sig = '1' then
        fifo_valid <= '1';
      elsif update_buffer = '1' or update_output = '1' then
          fifo_valid <= '0';
      end if;

      if update_buffer = '1' then
        buffer_valid <= '1';
      elsif update_output = '1' then
        buffer_valid <= '0';
      end if;

      if update_output = '1' then
        output_valid <= '1';
      elsif read_en_in = '1' then
        output_valid <= '0';
      end if;

    end if;

  end if;
end process;

end architecture;