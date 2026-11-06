; sndload.asm -- the timer and dispatch routines linked into the SndLoad unit through {$L SNDLOAD.OBJ}, after the unit's
; own code.  Every tick goes through driverEntryPtr into the driver LoadMidiDriver brought in from midi.dax.  The timer
; runs at a PIT reload of 5555h, and the handler chains the old INT 8 handler every third tick so the BIOS clock keeps
; its rate.
;
; The handler's state lives in this segment and is reached through CS: overrides, because the handler runs with
; whatever DS the interrupted code had.

DGROUP  GROUP   DATA                    ; driverEntryPtr lives in the data group
DATA    SEGMENT WORD PUBLIC
        EXTRN   DRIVERENTRYPTR:DWORD
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC             ; no class, so it merges into the unit code segment
        ASSUME  CS:CODE, DS:DGROUP
        PUBLIC  INSTALLTIMER
        PUBLIC  UNINSTALLTIMER
        PUBLIC  DRIVERDISPATCH
        PUBLIC  DRIVERCOMMAND

; The handler's state: the INT 8 handler it replaced, the ticks left until the next chained tick, and the flag that
; keeps a slow driver tick from being entered again.
oldInt8         dd      0
chainCountdown  dw      0
inDriverTick    db      0

; InstallTimer -- save the old INT 8 vector, point INT 8 at timerHandler and raise PIT channel 0 to the 5555h reload.
InstallTimer:
        push    es
        push    ds
        push    ax
        push    bx
        push    cx
        mov     ax,3508h                ; DOS get vector: INT 8, the timer tick
        int     21h
        mov     word ptr cs:[oldInt8],bx
        mov     word ptr cs:[oldInt8+2],es
        mov     dx,offset timerHandler  ; DS:DX = the new handler
        mov     ax,CODE
        mov     ds,ax
        mov     ax,2508h                ; DOS set vector: INT 8
        int     21h
        mov     word ptr cs:[chainCountdown],3
        mov     al,36h                  ; PIT control: channel 0, lo/hi byte, mode 3
        out     43h,al
        mov     ax,5555h                ; the faster reload, written lo then hi
        out     40h,al
        xchg    ah,al
        out     40h,al
        pop     cx
        pop     bx
        pop     ax
        pop     ds
        pop     es
        retf

; UninstallTimer -- put the saved INT 8 vector back and return PIT channel 0 to the BIOS's FFFFh reload.
UninstallTimer:
        push    ds
        push    ax
        push    bx
        push    cx
        mov     dx,word ptr cs:[oldInt8]
        mov     ax,word ptr cs:[oldInt8+2]
        mov     ds,ax                   ; DS:DX = the handler InstallTimer saved
        mov     ax,2508h                ; DOS set vector: INT 8
        int     21h
        mov     ax,0FFFFh               ; the BIOS's 18.2 Hz reload, written lo then hi
        out     40h,al
        xchg    ah,al
        out     40h,al
        pop     cx
        pop     bx
        pop     ax
        pop     ds
        retf

; DriverDispatch -- pass driverSegment to the driver in CX, with function 1 in AH.
DriverDispatch:
        push    bp
        mov     bp,sp
        mov     cx,[bp+6]
        mov     ah,1
        call    dword ptr [DRIVERENTRYPTR]
        pop     bp
        retf    2

; DriverCommand -- call the driver with function 2 in AH.
DriverCommand:
        mov     ah,2
        call    dword ptr [DRIVERENTRYPTR]
        retf

; timerHandler -- the INT 8 handler.  Acknowledge the interrupt, run one driver tick (function 0) unless the last one is
; still running, then every third tick chain the old handler; on the other ticks return from the interrupt.
timerHandler:
        sti
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        push    di
        push    ds
        push    si
        mov     al,20h                  ; end of interrupt to the PIC
        out     20h,al
        cmp     byte ptr cs:[inDriverTick],0
        je      enterDriver
        jmp     countTick
enterDriver:
        mov     byte ptr cs:[inDriverTick],1
        mov     ax,DGROUP
        mov     ds,ax
        mov     ah,0
        call    dword ptr [DRIVERENTRYPTR]
        mov     byte ptr cs:[inDriverTick],0
countTick:
        dec     word ptr cs:[chainCountdown]
        jnz     tickDone
        mov     word ptr cs:[chainCountdown],3
        pop     si
        pop     ds
        pop     di
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8]
tickDone:
        pop     si
        pop     ds
        pop     di
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret

CODE    ENDS
        END
