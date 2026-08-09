library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.apb_data_types.all;
use work.utils.all;

package sim_utils is 

  -- Simulation only

  procedure apb_read (signal clk : std_logic;
                      constant addr : natural;
                      read_data : out std_logic_vector(31 downto 0);
                      signal apb_cmd : out apb_cmd_t;
                      signal apb_rsp : in apb_rsp_t);

  procedure apb_write (signal clk : std_logic;
                       constant addr : natural;
                       constant write_data  : std_logic_vector(31 downto 0);
                       signal apb_cmd : out apb_cmd_t;
                       signal apb_rsp : in apb_rsp_t);
 

end package sim_utils;

package body sim_utils is

  procedure apb_read (signal clk : std_logic;
                      constant addr : natural;
                      read_data : out std_logic_vector(31 downto 0);
                      signal apb_cmd : out apb_cmd_t;
                      signal apb_rsp : in apb_rsp_t) is
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

    procedure apb_write (signal clk : std_logic;
                         constant addr : natural;
                         constant write_data  : std_logic_vector(31 downto 0);
                         signal apb_cmd : out apb_cmd_t;
                         signal apb_rsp : in apb_rsp_t) is
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


end package body;