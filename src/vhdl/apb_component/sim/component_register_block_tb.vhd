library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.utils.all;
use work.apb_data_types.all;

entity component_register_block_tb is
  generic (runner_cfg : string);
end entity;

architecture tb of component_register_block_tb is

  ----------------------------------------
  -- TYPES
  ----------------------------------------
  type counter_array_t is array(natural range <>) of std_logic_vector(31 downto 0);

  ----------------------------------------
  -- CONSTANTS
  ----------------------------------------
  constant CLKP            : time := 10 ns;
  constant C_NUM_REGISTERS : natural := 7;

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

  signal ren_counters  : counter_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));
  signal wen_counters  : counter_array_t(C_NUM_REGISTERS-1 downto 0) := (others => (others => '0'));

begin

  test_runner_watchdog(runner, 10 ms);

  process
  begin
    wait for CLKP/2;
    clk <= not clk;
  end process;

  main : process
    variable my_checker : checker_t;

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

  variable read_data  : std_logic_vector(31 downto 0) := (others => '0');
  variable write_data : std_logic_vector(31 downto 0) := (others => '0');


  begin
    test_runner_setup(runner, runner_cfg);
    set_timeout(runner, 1 ms);

    while test_suite loop

      apb_cmd <= apb_cmd_0;
      reset   <= '1';

      wait_clk(clk, 5);

      reset <= '0';
      wait_clk(clk, 2);

      if run("Single write") then

        -------------------------------------------------
        -- Single write
        write_data := x"cafebabe";
        apb_write(1, write_data);

        wait_clk(clk, 2);

        check_equal(unsigned(wen_counters(1)), 1 , "Expected write enable to go high");
        check_equal(unsigned(ren_counters(1)), 0 , "Expected read enable to stay low");
        check_equal(reg_wdata(1), write_data, "Expected data to equal write payload");

        wait_clk(clk, 10);

      elsif run ("Back to back write") then
        -------------------------------------------------
        -- Two back to back writes
        write_data := x"deadbeef";
        apb_write(2, write_data);

        write_data := x"fee1dead";
        apb_write(3, write_data);

        wait_clk(clk, 2);
        
        write_data := x"deadbeef";
        check_equal(reg_wdata(2), write_data, "Expected write enable to go high for write 1");

        write_data := x"fee1dead";
        check_equal(reg_wdata(3), write_data, "Expected write enable to go high for write 2");

        check_equal(unsigned(wen_counters(2)), 1 , "Expected write enable to go high for reg 2");
        check_equal(unsigned(wen_counters(3)), 1 , "Expected write enable to go high for reg 3");


        wait_clk(clk, 10);
      
      elsif run("Single write then wait and then single read") then

        -------------------------------------------------
        -- Single write and read
        write_data := x"aaaabbbb";
        apb_write(5, write_data);

        wait_clk(clk, 10);

        apb_read(5, read_data);

        wait_clk(clk, 10);
        
        check_equal(read_data, write_data, "Did not read back the value that we wrote");
        check_equal(unsigned(ren_counters(5)), 1 , "Expected read enable to go high for reg 5");

      
      elsif run("Write and read all registers") then
        -------------------------------------------------
        
        for i in 0 to C_NUM_REGISTERS-1 loop
          -- Write
          write_data := std_logic_vector(to_unsigned(i+20, apb_cmd.pwdata'length));
          apb_write(i, write_data);

          apb_read(i, read_data);

          check_equal(reg_wdata(i), write_data, "Expected data to equal write payload for write 1");
          check_equal(read_data, write_data, "Did not read back the value that we wrote");
        end loop;

        wait_clk(clk, 5);

        for i in 0 to C_NUM_REGISTERS-1 loop
          check_equal(unsigned(wen_counters(i)), 1 , "Expected 1 write");
          check_equal(unsigned(ren_counters(i)), 1 , "Expected 1 read");
        end loop;


        elsif run("Check ren count") then

          for i in 0 to 22-1 loop
            apb_read(6, read_data);
          end loop;

          wait_clk(clk, 2);

          for i in 0 to C_NUM_REGISTERS-1 loop
            if i = 6 then
              check_equal(unsigned(ren_counters(i)), to_unsigned(22, 32));
              check_equal(unsigned(wen_counters(i)), to_unsigned(0, 32));
            else
              check_equal(unsigned(ren_counters(i)), to_unsigned(0, 32));
              check_equal(unsigned(wen_counters(i)), to_unsigned(0, 32));
            end if;
          end loop;
        
          elsif run("Check wen count") then

            for i in 0 to 22-1 loop
              apb_write(6, write_data);
            end loop;
  
            wait_clk(clk, 2);
  
            for i in 0 to C_NUM_REGISTERS-1 loop
              if i = 6 then
                check_equal(unsigned(ren_counters(i)), to_unsigned(0, 32));
                check_equal(unsigned(wen_counters(i)), to_unsigned(22, 32));
              else
                check_equal(unsigned(ren_counters(i)), to_unsigned(0, 32));
                check_equal(unsigned(wen_counters(i)), to_unsigned(0, 32));
              end if;
            end loop;
  

        elsif run("Alternating write and reads") then

          for repeat in 0 to 30-1 loop

            for i in 0 to C_NUM_REGISTERS-1 loop

              write_data := std_logic_vector(to_unsigned(i*repeat, apb_cmd.pwdata'length));
              apb_write(i, write_data);

              apb_read(i, read_data);

              check_equal(reg_wdata(i), write_data, "Did not write correct value");
              check_equal(read_data, write_data, "Did not read back the value that we wrote");

            end loop;
            
          end loop;

          wait_clk(clk, 2);

          for i in 0 to C_NUM_REGISTERS-1 loop
            check_equal(unsigned(ren_counters(i)), to_unsigned(30, 32));
            check_equal(unsigned(wen_counters(i)), to_unsigned(30, 32));
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


  --------------------------------
  -- Loopback all registers
  process(reg_wdata)
  begin
    for i in 0 to C_NUM_REGISTERS-1 loop
      reg_rdata(i) <= reg_wdata(i);
    end loop;
  end process;

  g_counters : for i in 0 to C_NUM_REGISTERS-1 generate
  begin

    i_ren_pulse_counter : entity work.pulse_counter
      port map (
        clk              => clk,
        reset            => reset,
        --------------------------------------------------
        enable_in        => reg_ren(i),
        --------------------------------------------------
        count_out        => ren_counters(i)
      );
    
    i_wen_pulse_counter : entity work.pulse_counter
      port map (
        clk              => clk,
        reset            => reset,
        --------------------------------------------------
        enable_in        => reg_wen(i),
        --------------------------------------------------
        count_out        => wen_counters(i)
      );

    i_ren_tb_pulse_checker : entity work.tb_pulse_checker
      port map (
        clk              => clk,
        reset            => reset,
        --------------------------------------------------
        pulse_in         => reg_ren(i)
      );
    i_wen_tb_pulse_checker : entity work.tb_pulse_checker
      port map (
        clk              => clk,
        reset            => reset,
        --------------------------------------------------
        pulse_in         => reg_wen(i)
      );

  end generate;


end architecture;