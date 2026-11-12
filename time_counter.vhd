-- time_counter.vhd
-- Owner: Timekeeping Core
--
-- BCD time-of-day counter, 24-hour, HH:MM:SS. Advances one second per tick.
-- Rolls over 23:59:59 -> 00:00:00.
--
-- This module does NOT validate BCD. alarm_clock_io only asserts a load
-- signal when load_data has already been checked.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity time_counter is
	port (
		clock       : in  std_logic;
		resetn      : in  std_logic;
		tick        : in  std_logic;                      -- one-cycle enable from clock_divider
		load_hhmm   : in  std_logic;                      -- one-cycle pulse: HHMM <= load_data, seconds <= 00
		load_sec    : in  std_logic;                      -- one-cycle pulse: seconds <= load_data(7 downto 0)
		load_data   : in  std_logic_vector(15 downto 0);
		hhmm        : out std_logic_vector(15 downto 0);  -- BCD, e.g. x"1730"
		seconds     : out std_logic_vector(7 downto 0);   -- BCD, x"00" to x"59"
		minute_tick : out std_logic                       -- one-cycle pulse when seconds roll 59 -> 00
	);
end time_counter;

architecture rtl of time_counter is
begin

	-- TODO: six BCD digit registers (H tens, H ones, M tens, M ones, S tens, S ones).
	-- TODO: on tick, increment seconds with carry into minutes and hours.
	--       Watch the hours digit: it wraps at 23, not 29 or 99.
	-- TODO: load_hhmm and load_sec take priority over tick in the same cycle.
	-- TODO: minute_tick must pulse ONLY on a natural 59 -> 00 rollover, never
	--       on a load. alarm_ctrl relies on this so that setting the time
	--       directly to the alarm time does not fire the alarm.
	-- TODO: reset value is 00:00:00.

	-- Safe defaults so the project compiles; remove when implemented.
	hhmm        <= (others => '0');
	seconds     <= (others => '0');
	minute_tick <= '0';

end rtl;
