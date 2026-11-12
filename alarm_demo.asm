; alarm_demo.asm
; Owner: SCOMP Software & Demo
;
; Demo skeleton for the alarm clock peripheral.
;   1. Set the time to 06:59 and the alarm to 07:00.
;   2. Enable the alarm in fast mode (one simulated minute per real second).
;   3. Show the time on the hex displays while polling for RINGING.
;   4. Acknowledge the alarm.
;
; All timekeeping happens in the peripheral. This program only writes
; registers and reads status.

ORG 0

Start:
	LOAD   Time0659
	OUT    AC_Time          ; also resets seconds to 00
	LOAD   Time0700
	OUT    AC_Alarm
	LOAD   CtrlEnFast
	OUT    AC_Ctrl

Poll:
	IN     AC_Time
	OUT    Hex0             ; BCD shows correctly on the hex display as-is
	IN     AC_Sec
	OUT    Hex1
	IN     AC_Ctrl          ; reads STATUS
	AND    StRinging
	JZERO  Poll             ; not ringing yet

Ring:
	LOAD   AllLEDs
	OUT    LEDs
	; TODO: wait for a switch before acknowledging, so the audience sees it ring.
	; TODO: second demo path that writes CtrlSnooze instead and shows the refire.

	LOAD   CtrlAck          ; EN and FAST are levels, so they are rewritten here
	OUT    AC_Ctrl
	LOADI  0
	OUT    LEDs

Done:
	; TODO: keep showing the time, or loop back for another demo case.
	JUMP   Done

; Time constants (BCD HHMM). These are too big for LOADI, which only holds
; -1024 to 1023, so they live in memory.
Time0659:   DW &H0659
Time0700:   DW &H0700

; CTRL write values: bit 0 EN, bit 1 FAST, bit 2 ACK, bit 3 SNOOZE
CtrlEnFast: DW &B0011
CtrlAck:    DW &B0111       ; ACK, keeping EN and FAST set
CtrlSnooze: DW &B1011       ; SNOOZE, keeping EN and FAST set

; STATUS read masks: bit 0 RINGING, 1 EN, 2 FAST, 3 SNOOZED, 4 INVALID
StRinging:  DW &B00001
StSnoozed:  DW &B01000
StInvalid:  DW &B10000

AllLEDs:    DW &B1111111111

; IO address constants (from the base project)
Switches:   EQU 000
LEDs:       EQU 001
Timer:      EQU 002
Hex0:       EQU 004
Hex1:       EQU 005

; Alarm clock peripheral.
; TODO: placeholder BASE = 0xA0 (decimal 160). Must match BASE_ADDR in
;       alarm_clock_io.vhd.
AC_Time:    EQU 160         ; BASE+0
AC_Sec:     EQU 161         ; BASE+1
AC_Alarm:   EQU 162         ; BASE+2
AC_Ctrl:    EQU 163         ; BASE+3  CTRL on write, STATUS on read
