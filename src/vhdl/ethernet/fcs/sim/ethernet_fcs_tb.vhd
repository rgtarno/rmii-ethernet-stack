library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity ethernet_fcs_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of ethernet_fcs_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 8 ns;


  type input_bytes_t is array(natural range <>) of std_logic_vector(7 downto 0);

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk            : std_logic := '0';
  signal reset          : std_logic := '0';

  signal gen_data_in        : std_logic_vector(7 downto 0);
  signal gen_valid_in       : std_logic;
  signal gen_en_calc_in     : std_logic;

  signal fcs_byte_out   : std_logic_vector(7 downto 0);
  signal crc_reg_out    : std_logic_vector(31 downto 0);

  signal check_data_in        : std_logic_vector(7 downto 0);
  signal check_valid_in       : std_logic;
  signal check_en_calc_in     : std_logic;
  signal check_verify_out     : std_logic;

  signal data_buffer : input_bytes_t(511 downto 0) := (others => (others => '0'));

begin

    test_runner_watchdog(runner, 10 ms);
  
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
    variable rnd : RandomPType;
    variable tmp_slv : std_logic_vector(7 downto 0);

    constant input_data : input_bytes_t(63 downto 0) := (
      x"00",
      x"10",
      x"A4",
      x"7B",
      x"EA",
      x"80",
      x"00",
      x"12",
      x"34",
      x"56",
      x"78",
      x"90",
      x"08",
      x"00",
      x"45",
      x"00",
      x"00",
      x"2E",
      x"B3",
      x"FE",
      x"00",
      x"00",
      x"80",
      x"11",
      x"05",
      x"40",
      x"C0",
      x"A8",
      x"00",
      x"2C",
      x"C0",
      x"A8",
      x"00",
      x"04",
      x"04",
      x"00",
      x"04",
      x"00",
      x"00",
      x"1A",
      x"2D",
      x"E8",
      x"00",
      x"01",
      x"02",
      x"03",
      x"04",
      x"05",
      x"06",
      x"07",
      x"08",
      x"09",
      x"0A",
      x"0B",
      x"0C",
      x"0D",
      x"0E",
      x"0F",
      x"10",
      x"11",
      x"B3",
      x"31",
      x"88",
      x"1B"
    );

begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 20 ms);

  rnd.InitSeed(rnd'instance_name & "FCS");

  while test_suite loop

    gen_data_in     <= (others => '0');
    gen_valid_in    <= '0';
    gen_en_calc_in  <= '0';

    check_valid_in    <= '0';
    check_en_calc_in  <= '0';

    reset <= '1';
    wait_clk(clk, 10);
    reset <= '0';
    wait_clk(clk, 10);

    if run("Case 0") then

      gen_valid_in    <= '1';
      gen_en_calc_in  <= '1';

      for i in input_data'length-1 downto 4 loop
        gen_data_in     <= input_data(i);
        wait_clk(clk, 1);
      end loop;

      gen_en_calc_in  <= '0';

      for i in 3 downto 0 loop
        wait_clk(clk, 1);
        check_equal(fcs_byte_out, input_data(i), "Generated FCS byte does not match test vector");
      end loop;
      gen_valid_in    <= '0';

      wait_clk(clk, 10);

      check_valid_in    <= '1';
      check_en_calc_in  <= '1';
      for i in input_data'length-1 downto 0 loop
        check_data_in     <= input_data(i);
        wait_clk(clk, 1);
      end loop;

      check_valid_in    <= '0';
      check_en_calc_in  <= '0';
      wait_clk(clk, 2);
      check_equal(check_verify_out, '1', "Verify bit should be high");

      wait_clk(clk, 10);
    
    elsif run("Loopback") then

      for i in 0 to data_buffer'length-5 loop
        gen_valid_in    <= '1';
        gen_en_calc_in  <= '1';
        tmp_slv := rnd.RandSlv(0, 16#ff#, 8);
        data_buffer(i) <= tmp_slv;
        gen_data_in     <= tmp_slv;
        wait_clk(clk, 1);
      end loop;
      gen_en_calc_in  <= '0';
      wait_clk(clk, 1);
      for i in  data_buffer'length-4 to data_buffer'length-1 loop
        gen_valid_in    <= '1';
        data_buffer(i)  <= fcs_byte_out;
        wait_clk(clk, 1);
      end loop;
      gen_valid_in    <= '0';

      wait_clk(clk, 3);
      for i in 0 to data_buffer'length-1 loop
        check_data_in     <= data_buffer(i);
        check_valid_in    <= '1';
        check_en_calc_in  <= '1';
        wait_clk(clk, 1);
      end loop;

      check_valid_in    <= '0';
      check_en_calc_in  <= '0';
      wait_clk(clk, 1);

      
      wait_clk(clk, 2);
      check_equal(check_verify_out, '1', "Verify bit should be high");
      wait_clk(clk, 5);


    end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here

end process;


----------------------------------------
-- DUT
----------------------------------------

i_ethernet_fcs_gen : entity work.ethernet_fcs
  port map (

    clk            => clk,
    reset          => reset,
    --------------------------------------------------------
    data_in        => gen_data_in,
    valid_in       => gen_valid_in,
    en_calc_in     => gen_en_calc_in,
    --------------------------------------------------------
    fcs_byte_out   => fcs_byte_out,
    crc_reg_out    => crc_reg_out
  );


i_ethernet_fcs_check : entity work.ethernet_fcs
  port map (

    clk            => clk,
    reset          => reset,
    --------------------------------------------------------
    data_in        => check_data_in,
    valid_in       => check_valid_in,
    en_calc_in     => check_en_calc_in,
    --------------------------------------------------------
    verify_out     => check_verify_out,
    fcs_byte_out   => open,
    crc_reg_out    => open
  );


end architecture;

