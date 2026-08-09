library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.apb_data_types.all;

-- Converts APB signals in to a generic read / write register interface
-- See https://support.arm.com/documentation/ihi0024/e/


entity component_register_block is
  generic (
    G_NUM_REGISTERS : natural := 8
  );
  port (
    clk              : in std_logic;
    --------------------------------------------------
    apb_cmd_in       : in apb_cmd_t;
    apb_rsp_out      : out apb_rsp_t := apb_rsp_0;
    --------------------------------------------------
    reg_rdata_in     : in slv32_array_t(G_NUM_REGISTERS-1 downto 0);
    reg_wdata_out    : out slv32_array_t(G_NUM_REGISTERS-1 downto 0);
    reg_ren_out      : out std_logic_vector(G_NUM_REGISTERS-1 downto 0) := (others => '0');
    reg_wen_out      : out std_logic_vector(G_NUM_REGISTERS-1 downto 0) := (others => '0')
  );
end entity component_register_block;

architecture rtl of component_register_block is

  constant C_LOG2_NUM_REGISTERS : natural := log2_ceil(G_NUM_REGISTERS);

  signal reg_select_int : integer range 0 to G_NUM_REGISTERS-1;
  signal reg_sel        : std_logic_vector(G_NUM_REGISTERS-1 downto 0) := (others => '0');
  signal reg_ren_sig    : std_logic_vector(G_NUM_REGISTERS-1 downto 0) := (others => '0');

  signal pready      : std_logic := '1';
  signal pready_r    : std_logic := '1';

begin

  reg_select_int <= to_integer(unsigned(apb_cmd_in.paddr(C_LOG2_NUM_REGISTERS-1 downto 0)));

  apb_rsp_out.pready  <= pready_r;

  process(clk)
  begin

    if rising_edge(clk) then
      apb_rsp_out.pslverr <= '0';
      pready              <= '1';
      pready_r            <= pready;

      -- Stall ready for read operations so that the read-enable signal can be aligned with the acutal read
      -- From the components point of view, ren is like an ACK.
      if apb_cmd_in.psel = '1' and apb_cmd_in.penable = '0' and apb_cmd_in.pwrite = '0' then
        pready   <= '0';
        pready_r <= '0';
      end if;

      reg_sel                 <= (others => '0');
      reg_sel(reg_select_int) <= '1';

     end if;
    
  end process;

  -- Read data
  process(clk)
  begin
    if rising_edge(clk) then
      for i in 0 to G_NUM_REGISTERS-1 loop
        if reg_ren_sig(i) = '1' then
          apb_rsp_out.prdata <= reg_rdata_in(i);
        end if;
      end loop;
    end if;
  end process;

  g_write_data : for i in 0 to G_NUM_REGISTERS-1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if apb_cmd_in.psel = '1' and apb_cmd_in.penable = '1' then
          if apb_cmd_in.pwrite = '1' and reg_sel(i) = '1' then
            reg_wdata_out(i) <= apb_cmd_in.pwdata;
          end if;
        end if;
      end if;
    end process;
  end generate;

  g_write_enable : for i in 0 to G_NUM_REGISTERS-1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        reg_wen_out(i)   <= '0';
        if apb_cmd_in.psel = '1' and apb_cmd_in.penable = '1' and apb_cmd_in.pwrite = '1' then
          reg_wen_out(i)   <= reg_sel(i);
        end if;
      end if;
    end process;
  end generate;

  g_read_enable : for i in 0 to G_NUM_REGISTERS-1 generate
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        reg_ren_sig(i)   <= '0';
        if apb_cmd_in.psel = '1' and pready = '0' and pready_r = '0' and apb_cmd_in.pwrite = '0' then
          reg_ren_sig(i)   <= reg_sel(i);
        end if;
      end if;
    end process;
  end generate;

  reg_ren_out <= reg_ren_sig;

end architecture;