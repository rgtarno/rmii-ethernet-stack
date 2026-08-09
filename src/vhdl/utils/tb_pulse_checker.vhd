library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_pulse_checker is
  port (
    clk              : in std_logic;
    reset            : in std_logic;
    --------------------------------------------------
    pulse_in         : in std_logic
  );
end entity tb_pulse_checker;

architecture sim of tb_pulse_checker is

  signal pulse_in_r : std_logic;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '0' then
        pulse_in_r <= pulse_in;
      end if;
    end if;
  end process;

  process
  begin
    wait until rising_edge(clk);
    if reset = '0' then
      check(not (pulse_in_r = '1' and pulse_in = '1'), "Input is high for multiple clock cycles");
    end if;

  end process;

  

end architecture;