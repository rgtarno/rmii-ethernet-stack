library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;
use vunit_lib.signal_checker_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity fifo_backpressure_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of fifo_backpressure_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 10 ns;
  constant C_DATA_WIDTH           : natural := 8;
  constant C_LOG2_DEPTH           : natural := 3;

  constant C_WRITE_MIN_STALL      : natural := 1;
  constant C_WRITE_MAX_STALL      : natural := 10;

  constant C_READ_MIN_STALL       : natural := 1;
  constant C_READ_MAX_STALL       : natural := 10;

  constant fifo_dout_checker : signal_checker_t := new_signal_checker(
    logger => get_logger("fifo_dout_checker"));
  
  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                  : std_logic := '0';
  signal reset                : std_logic := '0';
  signal start_writes         : std_logic := '0';
  signal start_reads          : std_logic := '0';

  signal data_in_counter      : unsigned(C_DATA_WIDTH-1 downto 0) := (others => '0');

  signal write_data           : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal write_en             : std_logic := '0';
  signal full                 : std_logic := '0';
  signal read_data            : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal read_en              : std_logic := '0';
  signal empty                : std_logic := '0';

  signal checker_data         : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '1');

  signal WRITE_STALL_PROB     : real    := 0.3;
  signal READ_STALL_PROB      : real    := 0.4;

  signal dout_stability_start : std_logic := '0';
  signal dout_stability_stop  : std_logic := '0';

  signal num_ops              : natural;

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
  variable tmp : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 20 ms);
    
    while test_suite loop

      data_in_counter  <= (others => '0');
      start_writes    <= '0';
      start_reads     <= '0';
      reset <= '1';
      wait_clk(clk, 5);
      reset <= '0';
      wait_clk(clk, 5);

      if run("Random read and write") then

        num_ops <= 1000;
        wait_clk(clk, 1);

        start_writes    <= '1';
        start_reads     <= '1';

        for i in 0 to num_ops-1 loop

          wait until rising_edge(clk) and write_en = '1' and full = '0';
          data_in_counter <= data_in_counter + 1;
          tmp := std_logic_vector(data_in_counter);
          expect(net, fifo_dout_checker, tmp, now, now + 100 * CLKP);
        end loop;

        start_writes <= '0';
        wait_clk(clk, 1);
        wait until rising_edge(clk) and empty = '1';

        wait_until_idle(net, fifo_dout_checker);
        start_reads   <= '0';

      elsif run ("Heavy read stall") then

        WRITE_STALL_PROB     <= 0.00;
        READ_STALL_PROB      <= 0.8;

        num_ops <= 3000;
        wait_clk(clk, 1);

        start_writes    <= '1';
        start_reads     <= '1';

        for i in 0 to num_ops-1 loop

          wait until rising_edge(clk) and write_en = '1' and full = '0';
            data_in_counter <= data_in_counter + 1;
            tmp := std_logic_vector(data_in_counter);
            expect(net, fifo_dout_checker, tmp, now, now + 100 * CLKP);
        end loop;
        
        start_writes    <= '0';
        wait_clk(clk, 1);
        wait until rising_edge(clk) and empty = '1';
        wait_until_idle(net, fifo_dout_checker);
        start_reads     <= '0';

      elsif run ("Heavy write stall") then

        WRITE_STALL_PROB     <= 0.9;
        READ_STALL_PROB      <= 0.00;

        num_ops <= 3000;
        wait_clk(clk, 1);

        start_writes    <= '1';
        start_reads     <= '1';

        for i in 0 to num_ops-1 loop

          wait until rising_edge(clk) and write_en = '1' and full = '0';
          data_in_counter <= data_in_counter + 1;
          tmp := std_logic_vector(data_in_counter);
          expect(net, fifo_dout_checker, tmp, now, now + 100 * CLKP);
        end loop;
        

        start_writes    <= '0';
        wait_clk(clk, 1);
        wait until rising_edge(clk) and empty = '1';
        wait_until_idle(net, fifo_dout_checker);
        start_reads     <= '0';

      elsif run ("Full duty cycle write and read") then

        WRITE_STALL_PROB     <= 1.0;
        READ_STALL_PROB      <= 1.0;

        num_ops <= 3000;
        wait_clk(clk, 1);

        start_writes    <= '1';
        start_reads     <= '1';

        for i in 0 to num_ops-1 loop

          wait until rising_edge(clk) and write_en = '1' and full = '0';
          data_in_counter <= data_in_counter + 1;
          tmp := std_logic_vector(data_in_counter);
          expect(net, fifo_dout_checker, tmp, now, now + 100 * CLKP);
        end loop;
        

        start_writes    <= '0';
        wait_clk(clk, 1);
        wait until rising_edge(clk) and empty = '1';
        wait_until_idle(net, fifo_dout_checker);
        start_reads     <= '0';

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- Generate write signal
----------------------------------------

p_write_rnd : process
  variable rnd : RandomPType;
  variable num_stall_cycles : natural := 0;
  variable number_of_writes : natural := 0;
begin
  rnd.InitSeed(rnd'instance_name);

  number_of_writes := 0;

  wait until start_writes = '1' and rising_edge(clk);


  while number_of_writes < num_ops loop
    
    if rnd.Uniform(0.0, 1.0) < WRITE_STALL_PROB then
      num_stall_cycles := rnd.FavorSmall(C_WRITE_MIN_STALL, C_WRITE_MAX_STALL);
    end if;
    for stall in 0 to num_stall_cycles-1 loop
       wait until rising_edge(clk);
    end loop;

    write_en <= '1';
    wait until full = '0' and rising_edge(clk);
    write_en <= '0';
    number_of_writes := number_of_writes + 1;
  end loop;

  wait_clk(clk, 10);

end process;

----------------------------------------
-- Generate read signal
----------------------------------------

p_read_rnd : process
  variable rnd : RandomPType;
  variable num_stall_cycles : natural := 0;
begin
  rnd.InitSeed(rnd'instance_name);

  wait until start_reads = '1' and rising_edge(clk);

  while start_reads = '1' loop

    if rnd.RandReal(0.0, 1.0) < READ_STALL_PROB then
      num_stall_cycles := rnd.FavorSmall(C_READ_MIN_STALL, C_READ_MAX_STALL);
      info("Read stall");
    end if;
    for stall in 0 to num_stall_cycles-1 loop
       wait until rising_edge(clk);
    end loop;
    read_en <= '1';

    wait until empty = '0' and rising_edge(clk);
    
    read_en <= '0';
  end loop;

  wait_clk(clk, 10);

end process;

----------------------------------------
-- DUT
----------------------------------------

write_data <= std_logic_vector(data_in_counter);

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

  ----------------------------------------
  -- Check data
  ----------------------------------------

  process(clk)
  begin
    if rising_edge(clk) then
      if empty = '0' and read_en = '1' then
        checker_data <= read_data;
      end if;
    end if;
  end process;


  fifo_dout_checker_inst: entity vunit_lib.std_logic_checker
  generic map (
    signal_checker => fifo_dout_checker
  )
  port map (
    value => checker_data
  );

  process(clk)
    variable expected_value : unsigned(7 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      if reset = '1' then
        expected_value := (others => '0');
      else
        if empty = '0' and read_en = '1' then
          check_equal(read_data, expected_value, "Counter check failed");
          expected_value := expected_value + 1;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------
  -- Check read_data is stable when fifo is not empty until a read
  ----------------------------------------

  dout_stability_start <= not empty;
  dout_stability_stop  <= read_en;

  rdata_stability_check : check_stable(
    clk,
    start_reads,
    dout_stability_start,
    dout_stability_stop,
    read_data,
    result("FIFO dout stability")
  );

end architecture;