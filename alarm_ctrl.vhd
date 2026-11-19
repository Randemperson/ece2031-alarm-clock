-- alarm_ctrl.vhd
-- Owner: Alarm Logic
--
-- ONE alarm: holds the alarm time (HHMM and seconds), compares it against the
-- current time, and runs the ringing state machine. alarm_clock_io creates
-- one copy of this module per alarm (5 alarms), so this file only ever deals
-- with a single alarm.
--
--   IDLE    --(en = '1' and time ticks into hhmm:seconds = alarm)-->  RINGING
--   RINGING --(ack, or 60 s timeout)-->                                IDLE
--   RINGING --(snooze)-->                                              SNOOZED
--   SNOOZED --(5 minutes later)-->                                     RINGING
--
-- en  = global EN (Global Control b0) AND this alarm's EN (Alarm Settings b0).
-- ack = global RESET (Global Control b1) OR this alarm's RESET (Alarm Settings
--       b1 while this alarm is selected).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_ctrl is
	port (
		clock          : in  std_logic;
		resetn         : in  std_logic;
		tick           : in  std_logic;                      -- one pulse per (simulated) second
		minute_tick    : in  std_logic;                      -- one pulse per natural minute rollover
		hhmm           : in  std_logic_vector(15 downto 0);  -- current time from time_counter
		seconds        : in  std_logic_vector(7 downto 0);   -- current seconds from time_counter
		load_alarm     : in  std_logic;                      -- one-cycle pulse: alarm HHMM <= load_data (already validated)
		load_alarm_sec : in  std_logic;                      -- one-cycle pulse: alarm seconds <= load_data(7 downto 0) (already validated)
		load_data      : in  std_logic_vector(15 downto 0);
		time_set       : in  std_logic;                      -- one-cycle pulse: SCOMP just wrote TIME
		en             : in  std_logic;                      -- level: global EN and this alarm's EN
		ack            : in  std_logic;                      -- one-cycle pulse: stop ringing
		snooze         : in  std_logic;                      -- one-cycle pulse (tied to '0': no SNOOZE bit in the map)
		alarm_hhmm     : out std_logic_vector(15 downto 0);
		alarm_sec      : out std_logic_vector(7 downto 0);
		ringing        : out std_logic;
		snoozed        : out std_logic
	);
end alarm_ctrl;

architecture rtl of alarm_ctrl is
begin

	-- TODO: alarm HHMM register (load_alarm) and alarm seconds register
	--       (load_alarm_sec). Reset value pending (0x0000 / 0x00?).
	-- TODO: fire condition. The alarm now matches on hours, minutes AND
	--       seconds. Fire when en = '1' and the time TICKS INTO a match, so
	--       writing TIME to the alarm time does not fire it. Check with the
	--       Timekeeping owner whether hhmm/seconds already show the new value
	--       in the cycle tick is high, or one cycle later.
	-- TODO: state machine above, with a 60-tick timeout counter in RINGING.
	-- TODO (decision pending): the timeout counts ticks, so in fast mode a
	--       ring lasts only 1 real second. Is that what we want for the demo?
	-- TODO (extension): snooze. Counting 5 minute_ticks is much less hardware
	--       than doing BCD "alarm + 5 minutes" with wraparound past midnight.
	-- TODO (decision pending): what do time_set, load_alarm, and en = '0' do
	--       while RINGING or SNOOZED? ack/snooze when not ringing are ignored.

	-- Safe defaults so the project compiles; remove when implemented.
	alarm_hhmm <= (others => '0');
	alarm_sec  <= (others => '0');
	ringing    <= '0';
	snoozed    <= '0';

end rtl;
