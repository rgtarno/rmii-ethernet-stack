library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- https://wiki.wireshark.org/Development/LibpcapFileFormat

entity pcap_file_writer is
  generic (
    G_LINK_TYPE         : natural;
    G_DATA_WIDTH_BYTES  : natural;
    G_FILENAME          : string
  );
  port (
    clk                : in std_logic;
    clk_en             : in std_logic;

    s_axis_tdata_in    : in std_logic_vector((G_DATA_WIDTH_BYTES*8)-1 downto 0);
    s_axis_tvalid_in   : in std_logic;
    s_axis_tlast_in    : in std_logic;
    s_axis_tready_out  : out std_logic;

    finish_in          : in std_logic
  );
end entity pcap_file_writer;

architecture rtl of pcap_file_writer is

  alias t_octet is character;
  type t_octet_file is file of t_octet;
  type octet_vector is array (natural range <>) of t_octet;
  type data_array_t is array(natural range <>) of std_logic_vector(s_axis_tdata_in'range);
  
  signal pkt_num        : natural := 0;

begin

  process
    file file_out           : t_octet_file open write_mode is G_FILENAME;

    variable u32_buffer     : unsigned(31 downto 0);
    variable end_of_packet  : boolean := false;
    variable index          : natural := 0;
    variable packet_buffer  : data_array_t(2048-1 downto 0);

  begin

    -- Magic BE
    write(file_out, t_octet'val(16#a1#));
    write(file_out, t_octet'val(16#b2#));
    write(file_out, t_octet'val(16#c3#));
    write(file_out, t_octet'val(16#d4#));

    -- Major
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#02#));
    -- Minor
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#04#));
    -- TZ
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    -- Sigfigs
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    -- Snaplen
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#FF#));
    write(file_out, t_octet'val(16#FF#));
    -- Link type
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(16#00#));
    write(file_out, t_octet'val(G_LINK_TYPE));

    while finish_in = '0' loop


      while (end_of_packet /= true) and (finish_in = '0') loop

        wait until rising_edge(clk) and s_axis_tvalid_in = '1' and clk_en = '1';
        packet_buffer(index) := s_axis_tdata_in;
        index := index + 1;

        if s_axis_tlast_in = '1' then
          end_of_packet := true;
        else
          end_of_packet := false;
        end if;

      end loop;

      u32_buffer := to_unsigned(index, 32);
      end_of_packet := false;

      -- TS
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(pkt_num));

      -- TS us
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(16#00#));
      write(file_out, t_octet'val(16#00#));

      -- Len
      write(file_out, t_octet'val(to_integer(u32_buffer(31 downto 24))));
      write(file_out, t_octet'val(to_integer(u32_buffer(23 downto 16))));
      write(file_out, t_octet'val(to_integer(u32_buffer(15 downto 8))));
      write(file_out, t_octet'val(to_integer(u32_buffer(7 downto 0))));

      -- Len
      write(file_out, t_octet'val(to_integer(u32_buffer(31 downto 24))));
      write(file_out, t_octet'val(to_integer(u32_buffer(23 downto 16))));
      write(file_out, t_octet'val(to_integer(u32_buffer(15 downto 8))));
      write(file_out, t_octet'val(to_integer(u32_buffer(7 downto 0))));    

      for i in 0 to index-1 loop
        write(file_out, t_octet'val(to_integer(unsigned(packet_buffer(i)))));
      end loop;

      index := 0;
      pkt_num <= pkt_num + 1;

    end loop;

    file_close(file_out);

    wait;


  end process;



end architecture;