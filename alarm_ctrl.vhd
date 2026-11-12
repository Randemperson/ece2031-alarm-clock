-- alarm_ctrl.vhd
-- Owner: Alarm Logic
--
-- Holds the alarm time, compares it against the current time, and runs the
-- ringing state machine.
--
--   IDLE    --(en = '1' and minute_tick and hhmm = alarm)-->  RINGING
--   RINGING --(ack, or 60 s timeout)-->                       IDLE
--   RINGING --(snooze)-->                                     SNOOZED
--   SNOOZED --(5 minutes later)-->                            RINGING

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_ctrl is
	port (
		clock       : in  std_logic;
		resetn      : in  std_logic;
		tick        : in  std_logic;                      -- one pulse per (simulated) second
		minute_tick : in  std_logic;                      -- one pulse per natural minute rollover
		hhmm        : in  std_logic_vector(15 downto 0);  -- current time from time_counter
		load_alarm  : in  std_logic;                      -- one-cycle pulse: alarm <= load_data (already validated)
		load_data   : in  std_logic_vector(15 downto 0);
		time_set    : in  std_logic;                      -- one-cycle pulse: SCOMP just wrote TIME
		en          : in  std_logic;                      -- level, from CTRL bit 0
		ack         : in  std_logic;                      -- one-cycle pulse, from CTRL bit 2
		snooze      : in  std_logic;                      -- one-cycle pulse, from CTRL bit 3
		alarm_hhmm  : out std_logic_vector(15 downto 0);
		ringing     : out std_logic;
		snoozed     : out std_logic
	);
end alarm_ctrl;

architecture rtl of alarm_ctrl is
begin

	-- TODO: alarm register, loaded on load_alarm. Reset value pending.
	-- TODO: fire condition. minute_tick and the new hhmm must line up: check
	--       with the Timekeeping owner whether hhmm already shows the new
	--       minute in the cycle minute_tick is high, or one cycle later.
	-- TODO: state machine above, with a 60-tick timeout counter in RINGING.
	-- TODO (decision pending): the timeout counts ticks, so in fast mode a
	--       ring lasts only 1 real second. Is that what we want for the demo?
	-- TODO (extension): snooze. Counting 5 minute_ticks is much less hardware
	--       than doing BCD "alarm + 5 minutes" with wraparound past midnight.
	-- TODO (decision pending): what do time_set, load_alarm, and en = '0' do
	--       while RINGING or SNOOZED? ack/snooze when not ringing are ignored.

	-- Safe defaults so the project compiles; remove when implemented.
	alarm_hhmm <= (others => '0');
	ringing    <= '0';
	snoozed    <= '0';

end rtl;
