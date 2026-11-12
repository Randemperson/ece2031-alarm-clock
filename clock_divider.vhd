-- clock_divider.vhd
-- Owner: Timekeeping Core
--
-- Turns the board clock into a one-clock-wide "tick" enable pulse.
--   fast = '0' : 1 tick per second
--   fast = '1' : 60 ticks per second (one simulated minute per real second)
--
-- "tick" is an ENABLE, not a clock. Every other module stays on "clock" and
-- does:  if rising_edge(clock) then if tick = '1' then ...

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
	generic (
		CLK_HZ : positive := 10_000_000  -- clk_10MHz in the Lab 8 base; the testbench overrides this
	);
	port (
		clock  : in  std_logic;
		resetn : in  std_logic;  -- active low, asynchronous (same as SCOMP)
		fast   : in  std_logic;
		tick   : out std_logic
	);
end clock_divider;

architecture rtl of clock_divider is
begin

	-- TODO: count clock cycles from 0 to (CLK_HZ - 1) and pulse tick for one
	--       cycle on wrap. When fast = '1', wrap at (CLK_HZ / 60) - 1 instead.
	-- TODO (decision pending): CLK_HZ / 60 is not an integer at 10 MHz.
	--       Is the small error acceptable, or do we pick another fast ratio?
	-- TODO (decision pending): should writing TIME restart this counter so the
	--       first second after a time-set is a full second? Needs a new input.
	-- TODO: decide what happens to the count when fast changes mid-second.

	tick <= '0';  -- safe default so the project compiles; remove when implemented

end rtl;
