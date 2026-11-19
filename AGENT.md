# AGENT.md

Notes for AI coding agents working in this repo. Read `README.md` for the full spec, team roles and file ownership.

## I/O address constraint (from the professor)

- Peripherals may only use I/O addresses **`0x070` to `0x07F`**. Never assign anything outside this range.
- The alarm clock peripheral's `BASE` is **`0x070`**. Its 8 registers use `0x070` to `0x077`. `0x078` to `0x07F` are free for future use.
- `BASE` must be a multiple of 8. `alarm_clock_io.vhd` matches `IO_ADDR(10 downto 3)` against `BASE_ADDR` and uses `IO_ADDR(2 downto 0)` as the register number.
- The base project's own devices use `0x000` to `0x005` (Switches, LEDs, Timer, Hex0, Hex1). Leave them alone.

## Register map

| Address | `.asm` EQU | Register |
|---|---|---|
| `0x070` | 112 | TIME (BCD `HHMM`) |
| `0x071` | 113 | SECONDS (BCD `00SS`) |
| `0x072` | 114 | ALARM (BCD `HHMM`) |
| `0x073` | 115 | ALARM_SEC (BCD `00SS`) |
| `0x074` | 116 | STATUS: read b0 RINGING, b1 ERROR. Write 1 to b0 = reset alarm, 1 to b1 = clear ERROR |
| `0x075` | 117 | CONTROL: b0 EN (global enable), b1 FAST |
| `0x076` | 118 | ALARM_SEL: b1-0 pick the alarm (no effect yet, `alarm_ctrl` holds one alarm) |
| `0x077` | 119 | ALARM_SET: TBD, writes ignored, reads 0 |

SCASM `EQU` values are decimal (`112` = `0x70`). Use `&H` for hex literals.

## Keep these in sync

A change to the address or register map has to be made in all of these:

- `alarm_clock_io.vhd`: `BASE_ADDR` generic default, `REG_*` and bit constants, header comment
- `alarm_demo.asm`: `AC_*` EQUs and bit constants, then reassemble `alarm_clock.mif`
- `alarm_clock_tb.vhd`: `ADDR_*` constants (Verification owner; still on the old `0x0A0` four-register map)
- `README.md`: Register map section
- `register_map.xlsx`: bit-level table
- The group spec doc (outside the repo; a person has to update it)

## Repo rules

- Only a file's owner edits it (see the ownership table in `README.md`). Note needed changes to someone else's file instead of making them.
- Do not edit `.bdf` or `.qsf` files unless asked; they belong to the integration owner and do not merge.
- Do not commit `db/`, `output_files/` or other Quartus build output.
- VHDL uses `ieee.numeric_std`. One clock (`clk_10MHz`), active-low async `resetn`.
