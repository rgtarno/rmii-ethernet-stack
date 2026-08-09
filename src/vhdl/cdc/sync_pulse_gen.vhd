library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Generates a pulse when an input changes polarity
-- Based on the sunburst design paper http://www.sunburst-design.com/papers/CummingsSNUG2008Boston_CDC.pdf
-- Section 5.6.1 "MCP formulation using a synchronized enable pulse"

entity sync_pulse_gen is
  port (
    clk         : in std_logic;
    din         : in std_logic;
    dout        : out std_logic;
    pulse       : out std_logic
  );
end entity sync_pulse_gen;

architecture rtl of sync_pulse_gen is

  signal q1 : std_logic := '0';
  signal q2 : std_logic := '0';
  signal q3 : std_logic := '0';

begin

process(clk)
begin
  if rising_edge(clk) then
    q1 <= din;
    q2 <= q1;
    q3 <= q2;
  end if;
end process;

pulse <= q2 xor q3;
dout  <= q3;

end architecture;