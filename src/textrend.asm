; textrend.asm -- the three near glyph blitters RenderCharCga, RenderCharEga and RenderCharTandy, linked
; into the TextRend unit through the TEXTREND.OBJ link directive. The linked code follows all the Pascal
; code, including the empty initialization section.
;
; RenderChar stages the glyph in glyphBuf and passes
;   (col, row: Word; fg, bg, glyphIdx: Byte)   near; glyphIdx is unused here.
; glyphBuf and attrTable are data-segment variables, referenced as EXTRN so they relocate with the data
; segment.
DGROUP  GROUP   DATA                    ; glyphBuf and attrTable live in the data group
DATA    SEGMENT WORD PUBLIC
        EXTRN   GLYPHBUF:BYTE
        EXTRN   ATTRTABLE:BYTE
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC             ; no class, so it merges into the unit code segment
        ASSUME  CS:CODE, DS:DGROUP      ; DS stays DGROUP, so data references need no override
        PUBLIC  RENDERCHARCGA
        PUBLIC  RENDERCHAREGA
        PUBLIC  RENDERCHARTANDY

; --------------------------------------------------------------------------
; RenderCharCga -- 4bpp-ish 2-plane CGA (two interleaved banks), 2 halves x
; 4 columns x 4 rows.  fg/bg -> attrTable[fg]/[bg] pattern bytes in dl/dh.
; --------------------------------------------------------------------------
RENDERCHARCGA   PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     ax,[bp+0Ah]             ; row
        mov     bx,140h
        mul     bx
        mov     bx,[bp+0Ch]             ; col
        shl     bx,1
        add     ax,bx
        mov     di,ax
        xor     bx,bx
        mov     bl,[bp+8]               ; fg
        mov     dl,[bx+ATTRTABLE]
        mov     bl,[bp+6]               ; bg
        mov     dh,[bx+ATTRTABLE]
        xor     bx,bx
        mov     ah,1
        mov     cx,4
cga_outer:
        push    cx
        mov     cx,0B800h
        mov     es,cx
        mov     cx,2
        inc     di
cga_midA:
        push    cx
        mov     cx,4
        mov     al,0
cga_innerA:
        test    byte ptr [bx+GLYPHBUF],ah
        je      cga_skipA
        or      al,dl
        jmp     short cga_afterA
        nop
cga_skipA:
        or      al,dh
cga_afterA:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    cga_innerA
        mov     es:[di],al
        dec     di
        pop     cx
        loop    cga_midA
        inc     bx
        inc     di
        mov     ah,1
        mov     al,0
        mov     cx,0BA00h
        mov     es,cx
        mov     cx,2
        inc     di
cga_midB:
        push    cx
        mov     cx,4
        mov     al,0
cga_innerB:
        test    byte ptr [bx+GLYPHBUF],ah
        je      cga_skipB
        or      al,dl
        jmp     short cga_afterB
        nop
cga_skipB:
        or      al,dh
cga_afterB:
        rol     dl,1
        rol     dl,1
        rol     dh,1
        rol     dh,1
        rol     ah,1
        loop    cga_innerB
        mov     es:[di],al
        dec     di
        pop     cx
        loop    cga_midB
        inc     bx
        add     di,51h
        pop     cx
        loop    cga_outer
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah
RENDERCHARCGA   ENDP

; --------------------------------------------------------------------------
; RenderCharEga -- planar, via GC latch/bit-mask; 8 rows, fg/bg written by
; masking the plane with the glyph bit-mask register.
; --------------------------------------------------------------------------
RENDERCHAREGA   PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     ax,0A000h
        mov     es,ax
        mov     ax,[bp+0Ah]             ; row
        mov     bx,140h
        mul     bx
        add     ax,[bp+0Ch]             ; + col
        mov     di,ax
        mov     dx,3CEh
        mov     ax,0A05h
        out     dx,ax
        mov     ah,0
        mov     al,3
        out     dx,ax
        mov     ax,7
        out     dx,ax
        xor     bx,bx
        mov     cx,8
ega_row:
        mov     ah,[bx+GLYPHBUF]
        mov     al,8
        out     dx,ax
        mov     al,[bp+8]               ; fg
        and     es:[di],al
        not     ah
        mov     al,8
        out     dx,ax
        mov     al,[bp+6]               ; bg
        and     es:[di],al
        add     di,28h
        inc     bx
        loop    ega_row
        mov     ax,5
        out     dx,ax
        mov     ax,0FF08h
        out     dx,ax
        mov     ax,3
        out     dx,ax
        mov     ax,0F07h
        out     dx,ax
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah
RENDERCHAREGA   ENDP

; --------------------------------------------------------------------------
; renderCharTandy -- 16-color 4-bank Tandy, 2 outer
; passes.  fg=dh, bg=dl (note: opposite dl/dh order vs the CGA blitter).
; --------------------------------------------------------------------------
RENDERCHARTANDY PROC NEAR
        push    bp
        mov     bp,sp
        push    ss
        push    ds
        mov     ax,[bp+0Ah]             ; row
        mov     bx,140h
        mul     bx
        mov     bx,[bp+0Ch]             ; col
        shl     bx,1
        shl     bx,1
        add     ax,bx
        mov     di,ax
        mov     dl,[bp+6]               ; bg
        mov     dh,[bp+8]               ; fg
        xor     bx,bx
        mov     ah,1
        mov     cx,2
tdy_bank:
        push    cx
        ; --- bank 0 (extra add di,3) ---
        mov     cx,0B800h
        mov     es,cx
        mov     cx,4
        add     di,3
tdy_colB0:
        push    cx
        mov     cx,2
        mov     al,0
tdy_rowB0:
        test    byte ptr [bx+GLYPHBUF],ah
        je      tdy_sB0
        or      al,dh
        jmp     short tdy_aB0
        nop
tdy_sB0:
        or      al,dl
tdy_aB0:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    tdy_rowB0
        mov     es:[di],al
        dec     di
        pop     cx
        loop    tdy_colB0
        add     di,4
        inc     bx
        ; --- bank 1 ---
        mov     cx,0BA00h
        mov     es,cx
        mov     cx,4
tdy_colB1:
        push    cx
        mov     cx,2
        mov     al,0
tdy_rowB1:
        test    byte ptr [bx+GLYPHBUF],ah
        je      tdy_sB1
        or      al,dh
        jmp     short tdy_aB1
        nop
tdy_sB1:
        or      al,dl
tdy_aB1:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    tdy_rowB1
        mov     es:[di],al
        dec     di
        pop     cx
        loop    tdy_colB1
        add     di,4
        inc     bx
        ; --- bank 2 ---
        mov     cx,0BC00h
        mov     es,cx
        mov     cx,4
tdy_colB2:
        push    cx
        mov     cx,2
        mov     al,0
tdy_rowB2:
        test    byte ptr [bx+GLYPHBUF],ah
        je      tdy_sB2
        or      al,dh
        jmp     short tdy_aB2
        nop
tdy_sB2:
        or      al,dl
tdy_aB2:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    tdy_rowB2
        mov     es:[di],al
        dec     di
        pop     cx
        loop    tdy_colB2
        add     di,4
        inc     bx
        ; --- bank 3 (tail: inc bx then add di,0A1h) ---
        mov     cx,0BE00h
        mov     es,cx
        mov     cx,4
tdy_colB3:
        push    cx
        mov     cx,2
        mov     al,0
tdy_rowB3:
        test    byte ptr [bx+GLYPHBUF],ah
        je      tdy_sB3
        or      al,dh
        jmp     short tdy_aB3
        nop
tdy_sB3:
        or      al,dl
tdy_aB3:
        push    cx
        mov     cx,4
        rol     dl,cl
        mov     cx,4
        rol     dh,cl
        rol     ah,1
        pop     cx
        loop    tdy_rowB3
        mov     es:[di],al
        dec     di
        pop     cx
        loop    tdy_colB3
        inc     bx
        add     di,0A1h
        pop     cx
        dec     cx
        je      tdy_done
        jmp     tdy_bank
tdy_done:
        pop     ds
        pop     ss
        pop     bp
        ret     0Ah
RENDERCHARTANDY ENDP
CODE    ENDS
        END
