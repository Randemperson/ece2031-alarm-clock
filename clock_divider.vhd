-- clock_divider.vhd
-- Owner: Charles
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
		clk_hz : positive := 10_000_000  -- clk_10MHz in the Lab 8 base; the testbench overrides this
	);
	port (
		clock 	: in  std_logic; 
		resetn 	: in  std_logic;  -- active low, asynchronous (same as SCOMP)
		fast   	: in  std_logic;
		tick   	: out std_logic
	);
end clock_divider;

architecture rtl of clock_divider is
begin

	-- Changed 	Count clock cycles from 0 to (CLK_HZ - 1) and pulse tick for one
	--       	cycle on wrap. When fast = '1', wrap at (CLK_HZ / 60) - 1 instead.
	-- Changed  (decision pending): CLK_HZ / 60 is not an integer at 10 MHz.
	--       	Is the small error acceptable, or do we pick another fast ratio?
	-- TODO 		(decision pending): Should writing TIME restart this counter so the
	--       	first second after a time-set is a full second? Needs a new input.
	-- Done  	Decide what happens to the count when fast changes mid-second.
	
	
	-- How it works: There is a count that increases by one each cycle. Once the
	-- count reaches/passes the cycles per second of the provided clock, it then
	-- creates a tick and then subtracts the amount of cycles that it needed to 
	-- reach to make a full second from the current count. The reason that it 
	-- subtracts the amount of cycles instead of setting the count to zero is
	-- because it is able to reflect the exact amount of cycles per second through
	-- the carryover of the count.
	-- Fast Enable Example: 	clk_hz = 100; So this is 100 cycles per second
	-- 			 1st cycle: 	count = 60;
	--           2nd cycle: 	count = 120; -> count = 20; tick = 1;
	--           3rd cycle:    count = 80; tick = 0;
	--           4th cycle:    count = 140; -> count = 40; tick = 1;
	--           5th cycle:    count = 100; -> count = 0; tick = 1;       
	-- So since you get 3 ticks every 5 cycles, and in 100 cycles there is one second,
	-- then you get 60 ticks per second like desired. 
	-- The only issue is if there is a clock with hertz less than 60, the fast mode
	-- will only be 5 times faster rather than 60. But you shouldn't need to use fast 
	-- mode if the hertz is less than 60 hertz anyways because of how fast it'd go.

	
	
	process (resetn, clock)
	
	variable count	: natural := 0;
	
	begin
	if resetn = '0' then -- Resets the values if the reset is activated
		tick <= '0';
		count := 0;
		
	elsif rising_edge(clock) then
		tick <= '0'; -- Brings the tick to '0' if it was '1' (overided by the 1 if count >= clk_hz later in the code)

		if fast = '1' and clk_hz >= 60 then -- If fast is active then the count increments by 60, otherwise it increments by 1
			count := count + 60;
		elsif fast = '1' then
			count := count + 5; -- If the Hz of the clock is less than 60, than a minute occurs in 20 seconds instead of 1 during fast mode
		else                      
			count := count + 1;
		end if;
		
		if count >= clk_hz then -- If the count is greater than the clk_hz then a tick is made
			tick <= '1';
			count := count - clk_hz;
		end if;
	end if;
	end process;
end rtl;
