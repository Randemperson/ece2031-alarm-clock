
; alarm_demo.asm
; SCOMP Alarm Clock Demo
; Set time to 06:59:00, alarm 0 at 07:00:00
; Enable alarm 0 and fast mode, poll for ringing
; Wait for SW0 before resetting the alarm

ORG 0

Start:
    LOAD   Time0659
    OUT    AC_Time          ; also resets seconds to 00

    LOAD   Time0700
    OUT    AC_Alarm0        ; alarm 0 hours/minutes
    LOADI  0
    OUT    AC_Alarm0Sec     ; alarm 0 seconds = 00

    LOADI  0
    OUT    AC_AlarmSel      ; select alarm 0
    LOAD   SetEn
    OUT    AC_AlarmSet      ; enable alarm 0

    LOAD   GEnFast
    OUT    AC_GCtrl         ; global enable + fast mode

Poll:
    IN     AC_Time
    OUT    Hex0

    IN     AC_Sec
    OUT    Hex1

    IN     AC_AlarmSet      ; read side of Alarm Settings is the status
    AND    StAnyRinging
    JZERO  Poll

Ring:
    LOAD   AllLEDs
    OUT    LEDs

WaitForSwitch:
    IN     Switches
    AND    SwitchMask
    JZERO  WaitForSwitch

    LOAD   GResetKeep       ; RESET all alarms, keep EN and FAST set
    OUT    AC_GCtrl

    LOADI  0
    OUT    LEDs

Done:
    JUMP   Done

; Data constants
Time0659:    DW &H0659
Time0700:    DW &H0700

; GLOBAL CONTROL (0x072) write: bit 0 EN, bit 1 RESET, bit 2 FAST, bit 3 CLEAR_ERR
; EN and FAST are levels, so every write must include them.
GEnFast:     DW &B0101
GResetKeep:  DW &B0111
GClearKeep:  DW &B1101

; ALARM SETTINGS (0x074) write: bit 0 EN, bit 1 RESET (selected alarm)
SetEn:       DW &B01
SetResetEn:  DW &B11

; ALARM SETTINGS (0x074) read: bit 0 EN, bit 1 RINGING (selected alarm),
;                              bit 2 ANY_RINGING, bit 3 ERROR
StRinging:   DW &B0010
StAnyRinging: DW &B0100
StError:     DW &B1000

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
AC_Time:      EQU 112       ; 0x070
AC_Sec:       EQU 113       ; 0x071
AC_GCtrl:     EQU 114       ; 0x072
AC_AlarmSel:  EQU 115       ; 0x073
AC_AlarmSet:  EQU 116       ; 0x074
AC_Alarm0:    EQU 117       ; 0x075
AC_Alarm0Sec: EQU 118       ; 0x076
AC_Alarm1:    EQU 119       ; 0x077
AC_Alarm1Sec: EQU 120       ; 0x078
AC_Alarm2:    EQU 121       ; 0x079
AC_Alarm2Sec: EQU 122       ; 0x07A
AC_Alarm3:    EQU 123       ; 0x07B
AC_Alarm3Sec: EQU 124       ; 0x07C
AC_Alarm4:    EQU 125       ; 0x07D
AC_Alarm4Sec: EQU 126       ; 0x07E
