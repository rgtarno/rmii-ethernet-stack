library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity afifo is
  generic (
    G_DATA_WIDTH     : natural := 8;
    G_LOG2_DEPTH     : natural := 9;
    G_FWFT           : boolean := false
  );
  port (
    wr_clk           : in std_logic;
    reset            : in std_logic;
    reset_busy       : out std_logic;
    write_data       : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    write_en         : in  std_logic;
    full             : out std_logic;
    --------------------------------------------------
    rd_clk           : in std_logic;
    read_data        : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    read_en          : in  std_logic;
    empty            : out std_logic
  );
end entity afifo;

architecture rtl of afifo is

  ----------------------------------------------------
  -- TYPES
  ----------------------------------------------------
  type reset_state_t is (S_IDLE,
                         S_WAIT_FOR_RESET_DONE
                        );

  ----------------------------------------------------
  -- SIGNALS
  ----------------------------------------------------

  -- Read clock domain
  signal read_gray_pointer_rd_clk   : std_logic_vector(G_LOG2_DEPTH downto 0) := (others => '0');
  signal write_gray_pointer_rd_clk  : std_logic_vector(G_LOG2_DEPTH downto 0) := (others => '0');
  signal read_addr_rd_clk           : std_logic_vector(G_LOG2_DEPTH-1 downto 0) := (others => '0');
  signal read_reset                 : std_logic := '0';
  signal fifo_empty                 : std_logic := '0';
  signal fifo_q                     : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
  signal read_en_internal           : std_logic := '0';


  -- Write clock domain
  signal read_gray_pointer_wr_clk    : std_logic_vector(G_LOG2_DEPTH downto 0) := (others => '0');
  signal write_gray_pointer_wr_clk   : std_logic_vector(G_LOG2_DEPTH downto 0) := (others => '0');
  signal write_addr_wr_clk           : std_logic_vector(G_LOG2_DEPTH-1 downto 0) := (others => '0');
  signal write_en_wr_clk             : std_logic := '0';
  signal full_wr_clk                 : std_logic := '0';

  signal reset_state : reset_state_t := S_IDLE;
  signal reset_to_read               : std_logic := '0';
  signal read_reset_done             : std_logic := '0';
  signal reset_busy_sig              : std_logic := '0';


begin

  ----------------------------------------------------
  -- Dual port ram
  ----------------------------------------------------
  i_sdp_ram : entity work.sdp_ram
    generic map (
      G_DATA_WIDTH  => G_DATA_WIDTH,
      G_ADDR_WIDTH  => G_LOG2_DEPTH
    )
    port map (
      -- Port A
      clk_a     => wr_clk,
      clk_en_a  => write_en_wr_clk,
      addr_a    => write_addr_wr_clk,
      din_a     => write_data,
      -- Port B
      clk_b     => rd_clk,
      clk_en_b  => read_en_internal,
      addr_b    => read_addr_rd_clk,
      dout_b    => fifo_q
    );


  ----------------------------------------------------
  -- Read & empty logic
  ----------------------------------------------------
  i_afifo_read_logic : entity work.afifo_read_logic
    generic map (
      G_DATA_WIDTH        => G_DATA_WIDTH,
      G_ADDR_WIDTH        => G_LOG2_DEPTH
    )
    port map (
      rd_clk              => rd_clk,
      reset               => read_reset,
      read_en_in          => read_en_internal,
      empty_out           => fifo_empty,
      write_pointer_in    => write_gray_pointer_rd_clk,
      read_addr_out       => read_addr_rd_clk,
      read_pointer_out    => read_gray_pointer_rd_clk
    );

  ----------------------------------------------------
  -- FWFT
  ----------------------------------------------------
  gen_fwft : if G_FWFT = true generate
  begin
    i_afifo_fwft : entity work.fifo_fwft
    generic map (
      G_DATA_WIDTH     => G_DATA_WIDTH
    )
    port map (
      rd_clk           => rd_clk,
      reset            => read_reset,
      fifo_q           => fifo_q,
      data_out         => read_data,
      read_en_in       => read_en,
      fifo_read_en_out => read_en_internal,
      fifo_empty_in    => fifo_empty,
      empty_out        => empty
    );
  end generate;

  gen_no_fwft : if G_FWFT = false generate
  begin
    read_en_internal <= read_en and not fifo_empty; -- Prevent underflows
    read_data        <= fifo_q;
    empty            <= fifo_empty;
  end generate;
  ----------------------------------------------------
  -- Synchronise read pointer in to the write clock domain
  ----------------------------------------------------
  i_read_ptr_sync : entity work.grey_pointer_sync
    generic map (
      G_ADDR_WIDTH  => G_LOG2_DEPTH
    )
    port map (
      clk       => wr_clk,
      reset     => reset,
      --------------------------------------------------------
      din       => read_gray_pointer_rd_clk,
      --------------------------------------------------------
      dout      => read_gray_pointer_wr_clk
    );

  ----------------------------------------------------
  -- Write & full logic
  ----------------------------------------------------
  i_afifo_write_logic : entity work.afifo_write_logic
    generic map (
      G_DATA_WIDTH        => G_DATA_WIDTH,
      G_ADDR_WIDTH        => G_LOG2_DEPTH
    )
    port map(
      wr_clk              => wr_clk,
      reset               => reset,
      write_en_in         => write_en,
      full_out            => full_wr_clk,
      read_pointer_in     => read_gray_pointer_wr_clk,
      write_addr_out      => write_addr_wr_clk,
      write_pointer_out   => write_gray_pointer_wr_clk
    );

    write_en_wr_clk <= '0' when reset_busy_sig = '1' else
                      write_en when full_wr_clk = '0' else
                      '0';

    full <= full_wr_clk;  
  ----------------------------------------------------
  -- Synchronise write pointer in to the read clock domain
  ----------------------------------------------------
  i_write_ptr_sync : entity work.grey_pointer_sync
    generic map (
      G_ADDR_WIDTH  => G_LOG2_DEPTH
    )
    port map (
      clk       => rd_clk,
      reset     => read_reset,
      --------------------------------------------------------
      din       => write_gray_pointer_wr_clk,
      --------------------------------------------------------
      dout      => write_gray_pointer_rd_clk
    );

  ----------------------------------------------------
  -- Reset in to the component is in the write clock domain
  -- We synchronise it in to the read clock domain and back in to
  -- the write clock to tell us once it has been received in the read clock domain.
  -- reset_busy is asserted during this.
  ----------------------------------------------------
  i_reset_to_read_sync : entity work.bit_synchroniser
    port map(
      clk                => rd_clk,
      async_in           => reset_to_read,
      sync_out           => read_reset
    );

  i_read_reset_done : entity work.bit_synchroniser
    port map(
      clk                => wr_clk,
      async_in           => read_reset,
      sync_out           => read_reset_done
    );

    process(wr_clk)
    begin
      if rising_edge(wr_clk) then

        case reset_state is

          when S_IDLE =>
            reset_busy_sig    <= '0';
            reset_to_read     <= '0';
            if reset = '1' then
              reset_to_read     <= '1';
              reset_busy_sig    <= '1';
              reset_state       <= S_WAIT_FOR_RESET_DONE;
            end if;

          when S_WAIT_FOR_RESET_DONE =>
            reset_to_read     <= '1';
            reset_busy_sig    <= '1';
            if read_reset_done = '1' then
              reset_to_read     <= '0';
              reset_busy_sig    <= '0';
              reset_state       <= S_IDLE;
            end if;
  
        end case;

      end if;
    end process;

    reset_busy <= reset_busy_sig;

end architecture;
