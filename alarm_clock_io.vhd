-- alarm_clock_io.vhd
-- Owner: Bus Interface & Integration
--
-- The SCOMP-facing alarm clock peripheral. This is the block that goes on the
-- top-level schematic. Bus ports copy TIMER.vhd from the Lab 8 base project.
--
--   BASE+0  TIME      BASE+2  ALARM
--   BASE+1  SECONDS   BASE+3  CTRL (write) / STATUS (read)
--
-- Bus timing, taken from SCOMP.vhd (assumes CLOCK is the same clk_10MHz that
-- SCOMP runs on):
--   OUT: IO_WRITE is high for exactly one clock cycle with IO_ADDR and
--        IO_DATA valid. Sample it with a plain synchronous
--        "if IO_WRITE = '1'" -- no edge detector, no rising_edge(IO_WRITE).
--   IN:  IO_READ is high for one cycle and SCOMP latches IO_DATA at the end
--        of that same cycle, so read data must be driven COMBINATIONALLY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_clock_io is
	generic (
		CLK_HZ    : positive := 10_000_000;
		-- TODO: placeholder (0x0A0). Must be a multiple of 4 and not collide
		--       with 0x000-0x005, which the base project already uses.
		BASE_ADDR : std_logic_vector(10 downto 0) := "00010100000"
	);
	port (
		CLOCK    : in    std_logic;
		RESETN   : in    std_logic;
		IO_ADDR  : in    std_logic_vector(10 downto 0);
		IO_READ  : in    std_logic;
		IO_WRITE : in    std_logic;
		IO_DATA  : inout std_logic_vector(15 downto 0);
		RINGING  : out   std_logic  -- wire to an LED (or buzzer pin) on the top level
	);
end alarm_clock_io;

architecture rtl of alarm_clock_io is

	signal tick, minute_tick      : std_logic;
	signal hhmm, alarm_hhmm       : std_logic_vector(15 downto 0);
	signal seconds                : std_logic_vector(7 downto 0);
	signal ring_i, snoozed        : std_logic;

	-- Driven by the TODO logic below; constants for now so the stub compiles.
	signal load_hhmm, load_sec    : std_logic := '0';
	signal load_alarm             : std_logic := '0';
	signal ack, snooze            : std_logic := '0';
	signal en_reg, fast_reg       : std_logic := '0';

begin

	-- TODO: chip select = IO_ADDR(10 downto 2) matches BASE_ADDR(10 downto 2);
	--       IO_ADDR(1 downto 0) picks the register.
	-- TODO: BCD validation of IO_DATA on writes to TIME, SECONDS, and ALARM.
	--       Invalid writes are ignored and set a sticky INVALID flag.
	--       (decision pending: what clears INVALID?)
	-- TODO: one clocked process that, on a selected IO_WRITE:
	--         TIME    -> pulse load_hhmm       ALARM -> pulse load_alarm
	--         SECONDS -> pulse load_sec
	--         CTRL    -> en_reg <= bit 0, fast_reg <= bit 1,
	--                    pulse ack if bit 2, pulse snooze if bit 3
	--       Pulses must be exactly one clock cycle wide.
	-- TODO: combinational read mux on IO_ADDR(1 downto 0), then replace the
	--       IO_DATA line below with:
	--         IO_DATA <= read_data when (selected and IO_READ = '1') else (others => 'Z');
	--       (TIMER.vhd does the same thing with lpm_bustri; either is fine.)
	-- TODO (decision pending): reading TIME then SECONDS takes two INs and can
	--       straddle a rollover. Snapshot seconds when TIME is read?

	IO_DATA <= (others => 'Z');  -- never drive the bus until the read logic exists
	RINGING <= ring_i;

	u_div : entity work.clock_divider
		generic map (CLK_HZ => CLK_HZ)
		port map (clock => CLOCK, resetn => RESETN, fast => fast_reg, tick => tick);

	u_time : entity work.time_counter
		port map (
			clock => CLOCK, resetn => RESETN, tick => tick,
			load_hhmm => load_hhmm, load_sec => load_sec, load_data => IO_DATA,
			hhmm => hhmm, seconds => seconds, minute_tick => minute_tick
		);

	u_alarm : entity work.alarm_ctrl
		port map (
			clock => CLOCK, resetn => RESETN, tick => tick, minute_tick => minute_tick,
			hhmm => hhmm, load_alarm => load_alarm, load_data => IO_DATA,
			time_set => load_hhmm, en => en_reg, ack => ack, snooze => snooze,
			alarm_hhmm => alarm_hhmm, ringing => ring_i, snoozed => snoozed
		);

end rtl;
