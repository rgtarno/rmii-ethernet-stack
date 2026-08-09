library IEEE;
use IEEE.std_logic_1164.all;

package apb_data_types is 

  type apb_cmd_t is record
    paddr     : std_logic_vector(7 downto 0);
    pprot     : std_logic_vector(2 downto 0);
    psel      : std_logic;
    penable   : std_logic;
    pwrite    : std_logic;
    pwdata    : std_logic_vector(31 downto 0);
    pstrb     : std_logic_vector(3 downto 0);
    pwakeup   : std_logic;
  end record;

  type apb_rsp_t is record
    pready    : std_logic;
    prdata    : std_logic_vector(31 downto 0);
    pslverr   : std_logic;
  end record;

  constant apb_cmd_0 : apb_cmd_t := (
    paddr     => (others => '0'),
    pprot     => (others => '0'),
    psel      => '0',
    penable   => '0',
    pwrite    => '0',
    pwdata    => (others => '0'),
    pstrb     => (others => '0'),
    pwakeup   => '0'
  );

  constant apb_rsp_0 : apb_rsp_t := (
    pready  => '0',
    prdata  => (others => '0'),
    pslverr => '0'
  );

  type apb_cmd_array_t is array (natural range <>) of apb_cmd_t;
  type apb_rsp_array_t is array (natural range <>) of apb_rsp_t;


end package apb_data_types;
