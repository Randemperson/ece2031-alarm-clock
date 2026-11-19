
; alarm_demo.asm
; SCOMP Alarm Clock Demo
; Set time to 06:59, alarm at 07:00
; Enable fast mode, poll status
; Wait for SW0 before acknowledging

ORG 0

Start:
    LOAD   Time0659
    OUT    AC_Time

    LOAD   Time0700
    OUT    AC_Alarm

    LOAD   CtrlEnFast
    OUT    AC_Ctrl

Poll:
    IN     AC_Time
    OUT    Hex0

    IN     AC_Sec
    OUT    Hex1

    IN     AC_Status
    AND    StRinging
    JZERO  Poll

Ring:
    LOAD   AllLEDs
    OUT    LEDs

WaitForSwitch:
    IN     Switches
    AND    SwitchMask
    JZERO  WaitForSwitch

    LOAD   StReset
    OUT    AC_Status

    LOADI  0
    OUT    LEDs

Done:
    JUMP   Done

; Data constants
Time0659:    DW &H0659
Time0700:    DW &H0700

; CONTROL (BASE+5): bit 0 EN, bit 1 FAST
CtrlEnFast:  DW &B11

; STATUS (BASE+4) read: bit 0 RINGING, bit 1 ERROR
StRinging:   DW &B01
StInvalid:   DW &B10
; STATUS (BASE+4) write: bit 0 RESET (stop ringing), bit 1 CLEAR_ERR
StReset:     DW &B01
StClearErr:  DW &B10

AllLEDs:     DW &B1111111111
SwitchMask:  DW &H0001

; Standard SCOMP I/O
Switches:    EQU 000
LEDs:        EQU 001
Timer:       EQU 002
Hex0:        EQU 004
Hex1:        EQU 005

; Alarm peripheral I/O addresses
; These must match alarm_clock_io.vhd
; BASE = 0x070 (decimal 112). Allowed range is 0x070-0x07F.
AC_Time:     EQU 112
AC_Sec:      EQU 113
AC_Alarm:    EQU 114
AC_AlarmSec: EQU 115
AC_Status:   EQU 116
AC_Ctrl:     EQU 117
AC_AlarmSel: EQU 118
AC_AlarmSet: EQU 119
