; joystick.asm -- ReadJoystick, the PC game-port reader linked into the Joystick unit through the
; JOYSTICK.OBJ link directive. It times the capacitor discharge on port 201h in registers and keeps no
; Pascal frame.
;
; ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;  far
; The result is in AL.
CODE    SEGMENT BYTE PUBLIC             ; no class, so it merges into the unit code segment
        ASSUME  CS:CODE
        PUBLIC  READJOYSTICK

READJOYSTICK    PROC FAR
        push    bp
        mov     bp,sp
        cmp     byte ptr [bp+12h],1     ; joy# must be 1 or 2
        jz      valid
        cmp     byte ptr [bp+12h],2
        jz      valid
        mov     al,0                    ; bad joy# -> False
        pop     bp
        ret     0Eh
valid:
        mov     ah,1                    ; button/axis bit mask (joystick 1: bit 0; joystick 2: bit 2)
        xor     bx,bx
        cmp     byte ptr [bp+12h],2
        jnz     m_set
        shl     ah,1
        shl     ah,1
m_set:
        mov     bx,1
        xor     cx,cx
        mov     al,0FFh
        mov     dx,201h                 ; PC game port
        out     dx,al                   ; start capacitor discharge
xLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     xDone
        inc     bx
        loop    xLoop
        mov     al,0                    ; X axis timed out -> False
        pop     bp
        ret     0Eh
xDone:
        mov     cx,1FFFh                ; settle delay proportional to leftover count
        sub     cx,bx
        jc      xStore
        loop    $
xStore:
        les     di,[bp+0Eh]
        mov     es:[di],bx              ; xRaw := count
        shl     ah,1                    ; advance mask to Y axis
        xor     cx,cx
yLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     yPre
        loop    yLoop
        mov     al,0
        pop     bp
        ret     0Eh
yPre:
        mov     bx,1
        xor     cx,cx
        mov     al,0FFh
        out     dx,al
yLoop2:
        in      al,dx
        not     al
        test    al,ah
        jnz     yDone
        inc     bx
        loop    yLoop2
        mov     al,0
        pop     bp
        ret     0Eh
yDone:
        mov     cx,1FFFh
        sub     cx,bx
        jc      xStore                  ; reuse the X-store path (shared)
        loop    $
        les     di,[bp+0Ah]
        mov     es:[di],bx              ; yRaw := count
        shr     ah,1                    ; back to the button bit
        xor     cx,cx
bLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     bDone
        loop    bLoop
        mov     al,0
        pop     bp
        ret     0Eh
bDone:
        mov     cx,4
        shr     al,cl                   ; align button bits into low nibble
        les     di,[bp+06h]
        mov     es:[di],al              ; buttons := bits
        mov     al,1                    ; success
        pop     bp
        ret     0Eh
READJOYSTICK    ENDP
CODE    ENDS
        END
