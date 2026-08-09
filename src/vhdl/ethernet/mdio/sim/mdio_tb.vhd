library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.utils.all;
use work.mdio_slave_pkg.all;

entity mdio_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of mdio_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant C_CLK_FREQ_Hz          : natural := 125000000;
  constant C_MDC_FREQ_Hz          : natural := 500000;
  constant CLKP                   : time := 8 ns;
  constant C_NUM_REGS             : natural := 8;


  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk                 : std_logic := '0';
  signal reset               : std_logic := '0';

  signal mdio_ready          : std_logic := '0';
  signal send_msg_in         : std_logic := '0';
  signal write_enable_in     : std_logic := '0';
  signal phy_address_in      : std_logic_vector(4 downto 0) := (others => '0');
  signal reg_address_in      : std_logic_vector(4 downto 0) := (others => '0');
  signal write_data_in       : std_logic_vector(15 downto 0) := (others => '0');
  signal read_data_out       : std_logic_vector(15 downto 0) := (others => '0');
  signal op_done             : std_logic := '0';
  signal mdio_in             : std_logic := '0';
  signal mdio_out            : std_logic := '0';
  signal mdio_t_out          : std_logic := '0';
  signal mdc                 : std_logic := '0';

  signal dut_mdc : std_logic;

  signal MDIO_LINE : std_logic;

  signal data_read_regs     : data_array_t(C_NUM_REGS-1 downto 0);
  signal data_write_regs_en : std_logic_vector(C_NUM_REGS-1 downto 0) := (others => '0');
  signal data_write_regs    : data_array_t(C_NUM_REGS-1 downto 0) := (others => (others => '0'));

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
  procedure mdio_read(reg_address : natural;
                      phy_address : natural
                      ) is
  begin
    send_msg_in     <= '1';
    write_enable_in <= '0';
    phy_address_in  <= std_logic_vector(to_unsigned(phy_address, phy_address_in'length));
    reg_address_in  <= std_logic_vector(to_unsigned(reg_address, reg_address_in'length));
    wait until rising_edge(clk) and mdio_ready = '1';
    send_msg_in <= '0';
    wait until rising_edge(clk) and op_done = '1';
  end procedure;

  procedure mdio_write(reg_address : natural;
                      phy_address  : natural;
                      data         : std_logic_vector(15 downto 0)
                      ) is
  begin
    send_msg_in     <= '1';
    write_enable_in <= '1';
    write_data_in   <= data;
    phy_address_in  <= std_logic_vector(to_unsigned(phy_address, phy_address_in'length));
    reg_address_in  <= std_logic_vector(to_unsigned(reg_address, reg_address_in'length));
    wait until rising_edge(clk) and mdio_ready = '1';
    send_msg_in <= '0';
    wait until rising_edge(clk) and op_done = '1';
  end procedure;

  variable rnd : RandomPType;
  variable input_data : std_logic_vector(15 downto 0);

begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 10 ms);
  
  while test_suite loop
    send_msg_in       <= '0';
    write_enable_in   <= '0';
    write_data_in     <= (others => '0');
    phy_address_in    <= (others => '0');
    reg_address_in    <= (others => '0');
    reset <= '1';
    wait_clk(clk, 10);
    reset <= '0';
    wait_clk(clk, 10);

    if run("Single read") then

      mdio_read(2, 1);

      check_equal(read_data_out, data_read_regs(2), "Data read from PHY does not match expected");

      wait_clk(clk, 1);
      check_equal(op_done, '0', "Op done should be low");

      wait_clk(clk, 10);

    elsif run("Write and read back") then

      mdio_write(4, 1, x"cafe");

      check_equal(write_data_in, data_write_regs(to_integer(unsigned(reg_address_in))), "Data written to PHY does not match expected");

      wait_clk(clk, 10);

      mdio_read(4, 1);

      check_equal(write_data_in, data_read_regs(to_integer(unsigned(reg_address_in))), "Data read from PHY does not match expected");

      wait_clk(clk, 1);
      check_equal(op_done, '0', "Op done should be low");

      wait_clk(clk, 10);

    elsif run("Write and read back all regs") then

      for i in 0 to C_NUM_REGS-1 loop
        input_data := rnd.RandSlv(10, 16#fff#, 16);
        mdio_write(i, 1, input_data);
        check_equal(data_write_regs(i), input_data, "Data written to PHY does not match expected");

        mdio_read(i, 1);

        check_equal(read_data_out, input_data, "Did not read back expected data");

      end loop;

    end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here

end process;

----------------------------------------
-- DUT
----------------------------------------

i_dut : entity work.mdio
  generic map (
    G_CLK_FREQ_Hz       => C_CLK_FREQ_Hz,
    G_MDC_FREQ_Hz       => C_MDC_FREQ_Hz
  )
  port map (
    clk                 => clk,
    reset               => reset,
    --------------------------------------------------------
    ready_out           => mdio_ready,
    send_msg_in         => send_msg_in,
    write_enable_in     => write_enable_in,
    phy_address_in      => phy_address_in,
    reg_address_in      => reg_address_in,
    write_data_in       => write_data_in,
    --------------------------------------------------------
    read_data_out       => read_data_out,
    op_done             => op_done,
    --------------------------------------------------------
    mdio_in             => mdio_in,
    mdio_out            => mdio_out,
    mdio_tristate_out   => mdio_t_out,
    mdc_out             => mdc
  );

  dut_mdc <= 'Z' when mdio_t_out = '1'
                else mdio_out;

  MDIO_LINE <= dut_mdc;

  mdio_in <= MDIO_LINE;

----------------------------------------
-- PHY model
----------------------------------------
i_mdio_slave : entity work.mdio_slave
  generic map (
    G_NUM_REGS => C_NUM_REGS
  )
  port map (
    mdc                   => mdc,
    mdio                  => MDIO_LINE,
    --------------------------------------------------
    reset                 => reset,
    expected_phy_address  => phy_address_in,
    --------------------------------------------------
    data_read_regs_in     => data_read_regs,
    reg_write_en          => data_write_regs_en,
    data_write_regs_out   => data_write_regs
  );

g_regs : for i in 0 to C_NUM_REGS-1 generate
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        data_read_regs(i) <= std_logic_vector(to_unsigned(i, 16));
      else
        if data_write_regs_en(i) = '1' then
          data_read_regs(i) <= data_write_regs(i);
        end if;
      end if;
    end if;
  end process;
  
end generate;

end architecture;
