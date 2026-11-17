
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

    IN     AC_Ctrl
    AND    StRinging
    JZERO  Poll

Ring:
    LOAD   AllLEDs
    OUT    LEDs

WaitForSwitch:
    IN     Switches
    AND    SwitchMask
    JZERO  WaitForSwitch

    LOAD   CtrlAck
    OUT    AC_Ctrl

    LOADI  0
    OUT    LEDs

Done:
    JUMP   Done

; Data constants
Time0659:    DW &H0659
Time0700:    DW &H0700

CtrlEnFast:  DW &B0011
CtrlAck:     DW &B0111
CtrlSnooze:  DW &B1011

StRinging:   DW &B00001
StSnoozed:   DW &B01000
StInvalid:   DW &B10000

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
AC_Time:     EQU 160
AC_Sec:      EQU 161
AC_Alarm:    EQU 162
AC_Ctrl:     EQU 163
