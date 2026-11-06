; blit.asm -- the assembly half of the Blit unit: the per-mode tile blitters that
; BlitTileCell and BlitTileClipped dispatch to, and the two scanline loops they share.
;
; Every procedure is NEAR, called from inside the unit's own segment.  Arguments are
; in Pascal order, so the last one declared lies nearest bp.  The span tables are
; data-segment variables, referenced as EXTRN so they relocate with the data segment.

        LOCALS

DGROUP  GROUP   DATA                    ; the span tables live in the data group
DATA    SEGMENT WORD PUBLIC
        EXTRN   SPANACTIVE:BYTE         ; byte per view scanline: row touched since the last flush
        EXTRN   SPANY:WORD              ; word per row: screen byte of the leftmost dirty cell
        EXTRN   SPANX0:WORD             ; word per row: picture offset of the first dirty byte
        EXTRN   SPANX1:WORD             ; word per row: picture offset of the last dirty byte
DATA    ENDS

; TImgBuf (blit.pas) fields the blitters touch
imgHeight    EQU 0
imgWidth     EQU 2
imgSize      EQU 11h            ; bytes in one image of the set
imgTransp    EQU 13h            ; far pointer to the mask plane
imgData      EQU 17h            ; the pixels, inline after the header

; Every procedure here shares one frame, and the row loops run inside it.
; Arguments:
argDest      EQU 4              ; dest: PImgBuf
argGfx       EQU 8              ; gfx:  PImgBuf, the tile set
; BLITCELLCGA, BLITCELLCGAMASKED, BLITCELLEGA, BLITCELLEGAMASKED, BLITCELLTANDY and BLITCELLTANDYMASKED:
cellTile     EQU 0Ch            ; tileIdx
cellY        EQU 0Eh            ; screenY, in 8-scanline cells
cellX        EQU 10h            ; screenX, in cells
; BLITCLIPPEDCGA, BLITCLIPPEDEGA and BLITCLIPPEDTANDY:
clipFlag     EQU 0Ch            ; bit 0 masked, bit 2 save what is covered
clipTile     EQU 0Eh
clipY        EQU 10h
clipX        EQU 12h
argUnder     EQU 14h            ; under: PImgBuf, receives the covered pixels
; Locals:
maskPtr      EQU -4             ; far pointer, copy of gfx^.transp
spanLeft     EQU -6             ; value recorded into spanY
viewRow      EQU -8             ; first scanline, indexes the span tables
rowCount     EQU -0Ah
destOff      EQU -0Ch           ; running offset into dest^.data
srcOff       EQU -0Eh           ; running offset into gfx^.data (and the mask)
rowBytes     EQU -10h           ; bytes copied per scanline
destSkip     EQU -12h           ; dest bytes right of the tile
leftBytes    EQU -14h           ; dest bytes left of the tile
skipRight    EQU -16h           ; tile bytes clipped off the right
skipLeft     EQU -18h           ; tile bytes clipped off the left
saveFlag     EQU -1Ah           ; byte: copy the covered pixels to under first
saveOff      EQU -1Ch           ; running offset into under^.data

CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE, DS:DGROUP
        PUBLIC  BLITCELLCGA, BLITCELLCGAMASKED, BLITCLIPPEDCGA, BLITCELLEGA, BLITCELLEGAMASKED, BLITCLIPPEDEGA
        PUBLIC  BLITCELLTANDY, BLITCELLTANDYMASKED, BLITCLIPPEDTANDY

; BLITCELLCGA, BLITCELLEGA and BLITCELLTANDY draw tile tileIdx of gfx into dest at cell (screenX, screenY) whole, and
; BLITCELLCGAMASKED, BLITCELLEGAMASKED and BLITCELLTANDYMASKED draw it through the tile's mask. BLITCLIPPEDCGA,
; BLITCLIPPEDEGA and BLITCLIPPEDTANDY do the same for a tile that may hang off dest's edges, and can first save the
; pixels it covers into under. Each group has one entry per display mode, and the mode fixes the bytes per 8-pixel cell
; row: CGA 2, EGA 4, Tandy 4.

BLITCELLCGA PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLCGA ENDP

BLITCELLCGAMASKED PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLCGAMASKED ENDP

BLITCLIPPEDCGA PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@draw:
        mov     ax,[bp+leftBytes]
        shl     ax,1
        mov     [bp+leftBytes],ax
        mov     [bp+spanLeft],ax
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BLITCLIPPEDCGA ENDP

BLITCELLEGA PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLEGA ENDP

BLITCELLEGAMASKED PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLEGAMASKED ENDP

BLITCLIPPEDEGA PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@draw:
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        mov     ax,[bp+leftBytes]
        shl     ax,1
        shl     ax,1
        mov     [bp+leftBytes],ax
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BLITCLIPPEDEGA ENDP

BLITCELLTANDY PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLTANDY ENDP

BLITCELLTANDYMASKED PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        les     di,[bp+argDest]
        mov     ax,[bp+cellY]
        mov     cl,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+cellX]
        mov     [bp+leftBytes],ax
        mov     ax,es:[di+imgWidth]
        les     di,[bp+argGfx]
        sub     ax,es:[di+imgWidth]
        sub     ax,[bp+cellX]
        mov     [bp+destSkip],ax
        mov     ax,[bp+leftBytes]
        mov     [bp+spanLeft],ax
        shl     word ptr [bp+spanLeft],1
        shl     word ptr [bp+spanLeft],1
        mov     ax,es:[di+imgWidth]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        mov     ax,es:[di+imgHeight]
        mov     [bp+rowCount],ax
        mov     ax,es:[di+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,es:[di+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+leftBytes],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        mov     ax,es:[di+imgSize]
        xor     bx,bx
        mov     bl,[bp+cellTile]
        mul     bx
        mov     [bp+srcOff],ax
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        mov     word ptr [bp+skipLeft],0
        mov     word ptr [bp+skipRight],0
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     0Eh
BLITCELLTANDYMASKED ENDP

BLITCLIPPEDTANDY PROC NEAR
        push    bp
        mov     bp,sp
        sub     sp,1Ch
        sub     sp,1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        mov     ax,[si+imgTransp]
        mov     [bp+maskPtr],ax
        mov     ax,[si+imgTransp+2]
        mov     [bp+maskPtr+2],ax
        mov     ax,[bp+clipX]
        cmp     ax,8000h
        jbe     @@xOnScreen
        mov     [bp+skipLeft],ax
        neg     word ptr [bp+skipLeft]
        mov     word ptr [bp+leftBytes],0
        jmp     @@checkRight
@@xOnScreen:
        mov     word ptr [bp+skipLeft],0
        mov     [bp+leftBytes],ax
@@checkRight:
        add     ax,[si+imgWidth]
        cmp     es:[di+imgWidth],ax
        jae     @@rightFits
        sub     ax,es:[di+imgWidth]
        mov     [bp+skipRight],ax
        mov     word ptr [bp+destSkip],0
        jmp     @@clipTop
@@rightFits:
        mov     word ptr [bp+skipRight],0
        mov     ax,es:[di+imgWidth]
        sub     ax,[bp+clipX]
        sub     ax,[si+imgWidth]
        mov     [bp+destSkip],ax
@@clipTop:
        mov     ax,[bp+clipY]
        cmp     ax,8000h
        jbe     @@yOnScreen
        neg     ax
        mov     cx,3
        shl     ax,cl
        mov     bx,[si+imgHeight]
        mov     [bp+rowCount],bx
        sub     [bp+rowCount],ax
        mov     bx,[si+imgWidth]
        mul     bx
        mov     [bp+srcOff],ax
        mov     word ptr [bp+destOff],0
        mov     word ptr [bp+viewRow],0
        jmp     @@checkEmpty
@@yOnScreen:
        mov     word ptr [bp+srcOff],0
        mov     cx,3
        shl     ax,cl
        mov     [bp+viewRow],ax
        mov     bx,es:[di+imgWidth]
        mul     bx
        mov     [bp+destOff],ax
        mov     ax,[bp+viewRow]
        add     ax,[si+imgHeight]
        cmp     ax,es:[di+imgHeight]
        jbe     @@bottomFits
        mov     ax,es:[di+imgHeight]
        sub     ax,[bp+viewRow]
        mov     [bp+rowCount],ax
        jmp     @@checkEmpty
@@bottomFits:
        mov     ax,[si+imgHeight]
        mov     [bp+rowCount],ax
@@checkEmpty:
        mov     ax,[si+imgWidth]
        cmp     ax,[bp+skipLeft]
        jb      @@offView
        cmp     ax,[bp+skipRight]
        jb      @@offView
        mov     ax,[bp+srcOff]
        cmp     ax,[si+imgSize]
        ja      @@offView
        mov     ax,[bp+destOff]
        cmp     ax,es:[di+imgSize]
        ja      @@offView
        mov     ax,[bp+rowCount]
        cmp     ax,[si+imgHeight]
        ja      @@offView
        jmp     @@draw
@@offView:
        pop     ds
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@draw:
        mov     ax,[bp+leftBytes]
        shl     ax,1
        shl     ax,1
        mov     [bp+leftBytes],ax
        mov     [bp+spanLeft],ax
        mov     ax,[si+imgWidth]
        sub     ax,[bp+skipLeft]
        sub     ax,[bp+skipRight]
        shl     ax,1
        shl     ax,1
        mov     [bp+rowBytes],ax
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipLeft],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+skipRight],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+destSkip],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+srcOff],1
        shl     word ptr [bp+destOff],1
        shl     word ptr [bp+destOff],1
        mov     ax,[bp+srcOff]
        mov     [bp+saveOff],ax
        mov     ax,[si+imgSize]
        xor     bx,bx
        mov     bl,[bp+clipTile]
        mul     bx
        add     [bp+srcOff],ax
        mov     bx,[bp+viewRow]
        mov     cx,[bp+rowCount]
        mov     byte ptr [bp+saveFlag],0
        pop     ds
        test    byte ptr [bp+clipFlag],1
        jne     @@masked
        call    CopyRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
@@masked:
        mov     byte ptr [bp+saveFlag],0
        test    byte ptr [bp+clipFlag],4
        je      @@noSave
        mov     byte ptr [bp+saveFlag],1
@@noSave:
        call    MaskRows
        pop     ds
        pop     ss
        mov     sp,bp
        pop     bp
        ret     14h
BLITCLIPPEDTANDY ENDP

; The scanline loops, entered from a blitter's frame with bx = viewRow and cx =
; rowCount.  Each marks its row dirty and widens the row's dirty range for FlushView.
; CopyRows copies; MaskRows ANDs the mask in and ORs the tile over it.

CopyRows PROC NEAR
        mov     byte ptr [bx+spanActive],1
        shl     bx,1
        mov     ax,[bp+leftBytes]
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        cmp     ax,[bx+spanX0]
        ja      @@spanKnown
        mov     [bx+spanX0],ax
        mov     ax,[bp+spanLeft]
        mov     [bx+spanY],ax
@@spanKnown:
        push    ds
        lds     si,[bp+argGfx]
        les     di,[bp+argDest]
        add     si,imgData
        add     si,[bp+srcOff]
        add     di,imgData
        add     di,[bp+destOff]
        push    cx
        mov     cx,[bp+rowBytes]
        rep movsb
        pop     cx
        pop     ds
        mov     ax,[bp+rowBytes]
        add     [bp+srcOff],ax
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        dec     ax
        cmp     ax,[bx+spanX1]
        jb      @@endKnown
        mov     [bx+spanX1],ax
@@endKnown:
        mov     ax,[bp+destSkip]
        add     [bp+destOff],ax
        shr     bx,1
        inc     bx
        loop    CopyRows
        ret
CopyRows ENDP

MaskRows PROC NEAR
        mov     byte ptr [bx+spanActive],1
        shl     bx,1
        mov     ax,[bp+skipLeft]
        add     [bp+srcOff],ax
        mov     ax,[bp+leftBytes]
        add     [bp+destOff],ax
        mov     ax,[bp+destOff]
        cmp     ax,[bx+spanX0]
        jae     @@spanKnown
        mov     [bx+spanX0],ax
        mov     ax,[bp+spanLeft]
        mov     [bx+spanY],ax
@@spanKnown:
        push    ds
        les     di,[bp+argDest]
        add     di,[bp+destOff]
        push    cx
        mov     cx,[bp+rowBytes]
@@pixel:
        cmp     byte ptr [bp+saveFlag],0
        je      @@noSave
        lds     si,[bp+argUnder]
        add     si,[bp+saveOff]
        mov     al,es:[di+imgData]
        mov     [si+imgData],al
@@noSave:
        lds     si,[bp+maskPtr]
        add     si,[bp+srcOff]
        mov     ah,[si]
        lds     si,[bp+argGfx]
        add     si,[bp+srcOff]
        mov     al,[si+imgData]
        and     es:[di+imgData],ah
        or      es:[di+imgData],al
        inc     word ptr [bp+srcOff]
        inc     word ptr [bp+saveOff]
        inc     word ptr [bp+destOff]
        inc     di
        loop    @@pixel
        pop     cx
        pop     ds
        mov     ax,[bp+destOff]
        dec     ax
        cmp     ax,[bx+spanX1]
        jbe     @@endKnown
        mov     [bx+spanX1],ax
@@endKnown:
        mov     ax,[bp+destSkip]
        add     [bp+destOff],ax
        mov     ax,[bp+skipRight]
        add     [bp+srcOff],ax
        add     [bp+saveOff],ax
        shr     bx,1
        inc     bx
        dec     cx
        je      @@done
        jmp     MaskRows
@@done:
        ret
MaskRows ENDP

CODE    ENDS
        END
