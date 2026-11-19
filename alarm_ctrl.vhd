-- alarm_ctrl.vhd
-- Owner: Alarm Logic

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_ctrl is
    port (
        clock       : in  std_logic;
        resetn      : in  std_logic;
        tick        : in  std_logic;                      -- one pulse per simulated second
        minute_tick : in  std_logic;                      -- one pulse per minute rollover
        hhmm        : in  std_logic_vector(15 downto 0); -- current time
        load_alarm  : in  std_logic;                      -- load alarm register
        load_data   : in  std_logic_vector(15 downto 0);
        time_set    : in  std_logic;                      -- current time was just written
        en          : in  std_logic;                      -- alarm enable
        ack         : in  std_logic;                      -- clear alarm
        snooze      : in  std_logic;                      -- snooze request

        alarm_hhmm  : out std_logic_vector(15 downto 0);
        ringing     : out std_logic;
        snoozed     : out std_logic
    );
end alarm_ctrl;


architecture rtl of alarm_ctrl is

    type state_type is (IDLE, RINGING, SNOOZED);
    signal state : state_type := IDLE;

    signal alarm_reg   : std_logic_vector(15 downto 0) := (others => '0');

    -- Prevent reset value 00:00 from accidentally behaving like a real alarm.
    signal alarm_valid : std_logic := '0';

    -- Counts seconds spent ringing.
    signal ring_count : integer range 0 to 59 := 0;

    -- Counts minute rollovers during snooze.
    signal snooze_count : integer range 0 to 4 := 0;

    -- Delay minute_tick by one clock so hhmm has time to update.
    signal minute_tick_d : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------

    alarm_hhmm <= alarm_reg;

    ringing <= '1' when state = RINGING else '0';

    snoozed <= '1' when state = SNOOZED else '0';


    --------------------------------------------------------------------
    -- Alarm register + state machine
    --------------------------------------------------------------------

    process(clock, resetn)
    begin

        if resetn = '0' then

            state         <= IDLE;
            alarm_reg     <= (others => '0');
            alarm_valid   <= '0';

            ring_count    <= 0;
            snooze_count  <= 0;

            minute_tick_d <= '0';


        elsif rising_edge(clock) then

            ------------------------------------------------------------
            -- Delay minute_tick by one clock.
            ------------------------------------------------------------

            minute_tick_d <= minute_tick;


            ------------------------------------------------------------
            -- Load alarm register
            ------------------------------------------------------------

            if load_alarm = '1' then
                alarm_reg   <= load_data;
                alarm_valid <= '1';
            end if;


            ------------------------------------------------------------
            -- Alarm disabled
            ------------------------------------------------------------

            if en = '0' then

                state        <= IDLE;
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

                    when IDLE =>

                        ring_count   <= 0;
                        snooze_count <= 0;

                        -- Fire only when:
                        --   alarm has actually been loaded
                        --   a new minute has occurred
                        --   current time matches alarm
                        --   current time was not just manually changed
                        if alarm_valid = '1'
                           and minute_tick_d = '1'
                           and hhmm = alarm_reg
                           and time_set = '0' then

                            state      <= RINGING;
                            ring_count <= 0;

                        end if;


                    ----------------------------------------------------
                    -- RINGING
                    ----------------------------------------------------

                    when RINGING =>

                        -- ACK has highest priority.
                        if ack = '1' then

                            state      <= IDLE;
                            ring_count <= 0;


                        -- Snooze the active alarm.
                        elsif snooze = '1' then

                            state         <= SNOOZED;
                            snooze_count  <= 0;
                            ring_count    <= 0;


                        -- Count seconds while ringing.
                        elsif tick = '1' then

                            if ring_count = 59 then

                                -- 60 seconds have elapsed.
                                state      <= IDLE;
                                ring_count <= 0;

                            else

                                ring_count <= ring_count + 1;

                            end if;

                        end if;


                    ----------------------------------------------------
                    -- SNOOZED
                    ----------------------------------------------------

                    when SNOOZED =>

                        ring_count <= 0;

                        -- An ACK can also cancel a snoozed alarm.
                        if ack = '1' then

                            state         <= IDLE;
                            snooze_count  <= 0;


                        elsif minute_tick = '1' then

                            if snooze_count = 4 then

                                -- Fifth minute rollover.
                                state         <= RINGING;
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

                        state         <= IDLE;
                        ring_count    <= 0;
                        snooze_count  <= 0;

                end case;

            end if;

        end if;

    end process;

end rtl;