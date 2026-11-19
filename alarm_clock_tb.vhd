-- alarm_clock_tb.vhd
-- Owner: Verification & Docs
--
-- Testbench for alarm_clock_io. Simulation only: do NOT add this file to the
-- Quartus project's synthesis file list.
--
-- CLK_HZ is overridden to 120 so one simulated "second" is 120 clock cycles
-- (2 cycles in fast mode) instead of 10 million.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_clock_tb is
end alarm_clock_tb;

architecture sim of alarm_clock_tb is

	constant CLK_PERIOD : time := 100 ns;  -- 10 MHz
	constant TB_CLK_HZ  : positive := 120;
	constant ONE_SEC    : time := CLK_PERIOD * TB_CLK_HZ;

	-- Final register map (BASE = 0x070). See README.md.
	constant ADDR_TIME      : std_logic_vector(10 downto 0) := "00001110000";  -- 0x070 TIME
	constant ADDR_SEC       : std_logic_vector(10 downto 0) := "00001110001";  -- 0x071 SECONDS
	constant ADDR_GCTRL     : std_logic_vector(10 downto 0) := "00001110010";  -- 0x072 GLOBAL CONTROL
	constant ADDR_ALARM_SEL : std_logic_vector(10 downto 0) := "00001110011";  -- 0x073 ALARM SELECT
	constant ADDR_ALARM_SET : std_logic_vector(10 downto 0) := "00001110100";  -- 0x074 ALARM SETTINGS (+ status on read)
	constant ADDR_ALARM0    : std_logic_vector(10 downto 0) := "00001110101";  -- 0x075 alarm 0 HHMM (alarm i at 0x075 + 2i)
	constant ADDR_ALARM0_SEC: std_logic_vector(10 downto 0) := "00001110110";  -- 0x076 alarm 0 SECONDS (alarm i at 0x076 + 2i)

	-- GLOBAL CONTROL write bits: b0 EN, b1 RESET, b2 FAST, b3 CLEAR_ERR
	-- ALARM SETTINGS write: b0 EN, b1 RESET.  read: b0 EN, b1 RINGING, b2 ANY_RINGING, b3 ERROR

	signal clock    : std_logic := '0';
	signal resetn   : std_logic := '0';
	signal io_addr  : std_logic_vector(10 downto 0) := (others => '0');
	signal io_read  : std_logic := '0';
	signal io_write : std_logic := '0';
	signal io_data  : std_logic_vector(15 downto 0) := (others => 'Z');
	signal ringing  : std_logic;
	signal done     : boolean := false;

begin

	clock <= not clock after CLK_PERIOD / 2 when not done;

	dut : entity work.alarm_clock_io
		generic map (CLK_HZ => TB_CLK_HZ, BASE_ADDR => ADDR_TIME)
		port map (
			CLOCK => clock, RESETN => resetn,
			IO_ADDR => io_addr, IO_READ => io_read, IO_WRITE => io_write,
			IO_DATA => io_data, RINGING => ringing
		);

	stimulus : process

		-- Same timing as a SCOMP OUT: data valid, IO_WRITE high for one cycle.
		procedure scomp_out(addr : in std_logic_vector(10 downto 0);
		                    data : in std_logic_vector(15 downto 0)) is
		begin
			wait until rising_edge(clock);
			io_addr <= addr;  io_data <= data;
			wait until rising_edge(clock);
			io_write <= '1';
			wait until rising_edge(clock);
			io_write <= '0';
			wait until rising_edge(clock);
			io_data <= (others => 'Z');
		end procedure;

		-- Same timing as a SCOMP IN: IO_READ high for one cycle, data latched
		-- at the end of that cycle.
		procedure scomp_in(addr : in  std_logic_vector(10 downto 0);
		                   data : out std_logic_vector(15 downto 0)) is
		begin
			wait until rising_edge(clock);
			io_addr <= addr;
			wait until rising_edge(clock);
			io_read <= '1';
			wait until rising_edge(clock);
			data := io_data;
			io_read <= '0';
		end procedure;

		variable rd : std_logic_vector(15 downto 0);

	begin
		resetn <= '0';
		wait for 5 * CLK_PERIOD;
		resetn <= '1';

		-- Example of the pattern every test should follow:
		--   scomp_out(ADDR_TIME, x"2359");
		--   scomp_in(ADDR_TIME, rd);
		--   assert rd = x"2359" report "TIME readback failed" severity error;

		-- TODO test 1: rollover. Set 23:59, seconds 0x58, wait 2 * ONE_SEC,
		--              expect TIME = 0x0000 and SECONDS = 0x00.
		-- TODO test 2: alarm fires at 00:00:00. Alarm 0 = 0x0000 / 0x00,
		--              ALARM_SEL = 0, ALARM_SET EN = 1, GCTRL EN = 1, let the
		--              time tick from 23:59:59; expect ALARM_SET read bit 1
		--              (RINGING) and bit 2 (ANY_RINGING), and the RINGING pin.
		-- TODO test 3: no fire on direct set. Alarm 0 = 07:00:00, enabled;
		--              write TIME = 0x0700; expect RINGING to stay low.
		-- TODO test 4: set time while ringing (expected result is a pending
		--              decision; write the test once the spec says).
		-- TODO test 5: invalid writes. 0x2500, 0x1A30, 0x1260 to TIME and an
		--              alarm HHMM, 0x60 to SECONDS and an alarm SECONDS, 5 to
		--              ALARM_SEL; expect registers unchanged and ALARM_SET read
		--              bit 3 (ERROR) set. GCTRL bit 3 (CLEAR_ERR) clears it.
		-- TODO test 6: RESET. While ringing, write ALARM_SET with bit 1 set
		--              (keep bit 0 EN); expect that alarm to stop. Then GCTRL
		--              bit 1 (keep EN and FAST) with two alarms ringing; expect
		--              both to stop.
		-- TODO test 7: timeout. Let it ring without RESET for 60 * ONE_SEC;
		--              expect RINGING to drop on its own.
		-- TODO test 8: EN gating. An alarm fires only when GCTRL EN and its
		--              own ALARM_SET EN are both 1.
		-- TODO test 9: two alarms at different times each fire on their own.
		-- TODO: bus hygiene. io_data must be all 'Z' whenever io_read = '0',
		--       and reads of 0x07F and addresses outside 0x070-0x07F must not
		--       be driven.

		report "Testbench finished (no tests implemented yet)" severity note;
		done <= true;
		wait;
	end process;

end sim;
