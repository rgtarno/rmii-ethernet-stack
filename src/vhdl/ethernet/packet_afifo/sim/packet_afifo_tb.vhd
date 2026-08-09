library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;

entity packet_afifo_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of packet_afifo_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant C_CLK_A_PERIOD         : time := 10 ns;
  constant C_CLK_B_PERIOD         : time := 14.2 ns;
  constant C_LOG2_DEPTH           : natural := 12;

  constant C_NUM_PACKETS          : natural := 30;
  constant C_GEN_STALL_PROB       : real := 0.2;
  constant C_READ_MIN_STALL       : natural := 2;
  constant C_READ_MAX_STALL       : natural := 10;


  constant C_READ_STALL_PROB       : real := 0.80;


  
  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk_a                : std_logic := '0';
  signal clk_b                : std_logic := '0';

  signal reset                : std_logic := '0';
  signal start_signal         : std_logic := '0';
  signal finished_signal      : std_logic := '0';
  
  signal s_axis_tdata_in      : std_logic_vector(7 downto 0);
  signal s_axis_tvalid_in     : std_logic;
  signal s_axis_tlast_in      : std_logic;
  signal s_axis_tready_out    : std_logic;

  signal m_axis_tdata_out     : std_logic_vector(7 downto 0);
  signal m_axis_tvalid_out    : std_logic;
  signal m_axis_tlast_out     : std_logic;
  signal m_axis_tready_in     : std_logic;

  signal valid_stability_start  : std_logic := '0';
  signal valid_stability_stop   : std_logic := '0';

begin

----------------------------------------
-- CLK generation
----------------------------------------
process
begin
  wait for C_CLK_A_PERIOD/2;
  clk_a <= not clk_a;
end process;

process
begin
  wait for C_CLK_B_PERIOD/2;
  clk_b <= not clk_b;
end process;

----------------------------------------
-- Stim
----------------------------------------
main : process
  variable counter : unsigned(7 downto 0) := (others => '0');
begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 10 ms);
    
    while test_suite loop

      reset <= '1';
      wait_clk(clk_a, 5);
      reset <= '0';
      wait_clk(clk_a, 5);

      if run("a") then


        start_signal <= '1';

        wait until finished_signal = '1';
        while m_axis_tvalid_out = '1' loop
          wait_clk(clk_b, 1000);
        end loop;

      end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;

----------------------------------------
-- Generate input 
----------------------------------------
process
  variable rnd              : RandomPType;
  variable num_stall_cycles : natural := 0;
  variable packet_length    : natural := 0;
  variable counter          : unsigned(7 downto 0) := (others => '0');
begin
  rnd.InitSeed(rnd'instance_name);

  s_axis_tdata_in   <= (others => '0');
  s_axis_tvalid_in  <= '0';
  s_axis_tlast_in   <= '0';

  wait until start_signal = '1' and rising_edge(clk_b);

  for i in 0 to C_NUM_PACKETS-1 loop

    packet_length := rnd.RandInt(1, 1500);

    for j in 0 to packet_length-1 loop

      if rnd.RandReal(0.0, 1.0) < C_GEN_STALL_PROB then
        num_stall_cycles := rnd.RandInt(C_READ_MIN_STALL, C_READ_MAX_STALL);
        wait_clk(clk_a, num_stall_cycles);
      end if;

      s_axis_tvalid_in <= '1';
      s_axis_tdata_in  <= std_logic_vector(counter);
      counter := counter + 1;
      if j = packet_length-1 then
        s_axis_tlast_in <= '1';
      else
        s_axis_tlast_in <= '0';
      end if;
  
      wait until s_axis_tready_out = '1' and rising_edge(clk_a);
      
      s_axis_tvalid_in <= '0';

    end loop;
  end loop;


  info("Finished injecting packet");
  finished_signal <= '1';
  wait;

end process;

----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.packet_afifo
  generic map (
    G_LOG2_DEPTH          => C_LOG2_DEPTH
  )
  port map (
    reset                  => reset,
    --------------------------------------------------------
    wr_clk                 => clk_a,
    s_axis_tdata_in        => s_axis_tdata_in,
    s_axis_tvalid_in       => s_axis_tvalid_in,
    s_axis_tlast_in        => s_axis_tlast_in,
    s_axis_tready_out      => s_axis_tready_out,
    --------------------------------------------------------
    rd_clk                 => clk_b,
    m_axis_tdata_out       => m_axis_tdata_out,
    m_axis_tvalid_out      => m_axis_tvalid_out,
    m_axis_tlast_out       => m_axis_tlast_out,
    m_axis_tready_in       => m_axis_tready_in
  );

----------------------------------------
-- Generate backpressure 
----------------------------------------
process
  variable rnd              : RandomPType;
  variable num_stall_cycles : natural := 0;
begin
  rnd.InitSeed(rnd'instance_name);

  m_axis_tready_in <= '0';

  while true loop

    if rnd.RandReal(0.0, 1.0) < C_READ_STALL_PROB then
      num_stall_cycles := rnd.RandInt(C_READ_MIN_STALL, C_READ_MAX_STALL/2);
      wait_clk(clk_b, num_stall_cycles);
    end if;
    m_axis_tready_in <= '1';

    wait until m_axis_tvalid_out = '1' and rising_edge(clk_b);
    m_axis_tready_in <= '0';

  end loop;

  wait;

end process;

  ----------------------------------------
  -- Check data
  ----------------------------------------

  process(clk_b)
    variable expected_value : unsigned(7 downto 0) := (others => '0');
  begin
    if rising_edge(clk_b) then
      if reset = '1' then
        expected_value := (others => '0');
      else
        if m_axis_tvalid_out = '1' and m_axis_tready_in = '1' then
          check_equal(m_axis_tdata_out, expected_value, "Counter check failed");
          expected_value := expected_value + 1;
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------
  -- 
  ----------------------------------------

  valid_stability_start <= m_axis_tvalid_out;
  valid_stability_stop  <= m_axis_tvalid_out and m_axis_tlast_out and m_axis_tready_in;

  rdata_stability_check : check_stable(
    clk_b,
    start_signal,
    valid_stability_start,
    valid_stability_stop,
    m_axis_tvalid_out,
    result("valid stability")
  );

end architecture;