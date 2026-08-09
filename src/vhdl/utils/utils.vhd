library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

package utils is 

  type slv32_array_t is array (natural range <>) of std_logic_vector(31 downto 0);

  function log2_ceil(v : natural) return natural;
  function pow_2(v :  natural) return natural;
  function popcount(vec :  std_logic_vector) return natural;

  function extend(vec :  std_logic_vector; len : natural) return std_logic_vector;
  function extend_unsigned(n :  unsigned; len : natural) return unsigned;
  function reverse_slv(slv: std_logic_vector) return std_logic_vector;
  function pad_slv32(vec: std_logic_vector) return std_logic_vector;

  function add_saturate(a: unsigned; b: unsigned) return unsigned;

  -- Simulation only
  procedure wait_clk(signal clk : in std_logic; num_edges : natural);

end package utils;

package body utils is

  function log2_ceil(v : natural) return natural is
    variable i : natural := 0;
  begin
    while 2**i < v loop
      i := i + 1;
    end loop;
    return i;
  end function;

  function pow_2(v :  natural) return natural is
  begin
    return integer(2.0**real(v));
  end function;

  function extend_unsigned(n :  unsigned; len : natural) return unsigned is
  begin
    return unsigned(extend(std_logic_vector(n), len));
  end function;

  function extend(vec :  std_logic_vector; len : natural) return std_logic_vector is
    variable ret : std_logic_vector(len-1 downto 0) := (others => '0');
  begin
    ret(vec'length-1 downto 0) := vec;
    ret(ret'length-1 downto vec'length) := (others => '0');
    return ret;
  end function;

  function popcount(vec :  std_logic_vector) return natural is
    variable ret : natural := 0;
  begin
    for i in vec'range loop
      if vec(i) = '1' then
        ret := ret + 1;
      end if;
    end loop;

    return ret;
  end function;

  function add_saturate(a: unsigned; b: unsigned) return unsigned is
    variable full_sum : unsigned(a'length downto 0) := (others => '0');
    variable result : unsigned(a'range) := (others => '0');
  begin
    full_sum := ("0" & a) + ("0" & b);
    if full_sum(a'length) = '1' then
      result := (others => '1');
    else
      result := full_sum(result'range);
    end if;

    return result;
  end function;

  procedure wait_clk(signal clk : in std_logic; num_edges : natural) is
  begin
    for i in 0 to num_edges-1 loop
      wait until rising_edge(clk);
    end loop;
  end procedure;


  function reverse_slv(slv: std_logic_vector) return std_logic_vector is
    variable result: std_logic_vector(slv'reverse_range);
  begin
    for i in slv'range loop
        result(i) := slv(i);
    end loop;
    return result;
  end function;

  function pad_slv32(vec: std_logic_vector) return std_logic_vector is
    variable ret : std_logic_vector(31 downto 0) := (others => '0');
  begin
    ret(vec'length-1 downto 0) := vec;
    ret(ret'length-1 downto vec'length) := (others => '0');
    return ret;
  end function;


end package body;