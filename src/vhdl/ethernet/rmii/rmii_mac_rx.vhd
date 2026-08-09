library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;

-- In RMII the Carrier Sense (CRS) and Data Valid signals are multiplexed on to the CRS_DV line.
-- CRS_DV that coincides with the rising clock edge for the first di-bit of a nibble is CRS.
-- The 2ns dibit is DV.
-- So they alternate clock cycles.

entity rmii_mac_rx is
  port (
    clk50               : in std_logic;
    reset               : in std_logic;
    --------------------------------------------------------
    m_axis_tdata_out    : out std_logic_vector(7 downto 0);
    m_axis_tvalid_out   : out std_logic;
    m_axis_tlast_out    : out std_logic;
    --------------------------------------------------------
    false_carrier_out   : out std_logic;
    --------------------------------------------------------
    crs_dv              : in std_logic;
    rxd                 : in std_logic_vector(1 downto 0)
  );
end entity rmii_mac_rx;

architecture rtl of rmii_mac_rx is

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type fsm_state_t is (S_WAIT_FOR_SFD,
                       S_DATA
                       );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  signal crs_dv_r           : std_logic := '0';
  signal rxd_r              : std_logic_vector(1 downto 0);

  signal byte_counter_reset : std_logic := '0';
  signal byte_counter       : unsigned(1 downto 0) := (others => '0');
  signal byte_counter_max   : std_logic := '0';

  signal rx_byte            : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_byte_valid      : std_logic := '0';
  signal rx_byte_last       : std_logic := '0';

  signal rx_byte_r          : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_byte_valid_r    : std_logic := '0';
  signal rx_byte_last_r     : std_logic := '0';

  signal fsm_state          : fsm_state_t := S_WAIT_FOR_SFD;

begin

  false_carrier_out <= '0'; -- TODO

  ----------------------------------------------------
  -- Decode RMII signals in to byte stream
  ----------------------------------------------------
  process(clk50)
  begin
    if rising_edge(clk50) then
      crs_dv_r <= crs_dv;
      rxd_r    <= rxd;
    end if;
  end process;

  process (clk50)
  begin
    if (rising_edge(clk50)) then
      if (reset = '1' or crs_dv_r = '0') then
        byte_counter_reset <= '1';
      elsif (crs_dv_r = '1' and rxd_r = "01") then
        byte_counter_reset <= '0';
      end if;
    end if;
  end process;

  process (clk50)
  begin
    if (rising_edge(clk50)) then
      if (byte_counter_reset = '1') then
          byte_counter <= to_unsigned(1,byte_counter'length);
      else
          byte_counter <= byte_counter + 1;
      end if;
    end if;
  end process;

  byte_counter_max <= '1' when (byte_counter = to_unsigned(3, byte_counter'length)) else '0';

  process (clk50)
  begin
    if (rising_edge(clk50)) then
      rx_byte <= rxd_r & rx_byte(7 downto 2);
      rx_byte_last <= crs_dv_r and not crs_dv;
    end if;
  end process;

  process (clk50)
  begin
    if (rising_edge(clk50)) then
      if (reset = '1') then
        rx_byte_valid <= '0';
      else
        rx_byte_valid <= byte_counter_max and crs_dv_r;
      end if;
    end if;
  end process;

  ----------------------------------------------------
  -- Strip preamble and SFD
  ----------------------------------------------------
  process(clk50)
  begin
    if rising_edge(clk50) then

      case fsm_state is

        when S_WAIT_FOR_SFD => 

          rx_byte_r <= (others => '0');
          rx_byte_valid_r <= '0';
          rx_byte_last_r  <= '0';

          if rx_byte_valid = '1' and rx_byte = x"d5" then
            fsm_state <= S_DATA;
          end if;

        when S_DATA => 
          rx_byte_r       <= rx_byte;
          rx_byte_valid_r <= rx_byte_valid;
          rx_byte_last_r  <= rx_byte_last;

          if rx_byte_valid = '1' and rx_byte_last = '1' then
            fsm_state <= S_WAIT_FOR_SFD;
          end if;
      
        end case;

      if reset = '1' then
        fsm_state       <= S_WAIT_FOR_SFD;
        rx_byte_r       <= (others => '0');
        rx_byte_valid_r <= '0';
        rx_byte_last_r  <= '0';
      end if;

    end if;
  end process;
  
  
  ----------------------------------------------------
  -- Output reg
  ----------------------------------------------------
  process(clk50)
  begin
    if rising_edge(clk50) then

      m_axis_tdata_out  <= rx_byte_r;
      m_axis_tvalid_out <= rx_byte_valid_r;
      m_axis_tlast_out  <= rx_byte_last_r;

      if reset = '1' then
        m_axis_tdata_out  <= (others => '0');
        m_axis_tvalid_out <= '0';
        m_axis_tlast_out  <= '0';
      end if;

    end if;
  end process;

end architecture;