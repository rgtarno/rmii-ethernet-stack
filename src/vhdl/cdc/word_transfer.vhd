library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- Transfer multiple bits between clock domains
-- This is based on the Sunburst Design paper "", section 5.6.2 "Closed loop MCP formulation with feedback"
-- http://www.sunburst-design.com/papers/CummingsSNUG2008Boston_CDC.pdf
-- NOTE: clk_b side is expected to be always ready to receive

entity word_transfer is
  generic (
    G_DATA_WIDTH : natural
  );
  port (
    clk_a              : in std_logic;
    clk_b              : in std_logic;

    data_in_a         : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
    valid_in_a        : in std_logic;
    ready_out_a       : out std_logic;

    data_out_b        : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
    valid_out_b       : out std_logic
  );
end entity word_transfer;


architecture rtl of word_transfer is

  signal data_in_a_r    : std_logic_vector(data_in_a'range);
  signal valid_in_a_r   : std_logic := '0';

  signal ready          : std_logic;

  signal ack_a          : std_logic := '0';
  signal en_a           : std_logic := '0';

  signal ack_b          : std_logic := '0';
  signal en_b           : std_logic := '0';
  signal data_b         : std_logic_vector(data_in_a'range);
  signal valid_b        : std_logic := '0';


begin

  ----------------------------------------------------
  -- Generate upstream ready signal in clk_a domain
  -- and generate the send signal "en_a"
  ----------------------------------------------------
  ready_out_a <= ready;
  ready <= not valid_in_a_r;

  p_a_send : process(clk_a)
  begin
    if rising_edge(clk_a) then

      if ready = '1' then
        data_in_a_r   <= data_in_a;
        valid_in_a_r  <= valid_in_a;
      end if;

      if ack_a = '1' then
        valid_in_a_r <= '0';
      end if;

      en_a <= en_a xor (ready and valid_in_a);

    end if;
  end process;

  ----------------------------------------------------
  -- Send the transmit signal to clk_b domain
  ----------------------------------------------------
  i_en_a_sync : entity work.sync_pulse_gen
  port map (
    clk         => clk_b,
    din         => en_a,
    dout        => ack_b,
    pulse       => en_b
  );

  ----------------------------------------------------
  -- Sample the multi cycle data word
  -- The data has been stable for multiple clock cycles by the time we sample it
  -- So there is low chance of meta-stability
  ----------------------------------------------------
  p_b_receive : process(clk_b)
  begin
    if rising_edge(clk_b) then
      valid_b <= en_b;

      if en_b = '1' then
        data_b <= data_in_a_r;
      end if;

    end if;
  end process;

  data_out_b  <= data_b;
  valid_out_b <= valid_b;

  ----------------------------------------------------
  -- Send back the acknowledgement to the clk_a domain
  ----------------------------------------------------
  i_ack_b_sync : entity work.sync_pulse_gen
  port map (
    clk         => clk_a,
    din         => ack_b,
    dout        => open,
    pulse       => ack_a
  );

end architecture;
