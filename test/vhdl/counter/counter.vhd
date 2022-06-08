-- Copyright (C) 2020-2022 F4PGA Authors.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

library ieee;
context ieee.ieee_std_context;

entity Arty_Counter is
  port (
    CLK : in  std_logic;
    LEDs : out std_logic_vector(3 downto 0)
  );
end;

architecture arch of Arty_Counter is

  constant LOG2DELAY : natural := 22;

  signal counter : unsigned(LEDs'length+LOG2DELAY-1 downto 0) := (others=>'0');

begin

  process (CLK) begin
    counter <= counter + 1 when rising_edge(CLK);
  end process;

  LEDs <= std_logic_vector(resize(shift_right(counter, LOG2DELAY), LEDs'length));

end;
