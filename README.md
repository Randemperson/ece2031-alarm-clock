# Programmable Alarm Clock Peripheral for SCOMP

ECE 2031 final project. A time-based peripheral for SCOMP that keeps the time of day in hardware and lets a SCOMP program schedule up to five alarms.

SCOMP talks to the peripheral only through `IN` and `OUT`. All timekeeping, comparison, and alarm logic lives in VHDL. SCOMP programs write registers and read status; they never count time themselves.

> **Status:** the register map below is **final**. All new work must use it. Behavior details still undecided are listed under [Decisions pending](#decisions-pending) and marked `TODO` in the source.

## Behavior spec

- **Time format.** BCD, 24-hour. `HHMM` fits in one 16-bit word: `0x1730` is 17:30, `0x0000` is midnight, `0x1200` is noon. Seconds are a separate register, `00SS`.
- **Rollover.** 23:59:59 goes to 00:00:00.
- **Fast mode.** A control bit makes time run 60 times faster (one simulated minute per real second) for demos.
- **Alarms.** Five independent alarms, each with its own `HHMM`, seconds, and enable.
- **Firing.** An alarm starts ringing when the global EN and its own EN are both 1 and the time *ticks into* its `HH:MM:SS`. Writing the time directly to the alarm time does not fire it.
- **Stopping.** The Alarm Settings RESET bit stops the selected alarm; the Global Control RESET bit stops all of them. A ringing alarm also stops by itself after 60 seconds.
- **Invalid writes.** A time write that is not valid BCD (`0x2500`, `0x1A30`, `0x1260`, seconds `0x60`) or an ALARM_SEL value above 4 is ignored and sets the ERROR bit.

## Register map

`BASE` is `0x070`. The course only allows peripheral addresses `0x070` to `0x07F`. The peripheral uses `0x070` to `0x07E` and the low 4 address bits select the register, so `BASE` must be a multiple of 16. `0x07F` is unused and never driven.

| Address | `.asm` (decimal) | Name | Write | Read |
|---|---|---|---|---|
| `0x070` | 112 | Current Hours/Minutes | Set current `HHMM` (seconds reset to 00) | Current `HHMM` |
| `0x071` | 113 | Current Seconds | Set current seconds | Current seconds |
| `0x072` | 114 | Global Control | Control bits (below) | Current EN and FAST |
| `0x073` | 115 | Alarm Select | Pick the alarm (0-4) that Alarm Settings refers to | Selected alarm |
| `0x074` | 116 | Alarm Settings | EN and RESET for the selected alarm | Selected alarm's EN, plus status (below) |
| `0x075` | 117 | Alarm 0 Hours/Minutes | Set alarm 0 `HHMM` | Alarm 0 `HHMM` |
| `0x076` | 118 | Alarm 0 Seconds | Set alarm 0 seconds | Alarm 0 seconds |
| `0x077` | 119 | Alarm 1 Hours/Minutes | Set alarm 1 `HHMM` | Alarm 1 `HHMM` |
| `0x078` | 120 | Alarm 1 Seconds | Set alarm 1 seconds | Alarm 1 seconds |
| `0x079` | 121 | Alarm 2 Hours/Minutes | Set alarm 2 `HHMM` | Alarm 2 `HHMM` |
| `0x07A` | 122 | Alarm 2 Seconds | Set alarm 2 seconds | Alarm 2 seconds |
| `0x07B` | 123 | Alarm 3 Hours/Minutes | Set alarm 3 `HHMM` | Alarm 3 `HHMM` |
| `0x07C` | 124 | Alarm 3 Seconds | Set alarm 3 seconds | Alarm 3 seconds |
| `0x07D` | 125 | Alarm 4 Hours/Minutes | Set alarm 4 `HHMM` | Alarm 4 `HHMM` |
| `0x07E` | 126 | Alarm 4 Seconds | Set alarm 4 seconds | Alarm 4 seconds |

Alarm `i` is at `0x075 + 2i` (hours/minutes) and `0x076 + 2i` (seconds). The bit-level map is in `register_map.xlsx`.

### Data formats

| Register | B15-B12 | B11-B8 | B7-B4 | B3-B0 |
|---|---|---|---|---|
| Hours/Minutes (current and alarms) | `HR_TENS` | `HR_ONES` | `MIN_TENS` | `MIN_ONES` |
| Seconds (current and alarms) | 0 | 0 | `SEC_TENS` | `SEC_ONES` |

### Global Control (`0x072`)

| Bit | Name | Type | Write | Read |
|---|---|---|---|---|
| 0 | EN | Level | 1 = alarms enabled globally | Current EN |
| 1 | RESET | One-time | 1 = stop every ringing alarm | 0 |
| 2 | FAST | Level | 1 = time runs 60 times faster | Current FAST |
| 3 | CLEAR_ERR | One-time | 1 = clear ERROR | 0 |
| 15-4 | | | Write 0 | 0 |

EN and FAST are levels, so every write sets them. To reset or clear the error without changing them, include their current values (for example `0b0111` = RESET with EN and FAST kept on).

### Alarm Select (`0x073`)

Bits 2-0 hold the alarm number, 0 to 4. Values 5 and above are ignored and set ERROR. Only Alarm Settings uses the selection; the alarm time registers are addressed directly.

### Alarm Settings (`0x074`)

The read side doubles as the peripheral's status register.

| Bit | Write | Read |
|---|---|---|
| 0 | EN: 1 enables the selected alarm (level) | EN of the selected alarm |
| 1 | RESET: 1 stops the selected alarm (one-time) | RINGING: the selected alarm is ringing |
| 2 | Write 0 | ANY_RINGING: at least one alarm is ringing |
| 3 | Write 0 | ERROR: an invalid write was ignored (cleared by Global Control CLEAR_ERR) |
| 15-4 | Write 0 | 0 |

To stop the selected alarm and keep it enabled, write `0b11`.

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

- [x] **Register map.** Final 15-register map at `0x070`-`0x07E` (above).
- [x] **Multiple alarms.** Five, at `0x075`-`0x07E`. ALARM_SEL is 3 bits (0-4). `alarm_clock_io` creates one `alarm_ctrl` per alarm.
- [x] **Status bits.** On the read side of Alarm Settings (`0x074`): EN, RINGING, ANY_RINGING, ERROR.
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
