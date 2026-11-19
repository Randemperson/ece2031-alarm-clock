-- alarm_clock_io.vhd
-- Owner: Bus Interface & Integration (Charles)
--
-- The SCOMP-facing alarm clock peripheral. This is the block that goes on the
-- top-level schematic. Bus ports copy TIMER.vhd from the Lab 8 base project.
--
--   BASE+0  TIME       HHMM (BCD)          BASE+4  STATUS
--   BASE+1  SECONDS    00SS (BCD)          BASE+5  CONTROL
--   BASE+2  ALARM      HHMM (BCD)          BASE+6  ALARM_SEL
--   BASE+3  ALARM_SEC  00SS (BCD)          BASE+7  ALARM_SET
--
--   STATUS  read:  0 RINGING            1 ERROR (an invalid time write was ignored)
--           write: 0 RESET (1 = stop a ringing alarm, one-time)
--                  1 CLEAR_ERR (1 = clear ERROR, one-time)
--   CONTROL bits:  0 EN (global enable, level)   1 FAST (level)
--   ALARM_SEL:     bits 1-0 pick the alarm that BASE+2, BASE+3, BASE+7 refer to
--   ALARM_SET:     TBD (spec text incomplete). Writes ignored, reads 0.
--
-- Bus timing, taken from SCOMP.vhd (assumes CLOCK is the same clk_10MHz that
-- SCOMP runs on):
--   OUT: IO_WRITE is high for exactly one clock cycle with IO_ADDR and
--        IO_DATA valid. Everything that reacts to a write is either sampled
--        on the clock edge that ends that cycle, or is a combinational pulse
--        that is high only during that cycle.
--   IN:  IO_READ is high for one cycle and SCOMP latches IO_DATA at the end
--        of that same cycle, so read data is driven COMBINATIONALLY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_clock_io is
	generic (
		CLK_HZ    : positive := 10_000_000;
		-- 0x070. The course allows peripherals only at 0x070-0x07F, and the
		-- base must be a multiple of 8 (see the address decode below).
		BASE_ADDR : std_logic_vector(10 downto 0) := "00001110000"
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

	-- Register numbers: the low 3 bits of the IO address.
	constant REG_TIME      : std_logic_vector(2 downto 0) := "000";
	constant REG_SECONDS   : std_logic_vector(2 downto 0) := "001";
	constant REG_ALARM     : std_logic_vector(2 downto 0) := "010";
	constant REG_ALARM_SEC : std_logic_vector(2 downto 0) := "011";
	constant REG_STATUS    : std_logic_vector(2 downto 0) := "100";
	constant REG_CONTROL   : std_logic_vector(2 downto 0) := "101";
	constant REG_ALARM_SEL : std_logic_vector(2 downto 0) := "110";
	constant REG_ALARM_SET : std_logic_vector(2 downto 0) := "111";

	-- STATUS bit positions. Reading gives RINGING/ERROR; writing a 1 to the
	-- same bit resets the alarm / clears the error.
	constant STAT_RINGING   : natural := 0;
	constant STAT_ERROR     : natural := 1;
	constant STAT_RESET     : natural := 0;
	constant STAT_CLEAR_ERR : natural := 1;

	-- CONTROL bit positions.
	constant CTRL_ENABLE    : natural := 0;
	constant CTRL_FAST      : natural := 1;

	-- Width of ALARM_SEL (2 bits = up to 4 alarms).
	constant SEL_BITS       : natural := 2;

	-- True when d is a valid 24-hour BCD time, 0x0000 to 0x2359.
	function valid_hhmm(d : std_logic_vector(15 downto 0)) return boolean is
		variable h_tens : unsigned(3 downto 0) := unsigned(d(15 downto 12));
		variable h_ones : unsigned(3 downto 0) := unsigned(d(11 downto 8));
		variable m_tens : unsigned(3 downto 0) := unsigned(d(7 downto 4));
		variable m_ones : unsigned(3 downto 0) := unsigned(d(3 downto 0));
	begin
		return h_tens <= 2 and h_ones <= 9
		       and (h_tens < 2 or h_ones <= 3)   -- 20 to 23 only, not 24 to 29
		       and m_tens <= 5 and m_ones <= 9;
	end function;

	-- True when d is valid BCD seconds, 0x0000 to 0x0059.
	function valid_sec(d : std_logic_vector(15 downto 0)) return boolean is
		variable s_tens : unsigned(3 downto 0) := unsigned(d(7 downto 4));
		variable s_ones : unsigned(3 downto 0) := unsigned(d(3 downto 0));
	begin
		return d(15 downto 8) = x"00" and s_tens <= 5 and s_ones <= 9;
	end function;

	-- Address decode.
	signal selected : std_logic;                     -- the address is one of ours
	signal reg      : std_logic_vector(2 downto 0);  -- which register
	signal wr, rd   : std_logic;                     -- a write / read to us, this cycle

	-- Connections to the sub-modules.
	signal tick, minute_tick      : std_logic;
	signal hhmm, alarm_hhmm       : std_logic_vector(15 downto 0);
	signal seconds                : std_logic_vector(7 downto 0);
	signal ring_i, snoozed        : std_logic;
	signal load_hhmm, load_sec    : std_logic;
	signal load_alarm             : std_logic;
	signal ack, snooze            : std_logic;

	-- Registers that live in this file.
	signal en_reg, fast_reg       : std_logic;
	signal error_reg              : std_logic;
	signal alarm_sec_reg          : std_logic_vector(7 downto 0);
	signal alarm_sel_reg          : std_logic_vector(SEL_BITS-1 downto 0);

	signal read_data              : std_logic_vector(15 downto 0);
	signal drive_bus              : std_logic;

begin

	-- ------------------------------------------------------------------
	-- Address decode
	-- ------------------------------------------------------------------
	-- The upper 8 address bits pick the peripheral, the low 3 pick the
	-- register. This is why BASE_ADDR must be a multiple of 8.
	selected <= '1' when IO_ADDR(10 downto 3) = BASE_ADDR(10 downto 3) else '0';
	reg      <= IO_ADDR(2 downto 0);
	wr       <= selected and IO_WRITE;
	rd       <= selected and IO_READ;

	-- ------------------------------------------------------------------
	-- Writes: one-cycle pulses to the sub-modules
	-- ------------------------------------------------------------------
	-- These are combinational, so they are high during the same cycle that
	-- IO_WRITE is high. The sub-modules sample them (and IO_DATA, which is
	-- wired to their load_data) on the clock edge that ends that cycle.
	-- An invalid BCD value never produces a load pulse, so time_counter and
	-- alarm_ctrl can trust load_data.
	-- ("and" on booleans short-circuits, so the valid_* functions only look
	-- at IO_DATA while a write is actually happening.)
	load_hhmm  <= '1' when wr = '1' and reg = REG_TIME    and valid_hhmm(IO_DATA) else '0';
	load_sec   <= '1' when wr = '1' and reg = REG_SECONDS and valid_sec(IO_DATA)  else '0';
	load_alarm <= '1' when wr = '1' and reg = REG_ALARM   and valid_hhmm(IO_DATA) else '0';

	ack        <= '1' when wr = '1' and reg = REG_STATUS and IO_DATA(STAT_RESET) = '1' else '0';

	-- TODO: the current map has no SNOOZE bit. Tied off until we decide to use SNOOZE
	snooze     <= '0';

	-- ------------------------------------------------------------------
	-- Writes: registers that live in this file
	-- ------------------------------------------------------------------
	process (CLOCK, RESETN)
	begin
		if RESETN = '0' then
			en_reg        <= '0';
			fast_reg      <= '0';
			error_reg     <= '0';
			alarm_sec_reg <= (others => '0');
			alarm_sel_reg <= (others => '0');
		elsif rising_edge(CLOCK) then
			if wr = '1' then
				case reg is

					-- TIME, SECONDS, ALARM: the value itself is stored in a
					-- sub-module (see the load pulses above). Here we only
					-- record whether the write was rejected.
					when REG_TIME | REG_ALARM =>
						if not valid_hhmm(IO_DATA) then
							error_reg <= '1';
						end if;

					when REG_SECONDS =>
						if not valid_sec(IO_DATA) then
							error_reg <= '1';
						end if;

					when REG_ALARM_SEC =>
						if valid_sec(IO_DATA) then
							alarm_sec_reg <= IO_DATA(7 downto 0);
						else
							error_reg <= '1';
						end if;

					-- RESET is handled by the ack pulse above. CLEAR_ERR is handled here.
					when REG_STATUS =>
						if IO_DATA(STAT_CLEAR_ERR) = '1' then
							error_reg <= '0';
						end if;

					-- EN and FAST are levels: every CONTROL write sets them.
					when REG_CONTROL =>
						en_reg   <= IO_DATA(CTRL_ENABLE);
						fast_reg <= IO_DATA(CTRL_FAST);

					-- TODO (needs agreement with the Alarm Logic owner):
					--       alarm_ctrl holds only one alarm, so the selection is
					--       stored and read back but does not pick an alarm yet.
					when REG_ALARM_SEL =>
						alarm_sel_reg <= IO_DATA(SEL_BITS-1 downto 0);

					-- TODO: ALARM_SET fields are not defined yet. Writes ignored.
					when others =>
						null;

				end case;
			end if;
		end if;
	end process;

	-- ------------------------------------------------------------------
	-- Reads
	-- ------------------------------------------------------------------
	process (reg, hhmm, seconds, alarm_hhmm, alarm_sec_reg, alarm_sel_reg, ring_i, error_reg, en_reg, fast_reg)
	begin
		read_data <= (others => '0');
		case reg is
			when REG_TIME      => read_data <= hhmm;
			when REG_SECONDS   => read_data(7 downto 0) <= seconds;
			when REG_ALARM     => read_data <= alarm_hhmm;
			when REG_ALARM_SEC => read_data(7 downto 0) <= alarm_sec_reg;
			when REG_STATUS    =>
				read_data(STAT_RINGING) <= ring_i;
				read_data(STAT_ERROR)   <= error_reg;
			when REG_CONTROL   =>
				read_data(CTRL_ENABLE) <= en_reg;
				read_data(CTRL_FAST)   <= fast_reg;
			when REG_ALARM_SEL =>
				read_data(SEL_BITS-1 downto 0) <= alarm_sel_reg;
			when others        => null;   -- ALARM_SET: reads 0 until defined
		end case;
	end process;

	-- Drive the bus only while SCOMP is reading one of our eight registers.
	-- At every other time the peripheral must be disconnected ('Z'), or it
	-- would fight with SCOMP and the other devices on the shared bus.
	drive_bus <= rd;
	IO_DATA   <= read_data when drive_bus = '1' else (others => 'Z');

	RINGING <= ring_i;

	-- TODO (needs agreement with the Alarm Logic owner): alarm_sec_reg is
	--       stored and can be read back, but alarm_ctrl has no seconds port
	--       yet, so the alarm still compares hours and minutes only.
	-- TODO (decision pending): reading TIME then SECONDS takes two INs and can
	--       straddle a rollover. Snapshot seconds when TIME is read?

	-- ------------------------------------------------------------------
	-- Sub-modules
	-- ------------------------------------------------------------------
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
