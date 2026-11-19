
; alarm_demo.asm
; SCOMP Alarm Clock Demo
; Set time to 06:59:00, alarm 1 at 07:00:00
; Enable alarm 1 and fast mode, poll for ringing
; Wait for SW0 before resetting the alarm

ORG 0

Start:
    LOAD   Time0659
    OUT    AC_Time          ; also resets seconds to 00

    LOAD   Time0700
    OUT    AC_Alarm1        ; alarm 1 hours/minutes
    LOADI  0
    OUT    AC_Alarm1Sec     ; alarm 1 seconds = 00

    LOAD   SetEnA1
    OUT    AC_AlarmSet      ; enable alarm 1 (all other alarms off)

    LOAD   GEnFast
    OUT    AC_GCtrl         ; global enable + fast mode

Poll:
    IN     AC_Time
    OUT    Hex0

    IN     AC_Sec
    OUT    Hex1

    IN     AC_GCtrl         ; read side of Global Control has ANY_RINGING
    AND    GAnyRinging
    JZERO  Poll

Ring:
    LOAD   AllLEDs
    OUT    LEDs

WaitForSwitch:
    IN     Switches
    AND    SwitchMask
    JZERO  WaitForSwitch

    ; Reset only alarm 1, keeping every alarm's EN bit as it is.
    ; Reading Alarm Settings gives RINGING in the RESET positions, so mask
    ; down to the EN bits first or every ringing alarm would be reset.
    IN     AC_AlarmSet
    AND    EnMask
    OR     ResetA1
    OUT    AC_AlarmSet

    LOADI  0
    OUT    LEDs

Done:
    JUMP   Done

; Data constants
Time0659:    DW &H0659
Time0700:    DW &H0700

; GLOBAL CONTROL (0x072) write: bit 0 EN, bit 1 RESET (all alarms), bit 2 FAST, bit 3 CLEAR_ERR
; EN and FAST are levels, so every write must include them.
GEnFast:     DW &B0101
GResetKeep:  DW &B0111
GClearKeep:  DW &B1101
; GLOBAL CONTROL read: bit 0 EN, bit 1 ANY_RINGING, bit 2 FAST, bit 3 ERROR
GAnyRinging: DW &B0010
GError:      DW &B1000

; ALARM SETTINGS (0x073): alarm n uses bit 2(n-1) for EN and bit 2(n-1)+1
; for RESET (write) / RINGING (read). All EN bits are levels.
SetEnA1:     DW &H0001
ResetA1:     DW &H0002
EnMask:      DW &H0555      ; all six EN bits

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
AC_AlarmSet:  EQU 115       ; 0x073
AC_Alarm1:    EQU 116       ; 0x074
AC_Alarm1Sec: EQU 117       ; 0x075
AC_Alarm2:    EQU 118       ; 0x076
AC_Alarm2Sec: EQU 119       ; 0x077
AC_Alarm3:    EQU 120       ; 0x078
AC_Alarm3Sec: EQU 121       ; 0x079
AC_Alarm4:    EQU 122       ; 0x07A
AC_Alarm4Sec: EQU 123       ; 0x07B
AC_Alarm5:    EQU 124       ; 0x07C
AC_Alarm5Sec: EQU 125       ; 0x07D
AC_Alarm6:    EQU 126       ; 0x07E
AC_Alarm6Sec: EQU 127       ; 0x07F
