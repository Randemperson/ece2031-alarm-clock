# Programmable Alarm Clock Peripheral for SCOMP

ECE 2031 final project. A time-based peripheral for SCOMP that keeps the time of day in hardware and lets a SCOMP program schedule up to six alarms.

SCOMP talks to the peripheral only through `IN` and `OUT`. All timekeeping, comparison, and alarm logic lives in VHDL. SCOMP programs write registers and read status; they never count time themselves.

> **Status:** the register map below is **final**. All new work must use it. Behavior details still undecided are listed under [Decisions pending](#decisions-pending) and marked `TODO` in the source.

## Behavior spec

- **Time format.** BCD, 24-hour. `HHMM` fits in one 16-bit word: `0x1730` is 17:30, `0x0000` is midnight, `0x1200` is noon. Seconds are a separate register, `00SS`.
- **Rollover.** 23:59:59 goes to 00:00:00.
- **Fast mode.** A control bit makes time run 60 times faster (one simulated minute per real second) for demos.
- **Alarms.** Six independent alarms (numbered 1-6), each with its own `HHMM`, seconds, and enable.
- **Firing.** An alarm starts ringing when the global EN and its own EN are both 1 and the time *ticks into* its `HH:MM:SS`. Writing the time directly to the alarm time does not fire it.
- **Stopping.** An alarm's RESET bit in Alarm Settings stops that alarm; the Global Control RESET bit stops all of them. A ringing alarm also stops by itself after 60 seconds.
- **Invalid writes.** A time write that is not valid BCD (`0x2500`, `0x1A30`, `0x1260`, seconds `0x60`) is ignored and sets the ERROR bit.

## Register map

`BASE` is `0x070`. The course only allows peripheral addresses `0x070` to `0x07F`, and the peripheral uses all 16 of them. The low 4 address bits select the register, so `BASE` must be a multiple of 16.

| Address | `.asm` (decimal) | Name | Write | Read |
|---|---|---|---|---|
| `0x070` | 112 | Current Hours/Minutes | Set current `HHMM` (seconds reset to 00) | Current `HHMM` |
| `0x071` | 113 | Current Seconds | Set current seconds | Current seconds |
| `0x072` | 114 | Global Control | Control bits (below) | EN, FAST, plus status (below) |
| `0x073` | 115 | Alarm Settings | EN and RESET for every alarm (below) | Every alarm's EN and RINGING (below) |
| `0x074` | 116 | Alarm 1 Hours/Minutes | Set alarm 1 `HHMM` | Alarm 1 `HHMM` |
| `0x075` | 117 | Alarm 1 Seconds | Set alarm 1 seconds | Alarm 1 seconds |
| `0x076` | 118 | Alarm 2 Hours/Minutes | Set alarm 2 `HHMM` | Alarm 2 `HHMM` |
| `0x077` | 119 | Alarm 2 Seconds | Set alarm 2 seconds | Alarm 2 seconds |
| `0x078` | 120 | Alarm 3 Hours/Minutes | Set alarm 3 `HHMM` | Alarm 3 `HHMM` |
| `0x079` | 121 | Alarm 3 Seconds | Set alarm 3 seconds | Alarm 3 seconds |
| `0x07A` | 122 | Alarm 4 Hours/Minutes | Set alarm 4 `HHMM` | Alarm 4 `HHMM` |
| `0x07B` | 123 | Alarm 4 Seconds | Set alarm 4 seconds | Alarm 4 seconds |
| `0x07C` | 124 | Alarm 5 Hours/Minutes | Set alarm 5 `HHMM` | Alarm 5 `HHMM` |
| `0x07D` | 125 | Alarm 5 Seconds | Set alarm 5 seconds | Alarm 5 seconds |
| `0x07E` | 126 | Alarm 6 Hours/Minutes | Set alarm 6 `HHMM` | Alarm 6 `HHMM` |
| `0x07F` | 127 | Alarm 6 Seconds | Set alarm 6 seconds | Alarm 6 seconds |

Alarm `n` (1-6) is at `0x074 + 2(n-1)` (hours/minutes) and `0x075 + 2(n-1)` (seconds). The bit-level map is in `register_map.xlsx`.

### Data formats

| Register | B15-B12 | B11-B8 | B7-B4 | B3-B0 |
|---|---|---|---|---|
| Hours/Minutes (current and alarms) | `HR_TENS` | `HR_ONES` | `MIN_TENS` | `MIN_ONES` |
| Seconds (current and alarms) | 0 | 0 | `SEC_TENS` | `SEC_ONES` |

### Global Control (`0x072`)

| Bit | Write | Read |
|---|---|---|
| 0 | EN (level): 1 = alarms enabled globally | Current EN |
| 1 | RESET (one-time): 1 = stop every ringing alarm | ANY_RINGING: at least one alarm is ringing |
| 2 | FAST (level): 1 = time runs 60 times faster | Current FAST |
| 3 | CLEAR_ERR (one-time): 1 = clear ERROR | ERROR: an invalid time write was ignored |
| 15-4 | Write 0 | 0 |

EN and FAST are levels, so every write sets them. To reset or clear the error without changing them, include their current values (for example `0b0111` = RESET with EN and FAST kept on).

### Alarm Settings (`0x073`)

One pair of bits per alarm. Alarm `n` uses bit `2(n-1)` and bit `2(n-1)+1`:

| Bits | Alarm | Write | Read |
|---|---|---|---|
| 1-0 | 1 | b0 EN, b1 RESET | b0 EN, b1 RINGING |
| 3-2 | 2 | b2 EN, b3 RESET | b2 EN, b3 RINGING |
| 5-4 | 3 | b4 EN, b5 RESET | b4 EN, b5 RINGING |
| 7-6 | 4 | b6 EN, b7 RESET | b6 EN, b7 RINGING |
| 9-8 | 5 | b8 EN, b9 RESET | b8 EN, b9 RINGING |
| 11-10 | 6 | b10 EN, b11 RESET | b10 EN, b11 RINGING |
| 15-12 | | Write 0 | 0 |

- **EN** is a level: every write sets all six enables at once.
- **RESET** is a one-time action: 1 stops that alarm. On a read, the same bit shows whether that alarm is ringing.

**Resetting one alarm.** Because a write sets every EN bit, write back the current enables along with the RESET bit. Reading the register returns RINGING in the RESET positions, so mask to the EN bits (`AND 0x0555`) before adding the RESET bit; otherwise every ringing alarm is reset too:

```
IN   AlarmSettings
AND  EnMask      ; 0x0555
OR   ResetA1     ; 0x0002 = alarm 1 RESET
OUT  AlarmSettings
```

The `RINGING` output pin of the peripheral follows ANY_RINGING.

## Team roles

| # | Role | Owner | Responsibilities |
|---|---|---|---|
| 1 | Timekeeping Core | ________ | Clock divider (1 Hz tick and fast tick), BCD time counter with rollover |
| 2 | Alarm Logic | ________ | Alarm register, compare logic, ringing state machine, snooze, timeout |
| 3 | Bus Interface & Integration | ________ | IO decoding, `IO_DATA` tri-state on reads, top-level schematic, pin assignments, merging to `main` |
| 4 | SCOMP Software & Demo | ________ | Assembly demo programs, 7-segment display, demo plan |
| 5 | Verification & Docs | ________ | Testbenches, this README, GitHub Issues, final report |

## Files and ownership

Only the owner edits a file. If you need a change in someone else's file, open an Issue or ask them.

| File | Owner | What it is |
|---|---|---|
| `clock_divider.vhd` | 1 Timekeeping | Board clock to a one-cycle `tick` enable (1 Hz, or 60 Hz in fast mode) |
| `time_counter.vhd` | 1 Timekeeping | BCD HH:MM:SS counter with load inputs and `minute_tick` |
| `alarm_ctrl.vhd` | 2 Alarm | One alarm: alarm `HHMM` and seconds registers, compare, ringing state machine |
| `alarm_clock_io.vhd` | 3 Bus | The peripheral itself: address decode, write latching, read mux, connects the modules above (one `alarm_ctrl` per alarm) |
| `*.bdf`, `*.qsf`, `*.qpf`, `SCOMP.vhd` | 3 Bus | Top-level schematic, pin and project settings, base project files |
| `alarm_demo.asm`, `*.mif` | 4 Software | Demo programs and their assembled output |
| `alarm_clock_tb.vhd` | 5 Verification | Simulation testbench (not part of synthesis) |
| `README.md` | 5 Verification | This file |
| `.gitignore` | 3 Bus | Keeps Quartus build output out of the repo |

### Module interfaces

The port lists in the `.vhd` stubs are the contract between owners. Change a port only after agreeing with everyone who connects to it.

- Everything runs on the one board clock (`clk_10MHz`, the same clock SCOMP uses). There are no derived clocks. `tick` and `minute_tick` are one-cycle enable pulses.
- `resetn` is active low and asynchronous, the same as SCOMP.
- Use `ieee.numeric_std`, not `std_logic_arith` or `std_logic_unsigned`.
- `alarm_clock_io` validates BCD before pulsing a load signal, so `time_counter` and `alarm_ctrl` can trust `load_data`.

## Repo workflow

1. **Pull before you start working**, every time: `git pull origin main`.
2. **Work on a feature branch**, never directly on `main`: `git checkout -b alarm-fsm`.
3. **`main` must always compile.** Run a full Quartus compilation before opening a pull request. The stubs drive safe defaults so the project builds from day one; keep it that way.
4. **One owner for `.bdf` and `.qsf`.** These files do not merge. Only the Bus Interface & Integration owner edits and commits them. If Quartus changes them on your machine, discard the change (`git checkout -- <file>`) before committing.
5. **Open a pull request** into `main`. The integration owner merges it.
6. **Do not commit build output.** If `git status` shows `db/` or `output_files/`, the `.gitignore` is not being picked up.
7. **Commit the `.mif` with its `.asm`** so everyone can program the board without reassembling.

## Decisions pending

- [x] **Register map.** Final 16-register map at `0x070`-`0x07F` (above).
- [x] **Multiple alarms.** Six, at `0x074`-`0x07F`, each with an EN/RESET bit pair in Alarm Settings. No alarm select. `alarm_clock_io` creates one `alarm_ctrl` per alarm.
- [x] **Status bits.** Per-alarm RINGING on the read side of Alarm Settings; ANY_RINGING and ERROR on the read side of Global Control.
- [x] **Clearing ERROR.** Write 1 to Global Control bit 3.
- [x] **Alarm seconds.** Each alarm compares hours, minutes and seconds. `alarm_ctrl` has `seconds`, `load_alarm_sec` and `alarm_sec` ports for this.
- [x] **Fast-mode ratio.** Solved: `clock_divider` keeps the remainder (phase accumulator), so fast mode is exact on average.
- [ ] **Consistent TIME and SECONDS reads.** Two `IN`s can straddle a rollover. Snapshot seconds when TIME is read?
- [ ] **Timeout in fast mode.** The 60-second timeout counts simulated seconds, so in fast mode a ring lasts 1 real second. Keep, or time it in real seconds?
- [ ] **Setting the time while ringing.** Keep ringing or stop?
- [ ] **Changing an alarm or clearing EN while ringing.** Does clearing EN silence the alarm?
- [ ] **Alarm reset value.** `0x0000` / `0x00` with EN = 0?
- [ ] **Does writing TIME restart the 1 Hz divider** so the first second is a full second?
- [ ] **Snooze.** Out of the final map (no SNOOZE bit); `alarm_ctrl`'s `snooze` input is tied to 0.
- [ ] **RINGING output pin.** LED only, or a buzzer on a GPIO pin? DIG_OUT already drives the LEDs.
