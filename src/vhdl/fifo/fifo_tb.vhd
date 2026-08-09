library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.utils.all;

entity fifo_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of fifo_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 10 ns;
  constant C_DATA_WIDTH           : natural := 8;
  constant C_LOG2_DEPTH           : natural := 3;
  

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk              : std_logic := '0';
  signal reset            : std_logic := '0';

  signal write_data       : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal write_en         : std_logic := '0';
  signal full             : std_logic := '0';
  signal read_data        : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal read_en          : std_logic := '0';
  signal empty            : std_logic := '0';

begin

----------------------------------------
-- CLK generation
----------------------------------------
process
begin
  wait for CLKP/2;
  clk <= not clk;
end process;

----------------------------------------
-- Stim
----------------------------------------
main : process
  variable in_data : unsigned(C_DATA_WIDTH-1 downto 0) := (others => '0');
  variable out_data : unsigned(C_DATA_WIDTH-1 downto 0) := (others => '0');
  begin
    test_runner_setup(runner, runner_cfg);
    
    while test_suite loop

      read_en  <= '0';
      write_en <= '0';
      in_data  := (others => '0');
      
      reset <= '1';
      wait_clk(clk, 5);
      reset <= '0';
      wait_clk(clk, 5);

      if run("Continous write until full then continous read") then
        
        for i in 0 to pow_2(C_LOG2_DEPTH)-1 loop
          
          check_equal(full, '0', "FIFO should be not full whilst we are filling it up");
          in_data := in_data  + 1;
          write_data <= std_logic_vector(in_data);
          write_en   <= '1';
          wait_clk(clk, 1);

        end loop;

        write_en   <= '0';
        wait_clk(clk, 5);

        check_equal(full, '1', "FIFO should be full");
        check_equal(empty, '0', "FIFO should not be empty");

        wait_clk(clk, 5);
        
        in_data  := (others => '0');
        in_data  := in_data + 1;
        read_en   <= '1';

        for i in 0 to pow_2(C_LOG2_DEPTH)-1 loop
          wait_clk(clk, 1);
          check_equal(read_data, std_logic_vector(in_data), "Read wrong value");
          in_data  := in_data + 1;
        end loop;

        read_en   <= '0';
        wait_clk(clk, 1);

        check_equal(empty, '1', "FIFO should be empty");
        check_equal(full, '0', "FIFO should not be full");

        wait_clk(clk, 5);

      elsif run("Stagered write until full then stagered read") then

        for i in 0 to pow_2(C_LOG2_DEPTH)-1 loop
          
          check_equal(full, '0', "FIFO should be not full whilst we are filling it up");
          in_data := in_data  + 1;
          write_data <= std_logic_vector(in_data);
          write_en   <= '1';
          wait_clk(clk, 1);
          write_en   <= '0';
          wait_clk(clk, 1);

        end loop;

        write_en   <= '0';
        wait_clk(clk, 5);

        check_equal(full, '1', "FIFO should be full");
        check_equal(empty, '0', "FIFO should not be empty");

        wait_clk(clk, 5);
        
        in_data  := (others => '0');
        in_data  := in_data  + 1;
        read_en  <= '1';

        for i in 0 to pow_2(C_LOG2_DEPTH)-1 loop

          read_en  <= '1';
          wait_clk(clk, 1);
          check_equal(read_data, std_logic_vector(in_data), "Read wrong value");
          in_data := in_data  + 1;
          read_en   <= '0';
          wait_clk(clk, 1);

        end loop;

        check_equal(empty, '1', "FIFO should be empty");
        check_equal(full, '0', "FIFO should not be full");

      elsif run("Read from empty") then
        in_data := to_unsigned(1, in_data'length);
        out_data := to_unsigned(1, in_data'length);
        read_en  <= '1';
        write_en <= '1';
        write_data <= std_logic_vector(in_data);

        for i in 0 to 2*pow_2(C_LOG2_DEPTH) loop
          wait_clk(clk, 1);
          if empty = '0' then
            check_equal(read_data, std_logic_vector(out_data), "Read wrong value");
            out_data := out_data + 1;
          end if;
          in_data := in_data + 1;
          write_data <= std_logic_vector(in_data);
        end loop;

        write_en <= '0';
        read_en  <= '1';

        while empty = '0' loop
          wait_clk(clk, 1);
          if empty = '0' then
            check_equal(read_data, std_logic_vector(out_data), "Read wrong value");
            out_data := out_data + 1;
          end if;
        end loop;

      elsif run("Underflow") then
        in_data   := to_unsigned(1, in_data'length);
        write_en  <= '1';
        write_data <= std_logic_vector(in_data);
        wait_clk(clk, 1);
        write_en  <= '0';
        wait_clk(clk, 1);

        read_en   <= '1';
        wait_clk(clk, 3);
        read_en   <= '0';
        wait_clk(clk, 1);
        check_equal(empty, '1', "FIFO should be empty");
        check_equal(full, '0', "FIFO should not be full");

        in_data   := to_unsigned(1, in_data'length);
        write_en  <= '1';
        write_data <= std_logic_vector(in_data);
        wait_clk(clk, 1);
        in_data   := to_unsigned(2, in_data'length);
        write_en  <= '1';
        write_data <= std_logic_vector(in_data);
        wait_clk(clk, 1);
        in_data   := to_unsigned(3, in_data'length);
        write_en  <= '1';
        write_data <= std_logic_vector(in_data);
        wait_clk(clk, 1);
        write_en  <= '0';
        wait_clk(clk, 1);

        check_equal(empty, '0', "FIFO should not be empty");
        check_equal(full, '0', "FIFO should not be full");

        read_en   <= '1';
        wait_clk(clk, 1);
        check_equal(read_data, to_unsigned(1,8), "Read wrong value");
        wait_clk(clk, 1);
        check_equal(read_data, to_unsigned(2,8), "Read wrong value");
        wait_clk(clk, 1);
        check_equal(read_data, to_unsigned(3,8), "Read wrong value");
        read_en   <= '0';
        wait_clk(clk, 1);
        check_equal(empty, '1', "FIFO should not be empty");

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;


----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.fifo
  generic map (
    G_DATA_WIDTH              => C_DATA_WIDTH,
    G_LOG2_DEPTH              => C_LOG2_DEPTH
  )
  port map (
    clk              => clk,
    sreset           => reset,
    --------------------------------------------------
    write_data       => write_data,
    write_en         => write_en,
    full             => full,
    --------------------------------------------------
    read_data        => read_data,
    read_en          => read_en,
    empty            => empty
  );

end architecture;