-- alarm_clock_io.vhd
-- Owner: Bus Interface & Integration (Charles)
--
-- The SCOMP-facing alarm clock peripheral. This is the block that goes on the
-- top-level schematic. Bus ports copy TIMER.vhd from the Lab 8 base project.
--
-- Register map (final). BASE = 0x070; registers 0x070-0x07F (all 16).
--
--   0x070  TIME            HHMM (BCD)
--   0x071  SECONDS         00SS (BCD)
--   0x072  GLOBAL CONTROL  write: b0 EN, b1 RESET, b2 FAST, b3 CLEAR_ERR
--                          read:  b0 EN, b1 ANY_RINGING, b2 FAST, b3 ERROR
--   0x073  ALARM SETTINGS  one bit pair per alarm, alarm n (1-6) at bits
--                          2(n-1) and 2(n-1)+1:
--                          write: b[2(n-1)] EN, b[2(n-1)+1] RESET
--                          read:  b[2(n-1)] EN, b[2(n-1)+1] RINGING
--   0x074  ALARM 1 HHMM    0x075  ALARM 1 SECONDS
--   0x076  ALARM 2 HHMM    0x077  ALARM 2 SECONDS
--   0x078  ALARM 3 HHMM    0x079  ALARM 3 SECONDS
--   0x07A  ALARM 4 HHMM    0x07B  ALARM 4 SECONDS
--   0x07C  ALARM 5 HHMM    0x07D  ALARM 5 SECONDS
--   0x07E  ALARM 6 HHMM    0x07F  ALARM 6 SECONDS
--
--   EN bits and FAST are levels: every write sets them. RESET and CLEAR_ERR
--   are one-time actions. Global RESET stops every ringing alarm; a RESET bit
--   in Alarm Settings stops only that alarm. An alarm can fire only when both
--   the global EN and its own EN are 1.
--   Invalid BCD time writes are ignored and set ERROR.
--
--   Read-modify-write warning: reading Alarm Settings returns RINGING in the
--   RESET positions. To reset one alarm without touching the others, a
--   program must AND what it read with 0x0555 (EN bits only) before ORing in
--   the RESET bit, or it resets every alarm that is ringing.
--
-- Inside this file alarms are numbered 0-5 (alarm 1 = index 0).
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
		-- base must be a multiple of 16 (see the address decode below).
		BASE_ADDR : std_logic_vector(10 downto 0) := "00001110000"
	);
	port (
		CLOCK    : in    std_logic;
		RESETN   : in    std_logic;
		IO_ADDR  : in    std_logic_vector(10 downto 0);
		IO_READ  : in    std_logic;
		IO_WRITE : in    std_logic;
		IO_DATA  : inout std_logic_vector(15 downto 0);
		RINGING  : out   std_logic  -- 1 while any alarm is ringing
	);
end alarm_clock_io;

architecture rtl of alarm_clock_io is

	constant NUM_ALARMS : natural := 6;

	-- Register numbers: the low 4 bits of the IO address.
	constant R_TIME      : natural := 0;
	constant R_SECONDS   : natural := 1;
	constant R_GCTRL     : natural := 2;
	constant R_ALARM_SET : natural := 3;
	constant R_ALARM0    : natural := 4;   -- alarm index i: HHMM at 4+2i, seconds at 5+2i
	constant R_LAST      : natural := R_ALARM0 + 2*NUM_ALARMS - 1;  -- 15 (0x07F)

	-- GLOBAL CONTROL bit positions.
	constant G_EN          : natural := 0;  -- read and write
	constant G_RESET       : natural := 1;  -- write
	constant G_ANY_RINGING : natural := 1;  -- read
	constant G_FAST        : natural := 2;  -- read and write
	constant G_CLEAR_ERR   : natural := 3;  -- write
	constant G_ERROR       : natural := 3;  -- read

	-- ALARM SETTINGS: alarm index i uses bit 2i (EN) and bit 2i+1 (RESET / RINGING).

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

	-- Which registers belong to the per-alarm block, and which alarm.
	function is_alarm_hhmm(n : natural) return boolean is
	begin
		return n >= R_ALARM0 and n <= R_LAST and (n - R_ALARM0) mod 2 = 0;
	end function;

	function is_alarm_sec(n : natural) return boolean is
	begin
		return n >= R_ALARM0 and n <= R_LAST and (n - R_ALARM0) mod 2 = 1;
	end function;

	function alarm_index(n : natural) return natural is
	begin
		return (n - R_ALARM0) / 2;
	end function;

	type hhmm_array is array (0 to NUM_ALARMS-1) of std_logic_vector(15 downto 0);
	type sec_array  is array (0 to NUM_ALARMS-1) of std_logic_vector(7 downto 0);

	-- Address decode.
	signal selected : std_logic;                     -- the address is one of ours
	signal reg_n    : natural range 0 to 15;         -- which register
	signal wr, rd   : std_logic;                     -- a write / read to us, this cycle

	-- Clock and time.
	signal tick, minute_tick : std_logic;
	signal hhmm              : std_logic_vector(15 downto 0);
	signal seconds           : std_logic_vector(7 downto 0);
	signal load_hhmm         : std_logic;
	signal load_sec          : std_logic;

	-- Per-alarm connections (index = alarm number - 1).
	signal load_alarm     : std_logic_vector(0 to NUM_ALARMS-1);
	signal load_alarm_sec : std_logic_vector(0 to NUM_ALARMS-1);
	signal ack_a          : std_logic_vector(0 to NUM_ALARMS-1);
	signal en_a           : std_logic_vector(0 to NUM_ALARMS-1);
	signal ring_a         : std_logic_vector(0 to NUM_ALARMS-1);
	signal snoozed_a      : std_logic_vector(0 to NUM_ALARMS-1);
	signal alarm_hhmm_a   : hhmm_array;
	signal alarm_sec_a    : sec_array;
	signal any_ring       : std_logic;

	-- Registers that live in this file.
	signal gen_reg        : std_logic;                               -- global EN
	signal fast_reg       : std_logic;
	signal error_reg      : std_logic;
	signal alarm_en       : std_logic_vector(0 to NUM_ALARMS-1);     -- per-alarm EN

	signal global_reset   : std_logic;
	signal write_invalid  : std_logic;
	signal read_data      : std_logic_vector(15 downto 0);
	signal drive_bus      : std_logic;

begin

	-- ------------------------------------------------------------------
	-- Address decode
	-- ------------------------------------------------------------------
	-- The upper 7 address bits pick the peripheral, the low 4 pick the
	-- register. This is why BASE_ADDR must be a multiple of 16.
	selected <= '1' when IO_ADDR(10 downto 4) = BASE_ADDR(10 downto 4) else '0';
	reg_n    <= to_integer(unsigned(IO_ADDR(3 downto 0)));
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
	load_hhmm    <= '1' when wr = '1' and reg_n = R_TIME    and valid_hhmm(IO_DATA) else '0';
	load_sec     <= '1' when wr = '1' and reg_n = R_SECONDS and valid_sec(IO_DATA)  else '0';

	global_reset <= '1' when wr = '1' and reg_n = R_GCTRL and IO_DATA(G_RESET) = '1' else '0';

	-- Any time write that will be ignored because its value is invalid.
	write_invalid <= '1' when wr = '1' and (
	                     ((reg_n = R_TIME    or is_alarm_hhmm(reg_n)) and not valid_hhmm(IO_DATA)) or
	                     ((reg_n = R_SECONDS or is_alarm_sec(reg_n))  and not valid_sec(IO_DATA))
	                 ) else '0';

	-- ------------------------------------------------------------------
	-- Writes: registers that live in this file
	-- ------------------------------------------------------------------
	process (CLOCK, RESETN)
	begin
		if RESETN = '0' then
			gen_reg   <= '0';
			fast_reg  <= '0';
			error_reg <= '0';
			alarm_en  <= (others => '0');
		elsif rising_edge(CLOCK) then
			if write_invalid = '1' then
				error_reg <= '1';
			end if;

			if wr = '1' then
				case reg_n is

					-- EN and FAST are levels: every write sets them.
					-- RESET is the global_reset pulse above.
					when R_GCTRL =>
						gen_reg  <= IO_DATA(G_EN);
						fast_reg <= IO_DATA(G_FAST);
						if IO_DATA(G_CLEAR_ERR) = '1' then
							error_reg <= '0';
						end if;

					-- Every alarm's EN is a level: one write sets all six.
					-- The RESET bits are the ack pulses below.
					when R_ALARM_SET =>
						for i in 0 to NUM_ALARMS-1 loop
							alarm_en(i) <= IO_DATA(2*i);
						end loop;

					-- TIME, SECONDS and the alarm times are stored in the
					-- sub-modules (load pulses).
					when others =>
						null;

				end case;
			end if;
		end if;
	end process;

	-- ------------------------------------------------------------------
	-- Reads
	-- ------------------------------------------------------------------
	any_ring <= '0' when ring_a = (ring_a'range => '0') else '1';

	process (reg_n, hhmm, seconds, gen_reg, fast_reg, alarm_en, ring_a, any_ring,
	         error_reg, alarm_hhmm_a, alarm_sec_a)
	begin
		read_data <= (others => '0');
		case reg_n is
			when R_TIME      => read_data <= hhmm;
			when R_SECONDS   => read_data(7 downto 0) <= seconds;
			when R_GCTRL     =>
				read_data(G_EN)          <= gen_reg;
				read_data(G_ANY_RINGING) <= any_ring;
				read_data(G_FAST)        <= fast_reg;
				read_data(G_ERROR)       <= error_reg;
			when R_ALARM_SET =>
				for i in 0 to NUM_ALARMS-1 loop
					read_data(2*i)     <= alarm_en(i);
					read_data(2*i + 1) <= ring_a(i);
				end loop;
			when others      =>
				if is_alarm_hhmm(reg_n) then
					read_data <= alarm_hhmm_a(alarm_index(reg_n));
				elsif is_alarm_sec(reg_n) then
					read_data(7 downto 0) <= alarm_sec_a(alarm_index(reg_n));
				end if;
		end case;
	end process;

	-- Drive the bus only while SCOMP is reading one of our registers
	-- (all of 0x070-0x07F). At every other time the peripheral must be
	-- disconnected ('Z'), or it would fight with SCOMP and the other devices
	-- on the shared bus.
	drive_bus <= '1' when rd = '1' and reg_n <= R_LAST else '0';
	IO_DATA   <= read_data when drive_bus = '1' else (others => 'Z');

	RINGING <= any_ring;

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

	-- One alarm_ctrl per alarm (index i = alarm i+1).
	g_alarms : for i in 0 to NUM_ALARMS-1 generate

		load_alarm(i)     <= '1' when wr = '1' and reg_n = R_ALARM0 + 2*i
		                                 and valid_hhmm(IO_DATA) else '0';
		load_alarm_sec(i) <= '1' when wr = '1' and reg_n = R_ALARM0 + 2*i + 1
		                                 and valid_sec(IO_DATA) else '0';

		-- Stopped by the global RESET, or by its own RESET bit.
		ack_a(i) <= '1' when global_reset = '1'
		                  or (wr = '1' and reg_n = R_ALARM_SET
		                      and IO_DATA(2*i + 1) = '1') else '0';

		-- Armed only when both the global EN and its own EN are set.
		en_a(i)  <= gen_reg and alarm_en(i);

		u_alarm : entity work.alarm_ctrl
			port map (
				clock => CLOCK, resetn => RESETN, tick => tick, minute_tick => minute_tick,
				hhmm => hhmm, seconds => seconds,
				load_alarm => load_alarm(i), load_alarm_sec => load_alarm_sec(i),
				load_data => IO_DATA, time_set => load_hhmm,
				en => en_a(i), ack => ack_a(i),
				snooze => '0',   -- no SNOOZE bit in the map
				alarm_hhmm => alarm_hhmm_a(i), alarm_sec => alarm_sec_a(i),
				ringing => ring_a(i), snoozed => snoozed_a(i)
			);

	end generate;

end rtl;
