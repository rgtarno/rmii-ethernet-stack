library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;


library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;
use work.apb_data_types.all;

entity component_register_block_timing_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of component_register_block_timing_tb is

  ----------------------------------------
  -- TYPES
  ----------------------------------------

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP            : time := 10 ns;
  constant C_NUM_REGISTERS : natural := 2;

  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk           : std_logic := '0';
  signal reset         : std_logic := '0';

  signal apb_cmd       : apb_cmd_t := apb_cmd_0;
  signal apb_rsp       : apb_rsp_t := apb_rsp_0;
  signal reg_rdata     : slv32_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_wdata     : slv32_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_ren       : std_logic_vector(C_NUM_REGISTERS-1 downto 0) := (others => '0');
  signal reg_wen       : std_logic_vector(C_NUM_REGISTERS-1 downto 0) := (others => '0');

  signal counter_a_latched_on_read : std_logic_vector(31 downto 0);
  signal counter_b_latched_on_read : std_logic_vector(31 downto 0);

  signal counter_a : unsigned(31 downto 0);
  signal counter_b : unsigned(31 downto 0);

  signal write_reg_a_latched_on_write : std_logic_vector(31 downto 0);
  signal write_reg_b_latched_on_write : std_logic_vector(31 downto 0);

begin

  test_runner_watchdog(runner, 10 ms);

  process
  begin
    wait for CLKP/2;
    clk <= not clk;
  end process;

  main : process

    procedure apb_read (constant addr       : natural;
                        read_data    : out std_logic_vector(31 downto 0)
                      ) is
    begin
      apb_cmd.paddr   <= std_logic_vector(to_unsigned(addr, apb_cmd.paddr'length));
      apb_cmd.pwrite  <= '0';
      apb_cmd.psel    <= '1';
      wait_clk(clk, 1);
      apb_cmd.penable <= '1';
      wait until rising_edge(clk) and apb_rsp.pready = '1';
      apb_cmd.penable <= '0';
      read_data       := apb_rsp.prdata;
      apb_cmd.psel    <= '0';
    end procedure;
    procedure apb_write (constant addr        : natural;
                         constant write_data  : std_logic_vector(31 downto 0)
                      ) is
    begin
      apb_cmd.paddr   <= std_logic_vector(to_unsigned(addr, apb_cmd.paddr'length));
      apb_cmd.pwdata  <= write_data;
      apb_cmd.pwrite  <= '1';
      apb_cmd.psel    <= '1';
      wait_clk(clk, 1);
      apb_cmd.penable <= '1';
      wait until rising_edge(clk) and apb_rsp.pready = '1';
      apb_cmd.penable <= '0';
      apb_cmd.pwrite  <= '0';
      apb_cmd.psel    <= '0';
    end procedure;

    variable read_data        : std_logic_vector(31 downto 0) := (others => '0');
    variable write_data       : std_logic_vector(31 downto 0) := (others => '0');
    variable rnd              : RandomPType;

  begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 10 ms);

    rnd.InitSeed(rnd'instance_name);

    while test_suite loop

      apb_cmd <= apb_cmd_0;
      reset   <= '1';

      wait_clk(clk, 5);

      reset <= '0';
      wait_clk(clk, 2);

      if run("Read enable alignment") then

        for i in 0 to 1000-1 loop

          wait_clk(clk, rnd.RandInt(0, 30));
          apb_read(0, read_data);
          wait_clk(clk, 1);
          check_equal(read_data, counter_a_latched_on_read);

          wait_clk(clk, rnd.RandInt(0, 30));
          apb_read(1, read_data);
          wait_clk(clk, 1);
          check_equal(read_data, counter_b_latched_on_read);

        end loop;

      elsif run("Write enable alignment") then

        for i in 0 to 1000-1 loop

          wait_clk(clk, rnd.RandInt(0, 30));
          write_data := rnd.RandSlv(0, 16#ffffff#, 32);
          apb_write(0, write_data);
          wait on write_reg_a_latched_on_write;
          check_equal(write_data, write_reg_a_latched_on_write);

          wait_clk(clk, rnd.RandInt(0, 30));
          write_data := rnd.RandSlv(0, 16#ffffff#, 32);
          apb_write(1, write_data);
          wait on write_reg_b_latched_on_write;
          check_equal(write_data, write_reg_b_latched_on_write);

        end loop;
        

      end if;

    end loop;

    test_runner_cleanup(runner); -- Simulation ends here
  end process;


i_dut : entity work.component_register_block
  generic map (
    G_NUM_REGISTERS => C_NUM_REGISTERS
  )
  port map (
    clk              => clk,
    --------------------------------------------------
    apb_cmd_in       => apb_cmd,
    apb_rsp_out      => apb_rsp,
    --------------------------------------------------
    reg_rdata_in     => reg_rdata,
    reg_wdata_out    => reg_wdata,
    reg_ren_out      => reg_ren,
    reg_wen_out      => reg_wen
  );

  reg_rdata(0) <= std_logic_vector(counter_a);
  reg_rdata(1) <= std_logic_vector(counter_b);

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
          counter_a <= (others => '0');
          counter_b <= (others => '1');
      else
        counter_b <= counter_b - 1;
        counter_a <= counter_a + 1;
      end if;
    end if;
  end process;

  process
  begin
    wait until reset = '0' and rising_edge(clk);
    while reset /= '1' loop
      wait until reg_ren(0) = '1' and rising_edge(clk);
      counter_a_latched_on_read <= std_logic_vector(counter_a);
    end loop;
  end process;

  process
  begin
    wait until reset = '0' and rising_edge(clk);
    while reset /= '1' loop
      wait until reg_ren(1) = '1' and rising_edge(clk);
      counter_b_latched_on_read <= std_logic_vector(counter_b);
    end loop;
  end process;

  process
  begin
    wait until reset = '0' and rising_edge(clk);
    while reset /= '1' loop
      wait until reg_wen(0) = '1' and rising_edge(clk);
      write_reg_a_latched_on_write <= reg_wdata(0);
    end loop;
  end process;

  process
  begin
    wait until reset = '0' and rising_edge(clk);
    while reset /= '1' loop
      wait until reg_wen(1) = '1' and rising_edge(clk);
      write_reg_b_latched_on_write <= reg_wdata(1);
    end loop;
  end process;


end architecture;