library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package mdio_slave_pkg is 
  type data_array_t is array(natural range <>) of std_logic_vector(15 downto 0);
end package;