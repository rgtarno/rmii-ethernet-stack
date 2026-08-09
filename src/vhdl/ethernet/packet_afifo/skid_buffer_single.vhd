library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

entity skid_buffer_single is
  generic (
    G_DATA_WIDTH          : natural
  );
  port (
    clk            : in std_logic;
    reset          : in std_logic;
    --------------------------------------------------------
    data_in        : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    valid_in       : in std_logic;
    ready_out      : out std_logic;
    --------------------------------------------------------
    data_out       : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    valid_out      : out std_logic;
    ready_in       : in  std_logic
  );
end entity skid_buffer_single;


architecture rtl of skid_buffer_single is

  signal upstream_ready             : std_logic := '0';
  signal downstream_ready           : std_logic := '0';

  signal expansion_data_r          : std_logic_vector(G_DATA_WIDTH-1 downto 0);
  signal expansion_valid_r         : std_logic := '0';

begin

  ready_out <= upstream_ready;

  -- We are ready to receive when the expansion reg is empty
  upstream_ready   <= not expansion_valid_r;

  process(clk)
  begin
    if rising_edge(clk) then

      if downstream_ready = '1' then
        expansion_valid_r <= '0';
      else
        -- Downstream stall: Catch data in expansion reg. Upstream ready will be dropped
        if valid_in = '1' and expansion_valid_r = '0' then
          expansion_data_r   <= data_in;
          expansion_valid_r  <= valid_in;
        end if;

      end if;

  
      if reset = '1' then
        expansion_valid_r <= '0';
        expansion_data_r  <= (others => '0');
      end if;
    end if;
  end process;

  downstream_ready <= ready_in;

  -- Outputs comb assignments
  data_out    <= expansion_data_r when expansion_valid_r = '1' else data_in;
  valid_out   <= expansion_valid_r or valid_in;

end architecture;