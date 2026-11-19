# AGENT.md

Notes for AI coding agents working in this repo. Read `README.md` for the full spec, team roles and file ownership.

## I/O address constraint (from the professor)

- Peripherals may only use I/O addresses **`0x070` to `0x07F`**. Never assign anything outside this range.
- The alarm clock peripheral's `BASE` is **`0x070`**. Its 16 registers use all of `0x070` to `0x07F`.
- `BASE` must be a multiple of 16. `alarm_clock_io.vhd` matches `IO_ADDR(10 downto 4)` against `BASE_ADDR` and uses `IO_ADDR(3 downto 0)` as the register number.
- The base project's own devices use `0x000` to `0x005` (Switches, LEDs, Timer, Hex0, Hex1). Leave them alone.

## Register map (FINAL)

The group has fixed this map. All new changes must use it; do not add, move or renumber registers or bits.

| Address | `.asm` EQU | Register |
|---|---|---|
| `0x070` | 112 | Current Hours/Minutes (BCD `HHMM`) |
| `0x071` | 113 | Current Seconds (BCD `00SS`) |
| `0x072` | 114 | Global Control. Write: b0 EN, b1 RESET (all alarms), b2 FAST, b3 CLEAR_ERR. Read: b0 EN, b1 ANY_RINGING, b2 FAST, b3 ERROR |
| `0x073` | 115 | Alarm Settings. Alarm n (1-6) uses b[2(n-1)] EN and b[2(n-1)+1] RESET (write) / RINGING (read). Bits 15-12 unused |
| `0x074` + 2(n-1) | 116 + 2(n-1) | Alarm n Hours/Minutes (BCD `HHMM`), n = 1-6 |
| `0x075` + 2(n-1) | 117 + 2(n-1) | Alarm n Seconds (BCD `00SS`), n = 1-6 |

EN and FAST are levels (every write sets them; one Alarm Settings write sets all six alarm EN bits); RESET and CLEAR_ERR are one-time actions. An alarm can fire only when the global EN and its own EN are both 1. Invalid BCD writes are ignored and set ERROR. Alarms are numbered 1-6 in docs and `.asm`, 0-5 inside the VHDL.

Read-modify-write of Alarm Settings must `AND 0x0555` before ORing in a RESET bit, because reads return RINGING in the RESET positions.

SCASM `EQU` values are decimal (`112` = `0x70`). Use `&H` for hex literals.

## Keep these in sync

A change to the address or register map has to be made in all of these:

- `alarm_clock_io.vhd`: `BASE_ADDR` generic default, `R_*` and bit constants, header comment
- `alarm_ctrl.vhd`: port list, if what one alarm stores changes
- `alarm_demo.asm`: `AC_*` EQUs and bit constants, then reassemble `alarm_clock.mif`
- `alarm_clock_tb.vhd`: `ADDR_*` constants
- `README.md`: Register map section
- `register_map.xlsx`: bit-level table
- `diagrams/block_diagram.py`: address range label, then re-render the PNG
- The group spec doc and the submitted register map PDF (outside the repo; a person has to update them)

## Repo rules

- Only a file's owner edits it (see the ownership table in `README.md`). Note needed changes to someone else's file instead of making them.
- Do not edit `.bdf` or `.qsf` files unless asked; they belong to the integration owner and do not merge.
- Do not commit `db/`, `output_files/` or other Quartus build output.
- VHDL uses `ieee.numeric_std`. One clock (`clk_10MHz`), active-low async `resetn`.
