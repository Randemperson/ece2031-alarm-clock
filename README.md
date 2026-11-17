# Programmable Alarm Clock Peripheral for SCOMP

ECE 2031 final project. A time-based peripheral for SCOMP that keeps the time of day in hardware and lets a SCOMP program schedule an alarm.

SCOMP talks to the peripheral only through `IN` and `OUT`. All timekeeping, comparison, and alarm logic lives in VHDL. SCOMP programs write registers and read status; they never count time themselves.

> **Status: draft.** The spec and register map below are defaults until the group finalizes the spec doc. Anything undecided is listed under [Decisions pending](#decisions-pending) and marked `TODO` in the source.

## Behavior spec (draft)

- **Time format.** BCD, 24-hour. `HHMM` fits in one 16-bit word: `0x1730` is 17:30, `0x0000` is midnight, `0x1200` is noon. Seconds are tracked in hardware and read from a separate register.
- **Rollover.** 23:59:59 goes to 00:00:00.
- **Fast mode.** A control bit makes time run 60 times faster (one simulated minute per real second) for demos.
- **Firing.** When the alarm is enabled and the time *ticks into* `HHMM:00` matching the alarm, the alarm starts ringing. Writing the time directly to the alarm time does not fire it.
- **Stopping.** Ringing stops when SCOMP writes ACK, or by itself after 60 seconds.
- **Snooze (extension).** Stops the ringing and fires again 5 minutes later.
- **Invalid writes.** A write that is not valid BCD time (`0x2500`, `0x1A30`, `0x1260`) is ignored and sets the INVALID status bit.

## Register map

`BASE` is a placeholder (`0x0A0`) until we confirm a free block. The base project already uses `0x000` to `0x005`.

| Address | Name | Write | Read |
|---|---|---|---|
| BASE+0 | TIME | Set current `HHMM` | Current `HHMM` |
| BASE+1 | SECONDS | Set current seconds | Current seconds |
| BASE+2 | ALARM | Set alarm `HHMM` | Alarm `HHMM` |
| BASE+3 | ALARM_SEC | Set alarm seconds | Alarm seconds |
| BASE+4 | STATUS | TBD | Status bits (below) |
| BASE+5 | CONTROL | Control bits (below) | Current config |

This map comes from the group spec doc. The `.vhd` stubs, `alarm_demo.asm`, and the testbench still use the earlier four-register map (TIME, SECONDS, ALARM, CTRL/STATUS at BASE+0 to BASE+3) and need to be updated by their owners.

### CONTROL (write to BASE+5)

| Bit | Name | Type | Meaning |
|---|---|---|---|
| 0 | RINGING | Level | 1 = ring |
| 1 | ACK | One-time action | Write 1 to acknowledge a ringing alarm |
| 2 | FAST | Level | 1 enables fast mode (time runs 60 times faster) |
| 3 | CLEAR_ERR | One-time action | Write 1 to clear the invalid time-write error |
| 15-4 | reserved | | Write 0 |

RINGING and FAST are levels, so every write to CONTROL sets them. To acknowledge or clear the error without changing them, write ACK or CLEAR_ERR together with their current values.

### STATUS (read from BASE+4)

The spec doc only says that STATUS reports whether the alarm is ringing. The other bits below are carried over from the earlier draft; EN and SNOOZED have no matching control bit in the new map.

| Bit | Name | Meaning |
|---|---|---|
| 0 | RINGING | Alarm is ringing now |
| 1 | EN | Current enable setting |
| 2 | FAST | Current fast-mode setting |
| 3 | SNOOZED | Waiting to fire again after a snooze |
| 4 | INVALID | An invalid BCD write was ignored. Cleared by CLEAR_ERR. |
| 15-5 | | Read as 0 |

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
| `alarm_ctrl.vhd` | 2 Alarm | Alarm register, compare, ringing state machine |
| `alarm_clock_io.vhd` | 3 Bus | The peripheral itself: address decode, write latching, read mux, connects the three modules above |
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

- [ ] **BASE address.** Placeholder is `0x0A0`. Must be a multiple of 8, since six addresses need 3 register-select bits.
- [ ] **CONTROL bit 0.** The spec doc names it RINGING (1 = ring). Is this the alarm enable? The new map has no other enable bit.
- [ ] **STATUS bits.** Only RINGING is defined in the spec doc. Which other bits exist, and what does a write to STATUS do?
- [x] **Seconds.** SECONDS is at BASE+1 and the alarm has its own seconds register at BASE+3.
- [ ] **Alarm seconds and firing.** The behavior spec above fires at `HHMM:00` on the minute tick. With ALARM_SEC the compare must include seconds, which changes `alarm_ctrl` and its ports.
- [ ] **Consistent TIME and SECONDS reads.** Two `IN`s can straddle a rollover. Snapshot seconds when TIME is read?
- [ ] **Fast-mode ratio.** 10 MHz does not divide evenly by 60. Accept the small error or choose another ratio?
- [ ] **Timeout in fast mode.** The 60-second timeout counts simulated seconds, so in fast mode a ring lasts 1 real second. Keep, or time it in real seconds?
- [ ] **Setting the time while ringing or snoozed.** Keep ringing, stop, or cancel the snooze?
- [ ] **Changing the alarm or clearing EN while ringing.** Does clearing EN silence the alarm?
- [x] **Clearing INVALID.** Cleared by writing the CLEAR_ERR control bit.
- [ ] **Alarm reset value.** `0x0000` with EN = 0?
- [ ] **Does writing TIME restart the 1 Hz divider** so the first second is a full second?
- [ ] **Snooze.** In or out of scope? The new CONTROL map has no SNOOZE bit. Refire by counting 5 minute rollovers, or by adding 5 minutes to the alarm?
- [ ] **RINGING output pin.** LED only, or a buzzer on a GPIO pin?
