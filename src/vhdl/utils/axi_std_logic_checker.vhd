-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.com_pkg.net;
use vunit_lib.com_pkg.receive;
use vunit_lib.com_pkg.reply;
use vunit_lib.com_types_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.signal_checker_pkg.all;
use vunit_lib.sync_pkg.wait_until_idle_msg;
use vunit_lib.sync_pkg.wait_until_idle_reply_msg;

entity axi_std_logic_checker is
  generic (
    check_tuser    : boolean;
    signal_checker : signal_checker_t
  );
  port (
    clk      : in std_logic;
    tvalid   : in std_logic;
    tdata    : in std_logic_vector;
    tuser    : in std_logic_vector;
    tlast    : in std_logic
  );
end entity;


architecture a of axi_std_logic_checker is
  constant expect_queue : queue_t := new_queue;
begin

  main : process
    variable request_msg : msg_t;
    variable reply_msg : msg_t;
    variable msg_type : msg_type_t;
  begin
    receive(net, signal_checker.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = expect_msg then
      push_std_ulogic_vector(expect_queue, pop_std_ulogic_vector(request_msg)); -- tdata
      push_std_ulogic_vector(expect_queue, pop_std_ulogic_vector(request_msg)); -- tuser
      push_std_ulogic(expect_queue, pop_std_ulogic(request_msg)); -- tvalid

    elsif msg_type = wait_until_idle_msg then

      while not is_empty(expect_queue) loop
        if tvalid'event then
          wait for 0 ns;
        else
          wait until rising_edge(clk);
        end if;
      end loop;

      reply_msg := new_msg(wait_until_idle_reply_msg);
      reply(net, request_msg, reply_msg);
    else
      unexpected_msg_type(msg_type);
    end if;

    delete(request_msg);
  end process;

  monitor : process
    variable expected_tdata : std_logic_vector(tdata'range);
    variable expected_tuser : std_logic_vector(tuser'range);
    variable expected_tlast : std_logic;
  begin
    wait until rising_edge(clk) and tvalid = '1';

    if is_empty(expect_queue) then
      error(signal_checker.p_logger, "Unexpected event with value = " & to_string(tdata));
    else
      expected_tdata := pop_std_ulogic_vector(expect_queue);
      expected_tuser := pop_std_ulogic_vector(expect_queue);
      expected_tlast := pop_std_ulogic(expect_queue);

      if tdata /= expected_tdata then
        error(signal_checker.p_logger, "Got word with wrong value, got " & to_string(tdata) &
              " expected " & to_string(expected_tdata));

      elsif check_tuser and (tuser /= expected_tuser) then
        error(signal_checker.p_logger, "Got word with wrong tuser, got " & to_string(tuser) &
              " expected " & to_string(expected_tuser));

      elsif tlast /= expected_tlast then
        error(signal_checker.p_logger, "Got word with wrong tlast, got " & to_string(tlast) &
              " expected " & to_string(expected_tlast) & " for word " & to_string(expected_tdata));

      else
        pass(signal_checker.p_logger, "Got expected event with value = " & to_string(tdata));
      end if;
    end if;
  end process;
end architecture;
