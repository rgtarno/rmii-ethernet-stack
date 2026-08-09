library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pulse_counter is
  port (
    clk              : in std_logic;
    reset            : in std_logic;
    --------------------------------------------------
    enable_in        : in std_logic;
    --------------------------------------------------
    count_out        : out std_logic_vector
  );
end entity pulse_counter;

architecture sim of pulse_counter is

  signal counter : unsigned(count_out'range) := (others => '0');

begin

  count_out <= std_logic_vector(counter);

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        counter <= (others => '0');
      else
        if enable_in = '1' then
          counter <= counter + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;