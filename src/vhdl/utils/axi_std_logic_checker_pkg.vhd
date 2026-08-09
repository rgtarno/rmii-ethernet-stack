-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2024, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.com_pkg.send;
use vunit_lib.com_types_pkg.all;
use vunit_lib.signal_checker_pkg.all;

package axi_std_logic_checker_pkg is

  procedure axi_expect(signal net : inout network_t;
                        signal_checker : signal_checker_t;
                        tdata : std_logic_vector;
                        tuser : std_logic_vector;
                        tlast : std_logic);


end package;


package body axi_std_logic_checker_pkg is

  procedure axi_expect(signal net : inout network_t;
                        signal_checker : signal_checker_t;
                        tdata : std_logic_vector;
                        tuser : std_logic_vector;
                        tlast : std_logic) is
    variable request_msg : msg_t := new_msg(expect_msg);
  begin
    push_std_ulogic_vector(request_msg, tdata);
    push_std_ulogic_vector(request_msg, tuser);
    push_std_ulogic(request_msg, tlast);
    send(net, signal_checker.p_actor, request_msg);
  end;

end package body;
