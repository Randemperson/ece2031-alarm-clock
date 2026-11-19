-- alarm_ctrl.vhd
-- Owner: Alarm Logic
--
-- ONE alarm: holds the alarm time (HHMM and seconds), compares it against the
-- current time, and runs the ringing state machine. alarm_clock_io creates
-- one copy of this module per alarm (5 alarms), so this file only ever deals
-- with a single alarm.
--
--   S_IDLE    --(en = '1' and time ticks into hhmm:seconds = alarm)-->  S_RINGING
--   S_RINGING --(ack, or 60 s timeout)-->                                S_IDLE
--   S_RINGING --(snooze)-->                                              S_SNOOZED
--   S_SNOOZED --(5 minute rollovers)-->                                  S_RINGING
--   any state --(en = '0')-->                                            S_IDLE
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
        tick           : in  std_logic;                      -- one pulse per simulated second
        minute_tick    : in  std_logic;                      -- one pulse per minute rollover
        hhmm           : in  std_logic_vector(15 downto 0);  -- current time
        seconds        : in  std_logic_vector(7 downto 0);   -- current seconds
        load_alarm     : in  std_logic;                      -- load alarm HHMM register
        load_alarm_sec : in  std_logic;                      -- load alarm seconds register
        load_data      : in  std_logic_vector(15 downto 0);
        time_set       : in  std_logic;                      -- current time was just written
        en             : in  std_logic;                      -- alarm enable (global AND per-alarm)
        ack            : in  std_logic;                      -- clear alarm
        snooze         : in  std_logic;                      -- snooze request (tied to '0' for now)

        alarm_hhmm     : out std_logic_vector(15 downto 0);
        alarm_sec      : out std_logic_vector(7 downto 0);
        ringing        : out std_logic;
        snoozed        : out std_logic
    );
end alarm_ctrl;


architecture rtl of alarm_ctrl is

    -- VHDL is not case sensitive, so the state names must not match the
    -- port names "ringing" and "snoozed". Hence the S_ prefix.
    type state_type is (S_IDLE, S_RINGING, S_SNOOZED);
    signal state : state_type := S_IDLE;

    signal alarm_reg     : std_logic_vector(15 downto 0) := (others => '0');
    signal alarm_sec_reg : std_logic_vector(7 downto 0)  := (others => '0');

    -- Prevent reset value 00:00:00 from accidentally behaving like a real alarm.
    signal alarm_valid : std_logic := '0';

    -- Counts seconds spent ringing.
    signal ring_count : integer range 0 to 59 := 0;

    -- Counts minute rollovers during snooze.
    signal snooze_count : integer range 0 to 4 := 0;

    -- Delay tick and time_set by one clock. time_counter updates hhmm and
    -- seconds on the clock edge where tick = '1', so the new time is visible
    -- one cycle later, which is when tick_d is high. time_set_d lines up with
    -- it: if TIME was written in the same cycle as the tick, the time shown
    -- now is the value SCOMP wrote, not a natural tick, so do not fire.
    signal tick_d     : std_logic := '0';
    signal time_set_d : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------

    alarm_hhmm <= alarm_reg;
    alarm_sec  <= alarm_sec_reg;

    ringing <= '1' when state = S_RINGING else '0';

    snoozed <= '1' when state = S_SNOOZED else '0';


    --------------------------------------------------------------------
    -- Alarm register + state machine
    --------------------------------------------------------------------

    process(clock, resetn)
    begin

        if resetn = '0' then

            state         <= S_IDLE;
            alarm_reg     <= (others => '0');
            alarm_sec_reg <= (others => '0');
            alarm_valid   <= '0';

            ring_count    <= 0;
            snooze_count  <= 0;

            tick_d        <= '0';
            time_set_d    <= '0';


        elsif rising_edge(clock) then

            ------------------------------------------------------------
            -- Delay tick and time_set by one clock.
            ------------------------------------------------------------

            tick_d     <= tick;
            time_set_d <= time_set;


            ------------------------------------------------------------
            -- Load alarm registers
            ------------------------------------------------------------

            if load_alarm = '1' then
                alarm_reg   <= load_data;
                alarm_valid <= '1';
            end if;

            if load_alarm_sec = '1' then
                alarm_sec_reg <= load_data(7 downto 0);
                alarm_valid   <= '1';
            end if;


            ------------------------------------------------------------
            -- Alarm disabled
            ------------------------------------------------------------

            if en = '0' then

                state        <= S_IDLE;
                ring_count   <= 0;
                snooze_count <= 0;


            else

                --------------------------------------------------------
                -- State machine
                --------------------------------------------------------

                case state is

                    ----------------------------------------------------
                    -- IDLE
                    ----------------------------------------------------

                    when S_IDLE =>

                        ring_count   <= 0;
                        snooze_count <= 0;

                        -- Fire only when:
                        --   alarm has actually been loaded
                        --   a new second has just ticked
                        --   current HH:MM:SS matches the alarm
                        --   that time came from the tick, not a TIME write
                        if alarm_valid = '1'
                           and tick_d = '1'
                           and hhmm = alarm_reg
                           and seconds = alarm_sec_reg
                           and time_set_d = '0' then

                            state      <= S_RINGING;
                            ring_count <= 0;

                        end if;


                    ----------------------------------------------------
                    -- RINGING
                    ----------------------------------------------------

                    when S_RINGING =>

                        -- ACK has highest priority.
                        if ack = '1' then

                            state      <= S_IDLE;
                            ring_count <= 0;


                        -- Snooze the active alarm.
                        elsif snooze = '1' then

                            state         <= S_SNOOZED;
                            snooze_count  <= 0;
                            ring_count    <= 0;


                        -- Count seconds while ringing.
                        elsif tick = '1' then

                            if ring_count = 59 then

                                -- 60 seconds have elapsed.
                                state      <= S_IDLE;
                                ring_count <= 0;

                            else

                                ring_count <= ring_count + 1;

                            end if;

                        end if;


                    ----------------------------------------------------
                    -- SNOOZED
                    ----------------------------------------------------

                    when S_SNOOZED =>

                        ring_count <= 0;

                        -- An ACK can also cancel a snoozed alarm.
                        if ack = '1' then

                            state         <= S_IDLE;
                            snooze_count  <= 0;


                        elsif minute_tick = '1' then

                            if snooze_count = 4 then

                                -- Fifth minute rollover.
                                state         <= S_RINGING;
                                snooze_count  <= 0;
                                ring_count    <= 0;

                            else

                                snooze_count <= snooze_count + 1;

                            end if;

                        end if;


                    ----------------------------------------------------
                    -- Safety
                    ----------------------------------------------------

                    when others =>

                        state         <= S_IDLE;
                        ring_count    <= 0;
                        snooze_count  <= 0;

                end case;

            end if;

        end if;

    end process;

end rtl;
