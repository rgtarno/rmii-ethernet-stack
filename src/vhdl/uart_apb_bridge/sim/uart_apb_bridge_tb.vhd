library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

use vunit_lib.uart_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.stream_master_pkg.all;

use work.utils.all;
use work.apb_data_types.all;

entity uart_apb_bridge_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of uart_apb_bridge_tb is

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP                   : time := 10 ns;
  constant C_NUM_REGISTERS        : natural := 8;
  constant C_NUM_SLAVES           : natural := 2;
  constant C_ADDR_BITS_PER_SLAVE  : natural := 8;

  constant C_CLK_RATE_Hz         : natural := 100000000;
  constant C_BAUD_RATE_Hz        : natural := 115200;

  constant master_uart            : uart_master_t := new_uart_master;
  constant master_stream          : stream_master_t := as_stream(master_uart);
  constant slave_uart             : uart_slave_t := new_uart_slave(data_length => 8);
  constant slave_stream           : stream_slave_t := as_stream(slave_uart);


  ----------------------------------------
  -- SIGNALS
  ----------------------------------------
  signal clk              : std_logic := '0';
  signal reset            : std_logic := '0';
  signal apb_cmd_out      : apb_cmd_array_t(C_NUM_SLAVES-1 downto 0) := (others => apb_cmd_0);
  signal apb_rsp_in       : apb_rsp_array_t(C_NUM_SLAVES-1 downto 0) := (others => apb_rsp_0);

  signal uart_rx          : std_logic := '1';
  signal uart_tx          : std_logic := '1';


  function create_word(is_write: boolean; slave_num : natural; address : natural) return std_logic_vector is
    variable ret : std_logic_vector(31 downto 0) := (others => '0');
  begin
    if is_write then
      ret(31) := '1';
    end if;
    ret(30 downto 8) := std_logic_vector(to_unsigned(slave_num, 30-8+1));
    ret(7 downto 0) := std_logic_vector(to_unsigned(address, 7-0+1));
    return ret;
  end function;

begin

  ----------------------------------------
  -- CLK generation
  ----------------------------------------
  process
  begin
    wait for CLKP/2;
    clk <= not clk;
  end process;

  test_runner_watchdog(runner, 2 ms);
  
----------------------------------------
-- Stim
----------------------------------------

main : process
  variable reference_queue : queue_t := new_queue;
  variable reference       : stream_reference_t;

  procedure do_write(constant write_addr : std_logic_vector(31 downto 0);
                     constant write_data : std_logic_vector(31 downto 0)) is
    variable read_back_data : std_logic_vector(31 downto 0);
    variable read_back_word : std_logic_vector(7 downto 0);
    variable write_word : std_logic_vector(7 downto 0);
  begin
    -- Write address
    for i in 0 to 3 loop
      write_word := write_addr(((i+1)*8)-1 downto i*8);
      push_stream(net, master_stream, write_word);
    end loop;
    -- Write data
    for i in 0 to 3 loop
      push_stream(net, master_stream, write_data(((i+1)*8)-1 downto i*8));
      pop_stream(net, slave_stream, reference);
      push(reference_queue, reference);
    end loop;

    -- Readback write data
    for i in 0 to 3 loop
      reference := pop(reference_queue);
      await_pop_stream_reply(net, reference, read_back_word);
      read_back_data(((i+1)*8)-1 downto (i*8)) := read_back_word;
    end loop;
    check_equal(read_back_data, write_data);

  end procedure;

  procedure do_read(constant read_addr : std_logic_vector;
                     variable read_data : out std_logic_vector) is
    variable write_word : std_logic_vector(7 downto 0);
    variable read_word : std_logic_vector(7 downto 0);
    variable last : boolean;
  begin

    -- Write read address
    for i in 0 to 3 loop
      write_word := read_addr(((i+1)*8)-1 downto i*8);
      push_stream(net, master_stream, write_word);
    end loop;

    -- Read response
    for i in 0 to 3 loop
      pop_stream(net, slave_stream, read_word, last);
      read_data(((i+1)*8)-1 downto (i*8)) := read_word;
    end loop;

  end procedure;
    
    variable read_data : std_logic_vector(31 downto 0) := (others => '0');
    variable write_data : std_logic_vector(31 downto 0) := (others => '0');
begin
  test_runner_setup(runner, runner_cfg);
  set_timeout(runner, 50 ms);

  set_baud_rate(net, slave_uart, C_BAUD_RATE_Hz);
  set_baud_rate(net, master_uart, C_BAUD_RATE_Hz);

  while test_suite loop

    reset   <= '0';
    wait_clk(clk, 5);
    reset <= '0';
    wait_clk(clk, 15);

    if run("Write_and_read_back") then
      -- info("READ : " & to_hstring(read_data));

      write_data := x"cafebabe";
      do_write(create_word(true, 0, 1), write_data);
      do_read(create_word(false, 0, 1), read_data);
      check_equal(read_data, write_data);

      write_data := x"fee1dead";
      do_write(create_word(true, 0, 2), write_data);
      do_read(create_word(false, 0, 2), read_data);
      check_equal(read_data, write_data);

      write_data := x"aabbccdd";
      do_write(create_word(true, 1, 3), write_data);
      do_read(create_word(false, 1, 3), read_data);
      check_equal(read_data, write_data);
      do_read(create_word(false, 1, 3), read_data);
      check_equal(read_data, write_data);

      write_data := x"11111111";
      do_write(create_word(true, 1, 6), write_data);
      write_data := x"22222222";
      do_write(create_word(true, 1, 6), write_data);
      do_read(create_word(false, 1, 6), read_data);
      check_equal(read_data, write_data);

      for i in 0 to C_NUM_SLAVES-1 loop
        for j in 0 to C_NUM_REGISTERS-1 loop
          write_data := std_logic_vector(to_unsigned((i * 2000) + (j*10), 32));
          do_write(create_word(true, i, j), write_data);
          do_read(create_word(false, i, j), read_data);
          check_equal(read_data, write_data);
        end loop;
      end loop;
      


    end if;

  end loop;

  test_runner_cleanup(runner); -- Simulation ends here
end process;
----------------------------------------
-- UART MASTER
----------------------------------------
i_uart_master: entity vunit_lib.uart_master
  generic map (
    uart => master_uart
  )
  port map (
    tx => uart_rx
  );

----------------------------------------
-- UART SLAVE
----------------------------------------
i_uart_slave: entity vunit_lib.uart_slave
  generic map (
    uart => slave_uart
  )
  port map (
    rx => uart_tx
  );

----------------------------------------
-- DUT
----------------------------------------
i_dut : entity work.uart_apb_bridge
  generic map (
    G_NUM_SLAVES          => C_NUM_SLAVES,
    G_ADDR_BITS_PER_SLAVE => C_ADDR_BITS_PER_SLAVE,
    G_CLK_RATE_Hz         => C_CLK_RATE_Hz,
    G_BAUD_RATE_Hz        => C_BAUD_RATE_Hz
  )
  port map (
    clk              => clk,
    reset            => reset,
    --------------------------------------------------
    uart_rx          => uart_rx,
    uart_tx          => uart_tx,
    --------------------------------------------------
    apb_cmd_out      => apb_cmd_out,
    apb_rsp_in       => apb_rsp_in
  );

----------------------------------------
-- Registers
----------------------------------------
g_slaves : for i in 0 to C_NUM_SLAVES-1 generate

  signal reg_rdata     : slv32_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_wdata     : slv32_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal reg_ren       : std_logic_vector(C_NUM_REGISTERS-1 downto 0) := (others => '0');
  signal reg_wen       : std_logic_vector(C_NUM_REGISTERS-1 downto 0) := (others => '0');

begin

  i_apg_slave : entity work.component_register_block
  generic map (
    G_NUM_REGISTERS => C_NUM_REGISTERS
  )
  port map (
    clk              => clk,
    --------------------------------------------------
    apb_cmd_in       => apb_cmd_out(i),
    apb_rsp_out      => apb_rsp_in(i),
    --------------------------------------------------
    reg_rdata_in     => reg_rdata,
    reg_wdata_out    => reg_wdata,
    reg_ren_out      => reg_ren,
    reg_wen_out      => reg_wen
  );

  g_upper_reg : for j in 0 to C_NUM_REGISTERS-1 generate
  begin
    reg_rdata(j) <= reg_wdata(j);
  end generate;

  end generate;

end architecture;