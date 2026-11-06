; sounddrv.asm -- the PC-speaker and Tandy sound driver behind the SoundDrv unit, linked through {$L SOUNDDRV.OBJ}.
;
; The driver speeds the timer up to about 237 ticks a second and plays from two banks of four voices: bank A sounds on
; the PC speaker through PIT channel 2, bank B on the Tandy sound chip at port C0h. A sound is a script per voice of
; notes and opcodes. A note sets a voice's pitch and length; on every tick each voice steps its pitch slide, its vibrato
; and its volume envelope. Every thirteenth tick goes on to the BIOS timer handler, so the clock keeps its rate.
;
; The driver keeps its state in its own segment, and every entry point loads DS with it.
;
; DriverData is a countdown the SoundDrv unit arms. When it runs out, the handler puts up a run-time error and ends the
; program.

; A voice: its script and the time left on its current step, its pitch with a slide, vibrato read from a wave table, and
; a volume level driven by an envelope table.
TVoice          STRUC
                ; Ticks until the script takes its next step; zero once the script has ended.
ticks           dw      ?
                ; The next script byte, or zero for an idle voice.
script          dw      ?
                ; The note's divisor, before vibrato.
pitch           dw      ?
                ; Added to pitch on every tick.
slide           dw      ?
                ; The divisor sent to the hardware: pitch plus vibrato.
divisor         dw      ?
                ; The volume; on the speaker its low two bits are the port 61h gate bits.
level           dw      ?
                ; Added to level on every tick.
levelStep       dw      ?
                ; Note lengths are multiplied by this.
tempo           dw      ?
                ; Ticks before the end of a note at which the envelope moves to its release.
release         dw      ?
                ; Semitones added to every note.
transpose       dw      ?
                ; Ticks until the envelope moves to its release entries.
gateTicks       dw      ?
                ; The envelope table: pairs of a value and a tick count.
envelope        dw      ?
                ; Byte offset of the next envelope entry.
envIndex        dw      ?
                ; Ticks left on the current envelope entry.
envTicks        dw      ?
                ; The vibrato wave table.
wave            dw      ?
                ; Position in the wave, in sixteenths of an entry.
phase           dw      ?
                ; Added to phase on every tick.
phaseStep       dw      ?
                ; Vibrato depth: the wave sample is scaled by this.
depth           dw      ?
                ; The wave's length, in sixteenths of an entry.
waveLength      dw      ?
                ; Reserved.
                db      10 dup (?)
TVoice          ENDS

CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  InstallSoundTimer
        PUBLIC  UninstallSoundTimer
        PUBLIC  ProgramSpeakerVoices
        PUBLIC  ProgramTandyVoices
        PUBLIC  SetVoiceByte
        PUBLIC  DriverData

; Ticks left until the next one goes on to the BIOS timer handler.
tickDivider     db      0Dh
; Set while the handler runs the voices, or while ProgramSpeakerVoices or ProgramTandyVoices load them; the handler
; skips the voices while it is set.
inTick          db      00h
; The count of voices left in the loop over a bank.
voiceCount      db      00h
; The size of a voice, for the multiply that finds one by number.
voiceSize       db      SIZE TVoice
; Ticks until the run-time error; zero leaves it disarmed.
DriverData      dw      0000h
; The run-time error the countdown puts up.
crashMsg        db      'Run-time Error 209 at 0BAD:1138',0Ah,0Dh
; The sound last loaded; zero is silence.
soundId         dw      5050h
; The voice whose script is running.
curVoice        dw      5050h
; The bank being run.
voiceBase       dw      0850h
; The bank's divisor table.
freqTable       dw      0302h
; Where opReturn resumes the script after an opCall.
returnPtr       dw      0804h
; The sound each voice of the bank is playing; zero once its script has ended.
voiceSounds     db      00h,00h,00h,00h
; Clear to keep both banks quiet while their scripts still run.
outputOn        db      01h
; Note lengths, by the low five bits of a note byte.
noteLengths     db      00h,00h,00h,02h,00h,03h,04h,00h,06h,08h,00h,0Ch,10h,00h,18h,20h
                db      00h,30h,40h
; The handlers of script opcodes 0FAh to 0FFh.
opTable         dw      offset opClearVoice,offset opReturn,offset opCall
                dw      offset opSelectVoice,offset opLoop,offset opSetField
; Bank A, the PC-speaker voices.
voicesA         db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,05h,43h
                db      75h,72h,73h,65h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,11h,43h,75h,72h,65h,20h,4Ch,69h,67h
                db      68h,74h,20h,57h,6Fh,75h,6Eh,64h,73h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      12h,43h,61h,75h,73h,65h,20h,00h,30h,4Ch,00h,00h,00h,07h,00h,00h
                db      30h,48h,00h,00h,00h,0Fh,00h,00h,30h,50h,00h,00h,00h,14h,00h,06h
                db      90h,20h,00h,04h,00h,25h,00h,10h,50h,08h,00h,00h,00h,32h,00h,19h
                db      30h,60h,00h,00h,00h,37h,00h,06h,90h,20h,00h,00h,00h,4Ah,00h,10h
                db      00h,1Ch,00h,00h,00h,54h,00h,10h,00h,18h,00h,00h,00h,5Bh,00h,06h
                db      90h,20h,00h,00h,00h,66h,00h,10h,00h,20h,00h,00h,00h,71h,00h,06h
                db      90h,20h,00h,00h,00h,7Ch,00h,10h,00h,1Ch,00h,00h,00h,86h,00h,10h
                db      00h,18h,00h,00h,00h,8Dh,00h,10h,00h,14h,00h,00h,00h,91h,00h,06h
                db      90h,20h,00h,02h,00h,95h,00h,06h,90h,20h,00h,00h,00h,0A6h,00h,06h
                db      90h,20h,00h,00h,00h,0ADh,00h,10h,00h,1Ch,00h,00h,00h,0B9h,00h,10h
                db      00h,18h,00h,00h,00h,0C4h,00h,10h,90h,00h,00h,00h,00h,0CFh,00h,06h
                db      90h,20h,00h,00h,00h,04h,00h,06h,90h,20h,00h,01h,00h,07h,00h,06h
                db      90h,20h,00h,02h,00h,0Bh,00h,06h,90h,20h,00h,00h,00h,10h,00h,10h
                db      00h,10h,00h,00h,00h,19h,00h,10h,00h,18h,00h,00h,00h,20h,00h,10h
                db      00h,1Ch,00h,00h,00h,27h,00h,10h,10h,28h,00h,00h,00h,04h,00h,10h
                db      20h,28h,00h,00h,00h,07h,00h,10h,90h,00h,00h,00h,00h,0Ah,00h,10h
                db      90h,00h,00h,02h,00h,0Eh,00h,10h,90h,00h,00h,00h,00h,12h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,0Ch
; Bank A's PIT divisors for the twelve semitones of the lowest octave.
freqTableA      db      84h,8Eh,84h,86h,0F7h,7Eh,0D7h,77h,4Fh,71h,0C4h,6Ah,0C6h,64h,1Eh,5Fh
                db      0C7h,59h,0BDh,54h,0FCh,4Fh,7Eh,4Bh
; The bank A voice that has the speaker this tick.
speakerVoice    dw      0000h
; Bank B, the Tandy voices: three tone channels and the noise channel.
voicesB         db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,07h,45h
                db      6Eh,6Ch,61h,72h,67h,65h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,06h,52h,65h,64h,75h,63h,65h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      07h,46h,72h,69h,65h,6Eh,64h,73h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,0Dh,4Dh,61h,67h,69h,63h,20h
                db      4Dh,69h,73h,73h,69h,6Ch,65h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      00h,00h,14h,50h,72h,6Fh,74h,65h,63h,74h,69h,6Fh,6Eh,20h,46h,72h
                db      6Fh,6Dh,20h,45h,76h,69h,6Ch,00h,00h,00h,00h,00h,00h,00h,00h,04h
                db      0B8h,0Eh,10h,10h,28h,00h,00h,00h,04h,0BAh,0Eh,10h,20h,28h,00h,00h
                db      00h,02h,00h,02h,00h,04h,0A3h,0Eh,10h,90h,00h,00h,00h,00h,06h,89h
                db      16h,0Eh,10h,90h,00h,00h,02h,00h,02h,06h,0C4h,3Eh,0Eh,10h,90h,00h
                db      00h,00h,00h,02h,00h,2Ch,00h,06h,31h,0C0h,04h,26h,06h,89h,05h,02h
                db      00h,15h,00h,00h,37h,00h,02h,04h,55h,06h,89h,0E5h,02h,06h,89h,0ECh
                db      04h,5Dh,04h,0CBh,02h,00h,4Ah,00h,00h,43h,00h,00h,50h,00h,14h,00h
                db      04h,0Eh,04h,0E8h,0Eh,10h,00h,18h,00h,00h,00h,02h,06h,31h,0C0h,04h
                db      50h,02h,00h,6Fh,00h,04h,0Eh,04h,0E8h,0Eh,10h,00h,1Ch,00h,00h,00h
                db      02h,00h,02h,00h,00h,15h,00h,00h,44h,00h,00h,4Eh,00h,00h,60h,00h
                db      00h,75h,00h,02h,04h,55h,06h,89h,0E5h,02h,06h,89h,0ECh,04h,5Dh,04h
                db      0CBh,02h,00h,97h,00h,00h,84h,00h,0Ch,23h,01h,00h,9Dh,00h,14h,14h
; Bank B's divisors for the twelve semitones of the lowest octave.
freqTableB      db      0C0h,0FFh,40h,0F1h,0C0h,0E3h,00h,0D7h,40h,0CBh,80h,0BFh,0C0h,0B4h,80h,0AAh
                db      00h,0A1h,00h,98h,80h,8Fh,40h,87h
; The scripts for bank A: four per sound, one per voice, by sound number.
soundsA         db      0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,0C1h,0Ah,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      0B9h,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,29h,0Ah,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      51h,0Ah,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,0F1h,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      89h,0Ah,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,91h,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      4Dh,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,69h,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      0Dh,09h,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah,09h,0Bh,0B9h,0Ah,0B9h,0Ah,0B9h,0Ah
                db      31h,0Bh,00h,00h,00h,00h,00h,00h,0F0h,0Ch,00h,00h,00h,00h,00h,00h
                db      1Bh,0Eh,00h,00h,00h,00h,00h,00h,04h,10h,00h,00h,00h,00h,00h,00h
                db      0C3h,10h,00h,00h,00h,00h,00h,00h,0CAh,11h,00h,00h,00h,00h,00h,00h
                db      0AFh,12h,00h,00h,00h,00h,00h,00h,68h,13h,00h,00h,00h,00h,00h,00h
; The scripts for bank B: four per sound, one per voice, by sound number.
soundsB         db      0EFh,16h,0EFh,16h,0EFh,16h,0EFh,16h,0F7h,16h,23h,17h,4Fh,17h,0EFh,16h
                db      0EFh,16h,0EFh,16h,0EFh,16h,0D3h,16h,3Bh,16h,37h,16h,33h,16h,0EFh,16h
                db      57h,16h,0EFh,16h,9Bh,16h,0B3h,16h,0Bh,16h,0EFh,16h,0EFh,16h,0EFh,16h
                db      0EFh,16h,0EFh,16h,0E3h,15h,0F3h,15h,0B7h,15h,0B3h,15h,0EFh,16h,0EFh,16h
                db      0EFh,16h,0EFh,16h,0EFh,16h,7Bh,15h,0EFh,16h,0EFh,16h,0EFh,16h,9Bh,15h
                db      0EFh,16h,0EFh,16h,43h,15h,5Bh,15h,7Bh,17h,93h,17h,0ABh,17h,0EFh,16h
                db      0C3h,17h,0EFh,16h,0EFh,16h,0EFh,16h,82h,19h,0EFh,16h,0EFh,16h,0EFh,16h
                db      0ADh,1Ah,0EFh,16h,0EFh,16h,0EFh,16h,96h,1Ch,0EFh,16h,0EFh,16h,0EFh,16h
                db      55h,1Dh,0EFh,16h,0EFh,16h,0EFh,16h,5Ch,1Eh,0EFh,16h,0EFh,16h,0EFh,16h
                db      41h,1Fh,0EFh,16h,0EFh,16h,0EFh,16h,0FAh,1Fh,0EFh,16h,0EFh,16h,0EFh,16h
; Vibrato wave tables.
waves           db      00h,03h,06h,09h,0Ch,0Fh,12h,15h,18h,1Bh,1Eh,21h,24h,27h,2Ah,2Dh
                db      30h,33h,36h,39h,3Bh,3Eh,41h,43h,46h,49h,4Bh,4Eh,50h,52h,55h,57h
                db      59h,5Bh,5Eh,60h,62h,64h,66h,67h,69h,6Bh,6Ch,6Eh,70h,71h,72h,74h
                db      75h,76h,77h,78h,79h,7Ah,7Bh,7Bh,7Ch,7Dh,7Dh,7Eh,7Eh,7Eh,7Eh,7Eh
                db      7Eh,7Eh,7Eh,7Eh,7Eh,7Eh,7Dh,7Dh,7Ch,7Bh,7Bh,7Ah,79h,78h,77h,76h
                db      75h,74h,72h,71h,70h,6Eh,6Ch,6Bh,69h,67h,66h,64h,62h,60h,5Eh,5Bh
                db      59h,57h,55h,52h,50h,4Eh,4Bh,49h,46h,43h,41h,3Eh,3Bh,39h,36h,33h
                db      30h,2Dh,2Ah,27h,24h,21h,1Eh,1Bh,18h,15h,12h,0Fh,0Ch,09h,06h,03h
                db      00h,0FDh,0FAh,0F7h,0F4h,0F1h,0EEh,0EBh,0E8h,0E5h,0E2h,0DFh,0DCh,0D9h,0D6h,0D3h
                db      0D0h,0CDh,0CAh,0C7h,0C5h,0C2h,0BFh,0BDh,0BAh,0B7h,0B5h,0B2h,0B0h,0AEh,0ABh,0A9h
                db      0A7h,0A5h,0A2h,0A0h,9Eh,9Ch,9Ah,99h,97h,95h,94h,92h,90h,8Fh,8Eh,8Ch
                db      8Bh,8Ah,89h,88h,87h,86h,85h,85h,84h,83h,83h,82h,82h,82h,82h,82h
                db      82h,82h,82h,82h,82h,82h,83h,83h,84h,85h,85h,86h,87h,88h,89h,8Ah
                db      8Bh,8Ch,8Eh,8Fh,90h,92h,94h,95h,97h,99h,9Ah,9Ch,9Eh,0A0h,0A2h,0A5h
                db      0A7h,0A9h,0ABh,0AEh,0B0h,0B2h,0B5h,0B7h,0BAh,0BDh,0BFh,0C2h,0C5h,0C7h,0CAh,0CDh
                db      0D0h,0D3h,0D6h,0D9h,0DCh,0DFh,0E2h,0E5h,0E8h,0EBh,0EEh,0F1h,0F4h,0F7h,0FAh,0FDh
                db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h,78h
                db      29h,23h,0BEh,84h,0E1h,6Ch,0D6h,0AEh,52h,90h,49h,0F1h,0F1h,0BBh,0E9h,0EBh
                db      0B3h,0A6h,0DBh,3Ch,87h,0Ch,3Eh,99h,24h,5Eh,0Dh,1Ch,06h,0B7h,47h,0DEh
                db      0B3h,12h,4Dh,0C8h,43h,0BBh,8Bh,0A6h,1Fh,03h,5Ah,7Dh,09h,38h,25h,1Fh
                db      5Dh,0D4h,0CBh,0FCh,96h,0F5h,45h,3Bh,13h,0Dh,89h,0Ah,1Ch,0DBh,0AEh,32h
                db      20h,9Ah,50h,0EEh,40h,78h,36h,0FDh,12h,49h,32h,0F6h,9Eh,7Dh,49h,0DCh
                db      0ADh,4Fh,14h,0F2h,44h,40h,66h,0D0h,6Bh,0C4h,30h,0B7h,32h,3Bh,0A1h,22h
                db      0F6h,22h,91h,9Dh,0E1h,8Bh,1Fh,0DAh,0B0h,0CAh,99h,02h,0B9h,72h,9Dh,49h
                db      2Ch,80h,7Eh,0C5h,99h,0D5h,0E9h,80h,0B2h,0EAh,0C9h,0CCh,53h,0BFh,67h,0D6h
                db      0BFh,14h,0D6h,7Eh,2Dh,0DCh,8Eh,66h,83h,0EFh,57h,49h,61h,0FFh,69h,8Fh
                db      61h,0CDh,0D1h,1Eh,9Dh,9Ch,16h,72h,72h,0E6h,1Dh,0F0h,84h,4Fh,4Ah,77h
                db      02h,0D7h,0E8h,39h,2Ch,53h,0CBh,0C9h,12h,1Eh,33h,74h,9Eh,0Ch,0F4h,0D5h
                db      0D4h,9Fh,0D4h,0A4h,59h,7Eh,35h,0CFh,32h,22h,0F4h,0CCh,0CFh,0D3h,90h,2Dh
                db      48h,0D3h,8Fh,75h,0E6h,0D9h,1Dh,2Ah,0E5h,0C0h,0F7h,2Bh,78h,81h,87h,44h
                db      0Eh,5Fh,50h,00h,0D4h,61h,8Dh,0BEh,7Bh,05h,15h,07h,3Bh,33h,82h,1Fh
                db      18h,70h,92h,0DAh,64h,54h,0CEh,0B1h,85h,3Eh,69h,15h,0F8h,46h,6Ah,04h
                db      96h,73h,0Eh,0D9h,16h,2Fh,67h,68h,0D4h,0F7h,4Ah,4Ah,0D0h,57h,68h,76h
                db      0FAh,16h,0BBh,11h,0ADh,0AEh,24h,88h,79h,0FEh,52h,0DBh,25h,43h,0E5h,3Ch
                db      0F4h,45h,0D3h,0D8h,28h,0CEh,0Bh,0F5h,0C5h,60h,59h,3Dh,97h,27h,8Ah,59h
                db      76h,2Dh,0D0h,0C2h,0C9h,0CDh,68h,0D4h,49h,6Ah,79h,25h,08h,61h,40h,14h
                db      0B1h,3Bh,6Ah,0A5h,11h,28h,0C1h,8Ch,0D6h,0A9h,0Bh,87h,97h,8Ch,2Fh,0F1h
                db      15h,1Dh,9Ah,95h,0C1h,9Bh,0E1h,0C0h,7Eh,0E9h,0A8h,9Ah,0A7h,86h,0C2h,0B5h
                db      54h,0BFh,9Ah,0E7h,0D9h,23h,0D1h,55h,90h,38h,28h,0D1h,0D9h,6Ch,0A1h,66h
                db      5Eh,4Eh,0E1h,30h,9Ch,0FEh,0D9h,71h,9Fh,0E2h,0A5h,0E2h,0Ch,9Bh,0B4h,47h
                db      65h,38h,2Ah,46h,89h,0A9h,82h,79h,7Ah,76h,78h,0C2h,63h,0B1h,26h,0DFh
                db      0DAh,29h,6Dh,3Eh,62h,0E0h,96h,12h,34h,0BFh,39h,0A6h,3Fh,89h,5Eh,0F1h
                db      6Dh,0Eh,0E3h,6Ch,28h,0A1h,1Eh,20h,1Dh,0CBh,0C2h,03h,3Fh,41h,07h,84h
                db      0Fh,14h,05h,65h,1Bh,28h,61h,0C9h,0C5h,0E7h,2Ch,8Eh,46h,36h,08h,0DCh
                db      0F3h,0A8h,8Dh,0FEh,0BEh,0F2h,0EBh,71h,0FFh,0A0h,0D0h,3Bh,75h,06h,8Ch,7Eh
                db      87h,78h,73h,4Dh,0D0h,0BEh,82h,0BEh,0DBh,0C2h,46h,41h,2Bh,8Ch,0FAh,30h
                db      7Fh,70h,0F0h,0A7h,54h,86h,32h,95h,0AAh,5Bh,68h,13h,0Bh,0E6h,0FCh,0F5h
                db      0CAh,0BEh,7Dh,9Fh,89h,8Ah,41h,1Bh,0FDh,0B8h,4Fh,68h,0F6h,72h,7Bh,14h
                db      99h,0CDh,0D3h,0Dh,0F0h,44h,3Ah,0B4h,0A6h,66h,53h,33h,0Bh,0CBh,0A1h,10h
; The sound scripts and the envelope tables they use.
scripts         db      0FFh,0Ah,03h,00h,0FFh,04h,30h,75h,0FFh,1Ch,0Dh,07h,0FFh,24h,00h,20h
                db      0FFh,22h,10h,27h,0FFh,20h,10h,00h,0FFh,00h,1Ch,00h,0FFh,0Ah,00h,00h
                db      0FFh,00h,0Ch,00h,0FFh,0Ah,03h,00h,0FFh,04h,04h,10h,0FFh,22h,98h,08h
                db      0FFh,06h,10h,00h,0FFh,00h,2Ch,01h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h
                db      0FFh,0Ah,03h,00h,0FFh,04h,0A0h,0Fh,0FFh,00h,05h,00h,0FFh,04h,0E8h,03h
                db      0FFh,00h,04h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h
                db      0FFh,04h,0B0h,36h,0FFh,06h,0C8h,00h,0FFh,1Ch,0Dh,07h,0FFh,24h,00h,20h
                db      0FFh,22h,70h,17h,0FFh,20h,7Bh,00h,0FFh,00h,08h,00h,0FFh,0Ah,00h,00h
                db      0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,0B4h,3Fh,0FFh,26h,1Eh,00h
                db      0FFh,06h,3Ch,0FEh,0FFh,00h,0Ch,00h,0FFh,06h,77h,02h,0FFh,00h,08h,00h
                db      0FEh,26h,9Dh,09h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h
                db      0FFh,1Ch,0Dh,07h,0FFh,24h,00h,20h,0FFh,22h,40h,06h,0FFh,20h,9Bh,01h
                db      0FFh,04h,0CCh,10h,0FFh,06h,0Ah,00h,0FFh,00h,1Eh,00h,0FFh,22h,84h,03h
                db      0FFh,04h,14h,05h,0FFh,06h,50h,00h,0FFh,00h,05h,00h,0FFh,0Ah,00h,00h
                db      0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,26h,05h,00h,0FFh,04h,38h,18h
                db      0FFh,06h,00h,00h,0FFh,00h,06h,00h,0FFh,28h,0Ch,00h,0FFh,06h,5Eh,0FCh
                db      0FFh,00h,01h,00h,0FFh,06h,84h,03h,0FFh,00h,01h,00h,0FEh,28h,09h,0Ah
                db      0FEh,26h,0FDh,09h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h
                db      0FFh,04h,7Bh,19h,0FFh,26h,0Ah,00h,0FFh,06h,0D3h,0FFh,0FFh,00h,14h,00h
                db      0FFh,06h,0F4h,01h,0FFh,00h,01h,00h,0FEh,26h,35h,0Ah,0FFh,0Ah,00h,00h
                db      0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,1Ch,0Dh,07h,0FFh,24h,00h,20h
                db      0FFh,22h,10h,27h,0FFh,20h,10h,00h,0FFh,04h,0E0h,2Eh,0FFh,26h,2Ch,00h
                db      0FFh,06h,0F0h,0F1h,0FFh,00h,02h,00h,0FFh,06h,88h,0Eh,0FFh,00h,02h,00h
                db      0FEh,26h,6Dh,0Ah,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h
                db      0FFh,1Ch,0Dh,07h,0FFh,24h,00h,20h,0FFh,22h,28h,0Ah,0FFh,20h,10h,00h
                db      0FFh,04h,70h,17h,0FFh,06h,60h,0FFh,0FFh,00h,1Eh,00h,0FFh,06h,46h,00h
                db      0FFh,00h,23h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,00h,00h
                db      0FFh,00h,00h,00h,0FFh,0Ah,03h,00h,0FFh,04h,88h,13h,0FFh,1Ch,0EDh,05h
                db      0FFh,24h,00h,10h,0FFh,22h,0F4h,01h,0FFh,20h,4Eh,00h,0FFh,26h,28h,00h
                db      0FFh,06h,00h,00h,0FFh,00h,02h,00h,0FFh,06h,0ADh,0FDh,0FFh,00h,01h,00h
                db      0FFh,06h,00h,00h,0FFh,00h,02h,00h,0FFh,06h,0F4h,01h,0FFh,00h,01h,00h
                db      0FEh,26h,0DDh,0Ah,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,03h,00h
                db      0FFh,1Ch,0EDh,05h,0FFh,24h,00h,10h,0FFh,22h,0E8h,03h,0FFh,20h,00h,01h
                db      0FFh,04h,0E4h,0Ch,0FFh,06h,0ECh,0FFh,0FFh,00h,1Eh,00h,0FFh,0Ah,00h,00h
                db      0FFh,00h,00h,00h,0FCh,0A1h,14h,4Ch,0C8h,49h,0CBh,51h,4Fh,06h,0FFh,06h
                db      0FFh,06h,0FFh,06h,0FFh,26h,3Fh,06h,0B0h,26h,3Fh,06h,0B0h,31h,3Fh,11h
                db      30h,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h,0CFh,49h
                db      0CDh,49h,0CBh,4Ch,0CDh,49h,0CAh,51h,52h,06h,0FFh,06h,0FFh,06h,0FFh,06h
                db      0FFh,26h,3Eh,06h,0AEh,26h,3Eh,06h,0AEh,0Fh,2Eh,2Fh,3Eh,06h,0FFh,06h
                db      0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h,0D6h,49h,0D4h,49h,52h,26h
                db      41h,06h,0AEh,26h,41h,06h,0AEh,0Ch,2Dh,2Ch,41h,49h,0D4h,49h,0D1h,49h
                db      4Dh,26h,41h,06h,0ADh,26h,41h,06h,0ADh,51h,4Fh,2Ch,3Eh,0Ch,0ABh,26h
                db      43h,06h,0ABh,26h,43h,06h,0ABh,0Eh,2Bh,2Eh,0BEh,4Ch,0D0h,49h,0D4h,51h
                db      57h,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,2Ch,26h,0BCh,26h,3Ch,06h
                db      0ACh,0Fh,2Ch,2Fh,3Ch,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h
                db      0FFh,49h,0D9h,49h,0D7h,49h,55h,26h,41h,06h,0B1h,26h,41h,06h,0B1h,4Ch
                db      57h,0Ch,31h,2Ch,0C1h,49h,54h,06h,2Ch,26h,0BCh,26h,3Ch,06h,0ACh,51h
                db      50h,2Ch,3Ch,0Ch,0ACh,06h,2Ch,26h,0BCh,26h,3Ch,06h,0ACh,2Fh,3Ch,0Fh
                db      2Ch,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h,0D9h,49h
                db      0D7h,49h,55h,26h,41h,06h,0B1h,26h,41h,06h,0B1h,2Ch,3Fh,0Ch,38h,49h
                db      0D7h,49h,0D4h,49h,50h,06h,38h,26h,0BFh,26h,3Fh,06h,0B8h,2Ch,41h,0Ch
                db      31h,49h,0D9h,49h,0D7h,49h,55h,06h,31h,26h,0C1h,26h,41h,06h,0B1h,2Ch
                db      3Fh,0Ch,38h,49h,0D7h,49h,0D4h,49h,0D0h,51h,4Fh,0Ch,0FFh,06h,2Bh,26h
                db      0C3h,26h,43h,06h,0ABh,0Eh,2Bh,2Eh,0C3h,49h,0D6h,49h,0D3h,49h,0CFh,51h
                db      4Fh,0Ch,0FFh,06h,2Bh,26h,0C3h,26h,43h,06h,0ABh,0Eh,2Bh,2Eh,0C3h,4Bh
                db      4Fh,09h,0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h,4Fh,29h
                db      3Fh,09h,0B0h,4Bh,4Fh,09h,0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h
                db      0BCh,49h,4Fh,29h,3Fh,09h,0B0h,49h,0C8h,49h,4Dh,26h,3Ch,06h,0B5h,06h
                db      35h,26h,0BCh,49h,50h,09h,35h,29h,0BCh,4Bh,4Fh,09h,0FFh,26h,3Fh,06h
                db      0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h,4Fh,29h,3Fh,09h,0B0h,4Bh,4Fh,09h
                db      0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h,4Fh,29h,3Fh,09h
                db      0B0h,49h,0D4h,49h,59h,26h,3Ch,06h,0B5h,06h,35h,26h,0BCh,09h,35h,49h
                db      5Ch,29h,0BCh,0FCh,0A1h,14h,06h,0ABh,06h,0A9h,06h,0ABh,06h,0A9h,06h,0ABh
                db      06h,0A9h,06h,0ACh,06h,0AEh,06h,0B0h,06h,0B2h,06h,0B3h,06h,0B5h,06h,0B7h
                db      06h,0B5h,06h,0B7h,06h,0B5h,06h,0B7h,06h,0B5h,06h,0B8h,06h,0BAh,06h,0BCh
                db      06h,0BEh,06h,0BFh,06h,0C1h,51h,4Ah,31h,48h,06h,0ABh,06h,0A9h,06h,0ABh
                db      06h,0A9h,06h,0ABh,06h,0A9h,06h,0ACh,06h,0AEh,06h,0B0h,06h,0B2h,06h,0B3h
                db      06h,0B5h,51h,4Ah,31h,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,0B5h,06h,0B7h
                db      06h,0B5h,06h,0B8h,06h,0BAh,06h,0BCh,06h,0BEh,06h,0BFh,06h,0C1h,4Bh,4Ah
                db      2Bh,48h,06h,0ABh,06h,0A9h,06h,0ABh,06h,29h,46h,4Ah,26h,0C8h,49h,4Ah
                db      29h,48h,06h,0ABh,06h,0A9h,4Bh,4Ah,2Bh,48h,06h,0ACh,06h,0AEh,06h,0B0h
                db      06h,32h,46h,4Ah,26h,0C8h,49h,4Ah,29h,48h,06h,0B3h,06h,0B5h,4Bh,4Ah
                db      2Bh,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C7h,49h,4Ah
                db      29h,47h,06h,0B7h,06h,0B5h,4Bh,4Ah,2Bh,47h,06h,0B8h,06h,0BAh,06h,0BCh
                db      06h,3Eh,46h,4Ah,26h,0C7h,49h,4Ah,29h,47h,06h,0BFh,06h,0C1h,4Bh,4Ah
                db      2Bh,48h,06h,0ABh,06h,0A9h,06h,0ABh,06h,29h,46h,4Ah,26h,0C8h,49h,4Ah
                db      29h,48h,06h,0ABh,06h,0A9h,4Bh,4Ah,2Bh,48h,06h,0ACh,06h,0AEh,06h,0B0h
                db      06h,32h,46h,4Ah,26h,0C8h,49h,4Ah,29h,48h,06h,0B3h,06h,0B5h,4Bh,4Ah
                db      2Bh,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C7h,49h,4Ah
                db      29h,47h,06h,0B7h,06h,0B5h,4Bh,4Ah,2Bh,47h,06h,0B8h,06h,0BAh,06h,0BCh
                db      06h,3Eh,46h,4Ah,26h,0C7h,49h,4Ah,29h,47h,06h,0BFh,06h,0C1h,0FCh,0A1h
                db      14h,4Ch,48h,0Bh,24h,29h,0BFh,29h,43h,06h,0FFh,06h,0B0h,09h,24h,29h
                db      48h,49h,0CBh,51h,4Fh,0Bh,24h,29h,0BFh,29h,43h,06h,0FFh,06h,0B0h,09h
                db      24h,29h,0C8h,0Bh,24h,29h,0BFh,29h,43h,06h,0FFh,06h,0B0h,09h,24h,29h
                db      0C8h,0Bh,24h,49h,4Fh,29h,0BFh,29h,43h,49h,4Dh,06h,0FFh,06h,0B0h,09h
                db      24h,29h,48h,49h,0CBh,4Ch,4Dh,0Bh,2Eh,29h,0BEh,29h,41h,06h,0FFh,06h
                db      0BAh,09h,2Eh,29h,46h,49h,0CAh,51h,52h,0Bh,2Eh,29h,0BEh,29h,41h,06h
                db      0FFh,06h,0BAh,09h,2Eh,29h,0C6h,0Bh,2Eh,29h,0BEh,29h,41h,06h,0FFh,06h
                db      0BAh,09h,2Eh,29h,0C6h,0Bh,2Eh,49h,56h,29h,0BEh,29h,41h,49h,54h,06h
                db      0FFh,06h,0BAh,09h,2Eh,29h,46h,49h,0D2h,0Bh,2Dh,49h,54h,29h,0C5h,29h
                db      48h,49h,51h,06h,0FFh,06h,0B9h,09h,2Dh,29h,45h,49h,0CDh,51h,4Fh,0Bh
                db      2Bh,29h,0C8h,29h,4Bh,06h,0FFh,06h,0B7h,09h,2Bh,29h,0C8h,0Bh,2Bh,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0B7h,09h,2Bh,29h,0C8h,51h,4Fh,0Bh,2Bh,29h
                db      0C7h,29h,4Ah,06h,0FFh,06h,0B7h,09h,2Bh,29h,0C7h,0Bh,2Bh,29h,0C7h,29h
                db      4Ah,06h,0FFh,06h,0B7h,09h,2Bh,29h,0C7h,4Ch,50h,0Bh,2Ch,29h,0C8h,29h
                db      4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,48h,49h,0D4h,51h,57h,0Bh,2Ch,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,0C8h,0Bh,2Ch,29h,0C8h,29h
                db      4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,0C8h,09h,25h,29h,41h,49h,0D9h,09h
                db      29h,29h,44h,49h,0D7h,09h,2Ch,29h,49h,49h,0D5h,4Ch,57h,0Bh,2Ch,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,48h,49h,0D4h,51h,50h,0Bh
                db      2Ch,29h,0C8h,29h,4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,0C8h,0Bh,2Ch,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0B8h,09h,2Ch,29h,0C8h,09h,25h,29h,41h,49h
                db      0D9h,09h,29h,29h,44h,49h,0D7h,09h,2Ch,29h,49h,49h,0D5h,0Bh,2Ch,49h
                db      57h,29h,0C8h,29h,4Bh,49h,54h,06h,0FFh,06h,0B8h,09h,2Ch,29h,48h,49h
                db      0D0h,09h,25h,29h,41h,49h,0D9h,09h,29h,29h,44h,49h,0D7h,09h,2Ch,29h
                db      49h,49h,0D5h,0Bh,2Bh,49h,57h,29h,0C8h,29h,4Bh,49h,54h,06h,0FFh,06h
                db      0B7h,09h,2Bh,29h,48h,49h,0D0h,51h,4Fh,0Bh,2Bh,29h,0C8h,29h,4Bh,06h
                db      0FFh,06h,0B7h,09h,2Bh,29h,0C8h,0Bh,2Bh,29h,0C8h,29h,4Bh,06h,0FFh,06h
                db      0B7h,09h,2Bh,29h,0C8h,0Bh,2Bh,49h,56h,29h,0C7h,29h,4Ah,49h,53h,06h
                db      0FFh,06h,0B7h,09h,2Bh,29h,47h,49h,0CFh,51h,4Fh,0Bh,2Bh,29h,0C7h,29h
                db      4Ah,06h,0FFh,06h,0B7h,09h,2Bh,29h,0C7h,0Bh,2Bh,29h,0C7h,29h,4Ah,06h
                db      0FFh,06h,0B7h,09h,2Bh,29h,0C7h,0FCh,0A1h,14h,0Bh,24h,4Bh,4Fh,29h,0BFh
                db      29h,43h,06h,0FFh,06h,30h,46h,0CBh,09h,24h,29h,48h,49h,0CFh,0Bh,24h
                db      4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,30h,46h,0CBh,09h,24h,29h,48h
                db      49h,0CFh,09h,29h,29h,44h,49h,0C8h,09h,2Ch,29h,48h,49h,0CDh,09h,30h
                db      29h,4Dh,49h,0D0h,0Bh,24h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,30h
                db      46h,0CBh,09h,24h,29h,48h,49h,0CFh,0Bh,24h,4Bh,4Fh,29h,0BFh,29h,43h
                db      06h,0FFh,06h,30h,46h,0CBh,09h,24h,29h,48h,49h,0CFh,09h,29h,29h,44h
                db      49h,0D4h,09h,2Ch,29h,48h,49h,0D9h,09h,30h,29h,4Dh,49h,0DCh,0Bh,24h
                db      4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,30h,46h,0CBh,09h,24h,29h,48h
                db      49h,0CFh,0Bh,24h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,30h,46h,0CBh
                db      09h,24h,29h,48h,49h,0CFh,09h,29h,29h,45h,49h,0D4h,09h,2Dh,29h,48h
                db      49h,0D9h,09h,30h,29h,4Dh,49h,0DCh,31h,48h,51h,5Ch,0Ch,0ACh,09h,0ACh
                db      0Ch,0ACh,09h,0ACh,0Ch,0ACh,0FCh,0A1h,14h,09h,2Ch,29h,48h,49h,0CBh,0Ch
                db      2Ch,4Bh,4Ch,2Bh,0C9h,46h,0CEh,09h,2Ch,29h,49h,49h,0D0h,2Fh,48h,4Fh
                db      4Bh,0Ch,0ACh,09h,0ACh,0Ch,0ACh,09h,2Ch,29h,48h,49h,0CBh,0Ch,2Ch,4Bh
                db      4Ch,2Bh,0C9h,46h,0CEh,09h,2Ch,29h,49h,49h,0D0h,2Eh,4Bh,0Bh,2Fh,49h
                db      0CEh,49h,47h,06h,0FFh,06h,0B1h,49h,53h,09h,0B3h,0Eh,34h,2Eh,47h,4Bh
                db      0D0h,46h,0CEh,49h,0CCh,0Eh,30h,49h,4Fh,29h,0CCh,29h,4Ah,49h,0CEh,29h
                db      48h,49h,0CCh,0Eh,2Fh,49h,4Ah,29h,0C7h,29h,43h,49h,0C7h,29h,3Eh,49h
                db      0C3h,2Fh,49h,4Fh,4Ch,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h,49h,49h
                db      0CCh,0Ch,2Dh,4Bh,4Dh,2Bh,0CAh,46h,0CFh,49h,51h,09h,0ADh,2Fh,49h,4Fh
                db      4Ch,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h,49h,49h,0CCh,2Bh,4Ah,4Bh
                db      4Dh,09h,0B2h,09h,30h,06h,0FFh,46h,0CFh,49h,51h,09h,0AEh,4Fh,4Ch,2Fh
                db      49h,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h,49h,49h,0CCh,0Eh,2Bh,2Bh
                db      4Ah,49h,0CEh,49h,51h,06h,0FFh,26h,0C7h,29h,45h,49h,0CEh,2Eh,49h,4Eh
                db      4Ch,0Ch,0ADh,09h,0ADh,2Bh,4Ah,09h,2Bh,49h,0CEh,49h,51h,09h,32h,06h
                db      0FFh,26h,0C7h,29h,45h,49h,4Eh,09h,0B7h,51h,4Ch,2Ch,47h,09h,0AFh,09h
                db      0B6h,09h,0BBh,2Ch,45h,09h,0AFh,09h,0B6h,09h,0BBh,51h,4Bh,2Ch,43h,09h
                db      0AFh,09h,0B6h,09h,0BBh,2Ch,42h,09h,0AFh,09h,0B6h,09h,0BBh,0FCh,0A1h,14h
                db      4Bh,47h,0Bh,28h,2Bh,43h,09h,0FFh,09h,2Fh,06h,0FFh,46h,4Ch,26h,0C7h
                db      49h,4Fh,09h,34h,29h,0CCh,49h,4Eh,09h,2Ah,29h,0CBh,49h,4Ch,09h,2Fh
                db      29h,0C9h,49h,4Eh,09h,36h,29h,0CBh,4Bh,4Fh,2Bh,4Ah,09h,2Bh,09h,0FFh
                db      09h,32h,06h,0FFh,46h,4Eh,26h,0CAh,49h,4Ch,09h,37h,29h,0CAh,49h,4Ah
                db      09h,2Dh,29h,0C7h,49h,48h,09h,34h,29h,0C5h,49h,45h,09h,39h,29h,0C2h
                db      4Bh,47h,2Bh,43h,09h,2Fh,09h,0FFh,09h,3Bh,06h,0FFh,46h,4Ch,26h,0C7h
                db      49h,4Fh,09h,2Fh,29h,0CCh,49h,51h,09h,30h,29h,0CEh,49h,4Fh,09h,3Ch
                db      29h,0CCh,49h,51h,09h,30h,29h,0CEh,51h,53h,2Eh,4Ch,0Bh,0AFh,06h,0BBh
                db      09h,0AFh,2Eh,4Bh,0Bh,0AFh,06h,0BBh,09h,0AFh,0Ch,30h,2Ch,4Ch,4Bh,0D3h
                db      46h,0D3h,49h,0D3h,0Ch,2Bh,2Ch,4Ah,49h,0D3h,49h,0CFh,49h,0D1h,0Ch,30h
                db      2Ch,4Ch,4Bh,0D3h,46h,0D3h,49h,0D3h,0Ch,2Bh,2Ch,4Ah,49h,0D3h,49h,0CFh
                db      49h,0D1h,0Ch,30h,2Ch,4Ch,4Bh,0D3h,46h,0D1h,49h,0CFh,0Ch,30h,2Ch,4Ch
                db      49h,0D1h,49h,0CFh,49h,0CCh,11h,2Fh,51h,4Eh,26h,0CBh,26h,0B3h,26h,0B6h
                db      26h,0B9h,26h,0BBh,26h,0BFh,26h,0C2h,26h,0C5h,26h,0C7h,26h,0CBh,26h,0CEh
                db      26h,0D1h,0FCh,0A1h,14h,4Eh,53h,2Eh,4Fh,0Bh,0BBh,06h,0C0h,09h,0C3h,4Eh
                db      53h,2Eh,51h,09h,0C2h,09h,0C0h,09h,0C2h,4Eh,53h,2Eh,4Fh,0Bh,0C3h,06h
                db      0BBh,09h,0C0h,4Eh,54h,2Eh,51h,09h,0BEh,09h,0BCh,09h,0B9h,4Eh,53h,2Eh
                db      4Fh,0Bh,0BBh,06h,0C0h,09h,0C3h,4Eh,54h,2Eh,4Fh,09h,0C5h,09h,0C3h,09h
                db      0C5h,11h,47h,2Eh,4Fh,4Eh,0D3h,4Eh,53h,2Eh,0CEh,0Ch,30h,4Bh,53h,26h
                db      0C0h,26h,0C3h,26h,0C8h,26h,40h,46h,0D8h,49h,53h,26h,0C3h,26h,0C8h,0Ch
                db      2Bh,49h,56h,26h,0BEh,26h,0C3h,49h,53h,26h,0C7h,26h,0BEh,49h,4Fh,26h
                db      0C3h,26h,0C7h,0Ch,30h,4Bh,4Ch,26h,0C0h,26h,0C3h,26h,0C8h,26h,40h,46h
                db      0CFh,49h,54h,26h,0C3h,26h,0C8h,0Ch,2Bh,49h,53h,26h,0BEh,26h,0C3h,49h
                db      4Fh,26h,0C7h,26h,0BEh,49h,4Ah,26h,0C3h,26h,0C7h,2Ch,46h,4Bh,0D1h,46h
                db      0D6h,49h,0D1h,2Ch,41h,49h,0D4h,49h,0D1h,49h,0CDh,2Ch,46h,4Bh,0CAh,46h
                db      0CDh,49h,0D2h,2Ch,41h,49h,0D1h,49h,0CDh,49h,0C8h,0FCh,0A1h,14h,0Eh,32h
                db      2Eh,46h,4Bh,0D1h,46h,0CDh,49h,0CAh,51h,4Fh,2Ch,47h,0Ch,0A6h,09h,26h
                db      29h,0C7h,0Ch,26h,2Ch,0C7h,09h,26h,29h,0C7h,0Eh,32h,2Eh,46h,4Bh,0D1h
                db      46h,0CDh,49h,0CAh,51h,4Fh,2Ch,47h,0Ch,0A6h,09h,26h,29h,0C7h,0Ch,26h
                db      2Ch,0C7h,09h,26h,29h,0C7h,4Bh,51h,29h,0BEh,0Ch,2Eh,29h,41h,06h,0FFh
                db      46h,0CDh,49h,4Ah,29h,0C6h,4Bh,52h,29h,0BEh,0Ch,2Bh,29h,43h,06h,0FFh
                db      46h,0CFh,49h,4Ah,29h,0C6h,4Bh,53h,29h,0BEh,0Ch,37h,29h,43h,06h,0FFh
                db      46h,0CFh,49h,4Dh,29h,0C7h,4Bh,54h,29h,0C0h,0Ch,30h,29h,43h,06h,0FFh
                db      46h,0CFh,49h,4Dh,29h,0C8h,4Bh,55h,29h,0C0h,0Ch,2Dh,29h,45h,06h,0FFh
                db      46h,0D1h,49h,4Fh,29h,0C9h,4Bh,56h,29h,0C1h,0Ch,32h,29h,45h,06h,0FFh
                db      46h,0D1h,49h,4Dh,29h,0CAh,49h,58h,09h,30h,29h,0D1h,0Bh,2Eh,29h,4Fh
                db      49h,0D9h,49h,5Bh,29h,4Ah,06h,0FFh,06h,0BAh,49h,5Ch,09h,2Eh,29h,0C8h
                db      0Eh,2Dh,2Bh,49h,4Bh,0DDh,46h,51h,26h,0C9h,49h,51h,29h,0C9h,0Eh,2Eh
                db      2Bh,4Ah,4Bh,0DDh,46h,51h,26h,0CAh,49h,51h,29h,0CAh,0Bh,2Dh,2Bh,49h
                db      4Bh,0DDh,46h,51h,06h,2Fh,26h,0C9h,49h,51h,29h,49h,09h,0B1h,49h,56h
                db      29h,4Dh,09h,0B2h,0Bh,2Eh,29h,4Ch,49h,0D8h,29h,4Ah,49h,59h,06h,0FFh
                db      06h,0BAh,09h,2Eh,29h,48h,49h,0DBh,0Eh,2Dh,2Bh,49h,4Bh,0DDh,46h,51h
                db      26h,0C9h,49h,51h,29h,0C9h,0Eh,2Eh,2Bh,4Ah,4Bh,0DDh,46h,51h,26h,0CAh
                db      49h,51h,29h,0CAh,4Bh,5Dh,0Bh,2Dh,2Bh,0C9h,46h,51h,06h,2Fh,26h,0C9h
                db      49h,51h,29h,49h,09h,0B1h,09h,32h,49h,56h,29h,0CDh,0FFh,00h,00h,00h
                db      0FFh,00h,00h,00h,0FDh,30h,00h,0FFh,12h,0E8h,0FFh,0FFh,16h,13h,15h,0FFh
                db      1Ch,0EDh,05h,0FFh,24h,00h,10h,0FFh,22h,28h,00h,0FFh,20h,2Ch,01h,0FDh
                db      60h,00h,0FFh,12h,0E8h,0FFh,0FFh,10h,05h,00h,0FFh,16h,0FBh,14h,0FFh,1Ch
                db      0EDh,05h,0FFh,24h,00h,10h,0FFh,22h,14h,00h,0FFh,20h,78h,00h,0FDh,00h
                db      00h,0FFh,12h,0E8h,0FFh,0FFh,16h,2Bh,15h,0FFh,1Ch,0EDh,06h,0FFh,24h,00h
                db      02h,0FFh,22h,78h,00h,0FFh,20h,80h,00h,0FFh,0Eh,06h,00h,0FBh,03h,00h
                db      0FFh,0FFh,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h
                db      0FFh,0FFh,00h,00h,00h,00h,03h,00h,0FFh,0FFh,00h,00h,10h,00h,00h,00h
                db      0FFh,0FFh,00h,00h,00h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,03h,00h
                db      0FFh,0FFh,00h,00h,08h,00h,00h,00h,0FFh,0FFh,00h,00h,00h,00h,00h,00h
                db      0FFh,0FFh,00h,00h,00h,00h,0FFh,04h,0B8h,0Bh,0FFh,00h,1Ch,00h,0FFh,04h
                db      80h,3Eh,0FFh,06h,0E7h,0FFh,0FFh,00h,90h,01h,0FFh,00h,00h,00h,0FFh,04h
                db      0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,00h,1Ch,00h,0FFh,0Ah,50h,0C3h,0FFh,0Ch
                db      9Ch,0FFh,0FFh,00h,90h,01h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
                db      00h,01h,0FFh,0Ah,30h,75h,0FFh,0Ch,0E8h,03h,0FFh,00h,14h,00h,0FFh,0Ch
                db      18h,0FCh,0FFh,00h,28h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
                db      80h,01h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,54h,0F2h,0FFh,00h,10h,00h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,00h,04h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
                db      9Ch,0FFh,0FFh,04h,0E8h,0FDh,0FFh,26h,1Eh,00h,0FFh,06h,8Ah,0FDh,0FFh,00h
                db      0Ch,00h,0FFh,06h,76h,02h,0FFh,00h,08h,00h,0FEh,26h,0C7h,15h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,04h,0D0h,07h,0FFh,06h,5Ah,00h,0FFh,00h
                db      14h,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
                db      30h,0F8h,0FFh,00h,14h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
                db      0C2h,09h,0FFh,0Ah,30h,75h,0FFh,26h,0Ch,00h,0FFh,06h,0F7h,0FFh,0FFh,00h
                db      0Ch,00h,0FFh,06h,09h,00h,0FFh,00h,08h,00h,0FEh,26h,17h,16h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,00h,14h,00h,0FFh,00h,14h,00h,0FFh,04h
                db      0E3h,98h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,38h,0FFh,0FFh,06h,4Eh,0FFh,0FFh,00h
                db      0C8h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,10h,27h,0FFh,0Ch
                db      0F4h,01h,0FFh,04h,00h,0FAh,0FFh,06h,10h,0FFh,0FFh,00h,50h,00h,0FFh,0Ch
                db      00h,00h,0FFh,26h,2Ch,00h,0FFh,06h,50h,0FBh,0FFh,00h,02h,00h,0FFh,06h
                db      0D8h,04h,0FFh,00h,02h,00h,0FEh,26h,73h,16h,0FFh,0Ch,61h,0FEh,0FFh,06h
                db      3Ch,00h,0FFh,00h,78h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,04h
                db      30h,11h,0FFh,06h,0Bh,00h,0FFh,00h,0BCh,00h,0FFh,06h,0F5h,0FFh,0FFh,00h
                db      0BCh,00h,0FFh,00h,00h,00h,0FFh,04h,0C0h,01h,0FFh,0Ah,0A8h,61h,0FFh,0Ch
                db      9Fh,00h,0FFh,00h,0BCh,00h,0FFh,0Ch,61h,0FFh,0FFh,00h,0BCh,00h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,0Ch,60h,09h,0FFh,04h,00h,01h,0FFh,00h
                db      19h,00h,0FFh,0Ch,0A0h,0F6h,0FFh,00h,19h,00h,0FFh,0Ah,00h,00h,0FFh,00h
                db      00h,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch
                db      15h,0FFh,0FFh,04h,0E0h,1Fh,0FFh,26h,06h,00h,0FFh,06h,1Eh,00h,0FFh,00h
                db      10h,00h,0FFh,06h,0E2h,0FFh,0FFh,00h,10h,00h,0FEh,26h,07h,17h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,50h,0C3h,0FFh,0Ch,38h,0FFh,0FFh,04h
                db      10h,40h,0FFh,26h,0Ah,00h,0FFh,06h,42h,00h,0FFh,00h,08h,00h,0FFh,06h
                db      0BEh,0FFh,0FFh,00h,08h,00h,0FEh,26h,33h,17h,0FFh,0Ah,00h,00h,0FFh,00h
                db      00h,00h,0FFh,0Ah,0E8h,0FDh,0FFh,0Ch,0D4h,0FEh,0FFh,04h,0B0h,36h,0FFh,26h
                db      08h,00h,0FFh,06h,52h,00h,0FFh,00h,0Ch,00h,0FFh,06h,0B2h,0FFh,0FFh,00h
                db      0Ch,00h,0FEh,26h,5Fh,17h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
                db      60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h,0D0h,34h,0FFh,00h,1Eh,00h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FFh,0Ah,60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h
                db      20h,80h,0FFh,00h,1Eh,00h,0FFh,0Ah,00h,00h,0FFh,00h,00h,00h,0FFh,0Ah
                db      60h,0EAh,0FFh,0Ch,50h,0FBh,0FFh,04h,70h,17h,0FFh,00h,0Ah,00h,0FFh,0Ah
                db      00h,00h,0FFh,00h,00h,00h,0FCh,2Fh,21h,4Ch,0C8h,49h,0CBh,51h,4Fh,06h
                db      0FFh,06h,0FFh,06h,0FFh,06h,0FFh,26h,3Fh,06h,0B0h,26h,3Fh,06h,0B0h,31h
                db      3Fh,11h,30h,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h
                db      0CFh,49h,0CDh,49h,0CBh,4Ch,0CDh,49h,0CAh,51h,52h,06h,0FFh,06h,0FFh,06h
                db      0FFh,06h,0FFh,26h,3Eh,06h,0AEh,26h,3Eh,06h,0AEh,0Fh,2Eh,2Fh,3Eh,06h
                db      0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h,0D6h,49h,0D4h,49h
                db      52h,26h,41h,06h,0AEh,26h,41h,06h,0AEh,0Ch,2Dh,2Ch,41h,49h,0D4h,49h
                db      0D1h,49h,4Dh,26h,41h,06h,0B9h,26h,41h,06h,0B9h,51h,4Fh,2Ch,3Eh,0Ch
                db      0B7h,26h,43h,06h,0B7h,26h,43h,06h,0B7h,0Eh,37h,2Eh,0BEh,4Ch,0D0h,49h
                db      0D4h,51h,57h,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,38h,26h,0BCh,26h
                db      3Ch,06h,0B8h,0Fh,38h,2Fh,3Ch,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h
                db      0FFh,06h,0FFh,49h,0D9h,49h,0D7h,49h,55h,26h,41h,06h,0B1h,26h,41h,06h
                db      0B1h,4Ch,57h,0Ch,31h,2Ch,0C1h,49h,54h,06h,38h,26h,0BCh,26h,3Ch,06h
                db      0B8h,51h,50h,2Ch,3Ch,0Ch,0B8h,06h,38h,26h,0BCh,26h,3Ch,06h,0B8h,2Fh
                db      3Ch,0Fh,38h,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,06h,0FFh,49h
                db      0D9h,49h,0D7h,49h,55h,26h,41h,06h,0B1h,26h,41h,06h,0B1h,2Ch,3Fh,0Ch
                db      38h,49h,0D7h,49h,0D4h,49h,50h,06h,38h,26h,0BFh,26h,3Fh,06h,0B8h,2Ch
                db      41h,0Ch,31h,49h,0D9h,49h,0D7h,49h,55h,06h,31h,26h,0C1h,26h,41h,06h
                db      0B1h,2Ch,3Fh,0Ch,38h,49h,0D7h,49h,0D4h,49h,0D0h,51h,4Fh,0Ch,0FFh,06h
                db      37h,26h,0C3h,26h,43h,06h,0B7h,0Eh,37h,2Eh,0C3h,49h,0D6h,49h,0D3h,49h
                db      0CFh,51h,4Fh,0Ch,0FFh,06h,37h,26h,0C3h,26h,43h,06h,0B7h,0Eh,37h,2Eh
                db      0C3h,4Bh,4Fh,09h,0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h
                db      4Fh,29h,3Fh,09h,0B0h,4Bh,4Fh,09h,0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h
                db      3Fh,06h,0BCh,49h,4Fh,29h,3Fh,09h,0B0h,49h,0C8h,49h,4Dh,26h,3Ch,06h
                db      0B5h,06h,35h,26h,0BCh,49h,50h,09h,35h,29h,0BCh,4Bh,4Fh,09h,0FFh,26h
                db      3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h,4Fh,29h,3Fh,09h,0B0h,4Bh
                db      4Fh,09h,0FFh,26h,3Fh,06h,0B0h,46h,4Bh,26h,3Fh,06h,0BCh,49h,4Fh,29h
                db      3Fh,09h,0B0h,49h,0D4h,49h,59h,26h,3Ch,06h,0B5h,06h,35h,26h,0BCh,09h
                db      35h,49h,5Ch,29h,0BCh,0FCh,2Fh,21h,06h,0B7h,06h,0B5h,06h,0B7h,06h,0B5h
                db      06h,0B7h,06h,0B5h,06h,0B8h,06h,0BAh,06h,0BCh,06h,0BEh,06h,0BFh,06h,0C1h
                db      06h,0C3h,06h,0C1h,06h,0C3h,06h,0C1h,06h,0C3h,06h,0C1h,06h,0C4h,06h,0C6h
                db      06h,0C8h,06h,0CAh,06h,0CBh,06h,0CDh,51h,4Ah,31h,48h,06h,0B7h,06h,0B5h
                db      06h,0B7h,06h,0B5h,06h,0B7h,06h,0B5h,06h,0B8h,06h,0BAh,06h,0BCh,06h,0BEh
                db      06h,0BFh,06h,0C1h,51h,4Ah,31h,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,0B5h
                db      06h,0B7h,06h,0B5h,06h,0B8h,06h,0BAh,06h,0BCh,06h,0BEh,06h,0BFh,06h,0C1h
                db      2Eh,48h,4Bh,4Ah,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C8h
                db      49h,4Ah,29h,48h,06h,0B7h,06h,0B5h,2Eh,48h,4Bh,4Ah,06h,0B8h,06h,0BAh
                db      06h,0BCh,06h,3Eh,46h,4Ah,26h,0C8h,49h,4Ah,29h,48h,06h,0BFh,06h,0C1h
                db      4Bh,4Ah,2Bh,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C7h
                db      49h,4Ah,29h,47h,06h,0B7h,06h,0B5h,4Bh,4Ah,2Bh,47h,06h,0B8h,06h,0BAh
                db      06h,0BCh,06h,3Eh,46h,4Ah,26h,0C7h,49h,4Ah,29h,47h,06h,0BFh,06h,0C1h
                db      4Bh,4Ah,2Bh,48h,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C8h
                db      49h,4Ah,29h,48h,06h,0B7h,06h,0B5h,4Bh,4Ah,2Bh,48h,06h,0B8h,06h,0BAh
                db      06h,0BCh,06h,3Eh,46h,4Ah,26h,0C8h,49h,4Ah,29h,48h,06h,0BFh,06h,0C1h
                db      4Bh,4Ah,2Bh,47h,06h,0B7h,06h,0B5h,06h,0B7h,06h,35h,46h,4Ah,26h,0C7h
                db      49h,4Ah,29h,47h,06h,0B7h,06h,0B5h,4Bh,4Ah,2Bh,47h,06h,0B8h,06h,0BAh
                db      06h,0BCh,06h,3Eh,46h,4Ah,26h,0C7h,49h,4Ah,29h,47h,06h,0BFh,06h,0C1h
                db      0FCh,2Fh,21h,4Ch,48h,0Bh,30h,29h,0BFh,29h,43h,06h,0FFh,06h,0BCh,09h
                db      30h,29h,48h,49h,0CBh,51h,4Fh,0Bh,30h,29h,0BFh,29h,43h,06h,0FFh,06h
                db      0BCh,09h,30h,29h,0C8h,0Bh,30h,29h,0BFh,29h,43h,06h,0FFh,06h,0BCh,09h
                db      30h,29h,0C8h,0Bh,30h,49h,4Fh,29h,0BFh,29h,43h,49h,4Dh,06h,0FFh,06h
                db      0BCh,09h,30h,29h,48h,49h,0CBh,4Ch,4Dh,0Bh,2Eh,29h,0BEh,29h,41h,06h
                db      0FFh,06h,0BAh,09h,2Eh,29h,46h,49h,0CAh,51h,52h,0Bh,2Eh,29h,0BEh,29h
                db      41h,06h,0FFh,06h,0BAh,09h,2Eh,29h,0C6h,0Bh,2Eh,29h,0BEh,29h,41h,06h
                db      0FFh,06h,0BAh,09h,2Eh,29h,0C6h,0Bh,2Eh,49h,56h,29h,0BEh,29h,41h,49h
                db      54h,06h,0FFh,06h,0BAh,09h,2Eh,29h,46h,49h,0D2h,0Bh,2Dh,49h,54h,29h
                db      0C5h,29h,48h,49h,51h,06h,0FFh,06h,0B9h,09h,2Dh,29h,45h,49h,0CDh,51h
                db      4Fh,0Bh,37h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C3h,09h,37h,29h,0C8h,0Bh
                db      37h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C3h,09h,37h,29h,0C8h,51h,4Fh,0Bh
                db      37h,29h,0C7h,29h,4Ah,06h,0FFh,06h,0C3h,09h,37h,29h,0C7h,0Bh,37h,29h
                db      0C7h,29h,4Ah,06h,0FFh,06h,0C3h,09h,37h,29h,0C7h,4Ch,50h,0Bh,38h,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,48h,49h,0D4h,51h,57h,0Bh
                db      38h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,0C8h,0Bh,38h,29h
                db      0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,0C8h,09h,31h,29h,41h,49h
                db      0D9h,09h,35h,29h,44h,49h,0D7h,09h,38h,29h,49h,49h,0D5h,4Ch,57h,0Bh
                db      38h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,48h,49h,0D4h,51h
                db      50h,0Bh,38h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,0C8h,0Bh
                db      38h,29h,0C8h,29h,4Bh,06h,0FFh,06h,0C4h,09h,38h,29h,0C8h,09h,31h,29h
                db      41h,49h,0D9h,09h,35h,29h,44h,49h,0D7h,09h,38h,29h,49h,49h,0D5h,0Bh
                db      38h,49h,57h,29h,0C8h,29h,4Bh,49h,54h,06h,0FFh,06h,0C4h,09h,38h,29h
                db      48h,49h,0D0h,09h,31h,29h,41h,49h,0D9h,09h,35h,29h,44h,49h,0D7h,09h
                db      38h,29h,49h,49h,0D5h,0Bh,37h,49h,57h,29h,0C8h,29h,4Bh,49h,54h,06h
                db      0FFh,06h,0C3h,09h,37h,29h,48h,49h,0D0h,51h,4Fh,0Bh,37h,29h,0C8h,29h
                db      4Bh,06h,0FFh,06h,0C3h,09h,37h,29h,0C8h,0Bh,37h,29h,0C8h,29h,4Bh,06h
                db      0FFh,06h,0C3h,09h,37h,29h,0C8h,0Bh,37h,49h,56h,29h,0C7h,29h,4Ah,49h
                db      53h,06h,0FFh,06h,0C3h,09h,37h,29h,47h,49h,0CFh,51h,4Fh,0Bh,37h,29h
                db      0C7h,29h,4Ah,06h,0FFh,06h,0C3h,09h,37h,29h,0C7h,0Bh,37h,29h,0C7h,29h
                db      4Ah,06h,0FFh,06h,0C3h,09h,37h,29h,0C7h,0FCh,2Fh,21h,0Bh,30h,4Bh,4Fh
                db      29h,0BFh,29h,43h,06h,0FFh,06h,3Ch,46h,0CBh,09h,30h,29h,48h,49h,0CFh
                db      0Bh,30h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,3Ch,46h,0CBh,09h,30h
                db      29h,48h,49h,0CFh,09h,35h,29h,44h,49h,0C8h,09h,38h,29h,48h,49h,0CDh
                db      09h,3Ch,29h,4Dh,49h,0D0h,0Bh,30h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh
                db      06h,3Ch,46h,0CBh,09h,30h,29h,48h,49h,0CFh,0Bh,30h,4Bh,4Fh,29h,0BFh
                db      29h,43h,06h,0FFh,06h,3Ch,46h,0CBh,09h,30h,29h,48h,49h,0CFh,09h,35h
                db      29h,44h,49h,0D4h,09h,38h,29h,48h,49h,0D9h,09h,3Ch,29h,4Dh,49h,0DCh
                db      0Bh,30h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,3Ch,46h,0CBh,09h,30h
                db      29h,48h,49h,0CFh,0Bh,30h,4Bh,4Fh,29h,0BFh,29h,43h,06h,0FFh,06h,3Ch
                db      46h,0CBh,09h,30h,29h,48h,49h,0CFh,09h,35h,29h,45h,49h,0D4h,09h,39h
                db      29h,48h,49h,0D9h,09h,3Ch,29h,4Dh,49h,0DCh,31h,48h,51h,5Ch,0Ch,0B8h
                db      09h,0B8h,0Ch,0B8h,09h,0B8h,0Ch,0B8h,0FCh,2Fh,21h,09h,38h,29h,48h,49h
                db      0CBh,0Ch,38h,4Bh,4Ch,2Bh,0C9h,46h,0CEh,09h,38h,29h,49h,49h,0D0h,2Fh
                db      48h,4Fh,4Bh,0Ch,0B8h,09h,0B8h,0Ch,0B8h,09h,38h,29h,48h,49h,0CBh,0Ch
                db      38h,4Bh,4Ch,2Bh,0C9h,46h,0CEh,09h,38h,29h,49h,49h,0D0h,2Eh,4Bh,0Bh
                db      2Fh,49h,0CEh,49h,47h,06h,0FFh,06h,0B1h,49h,53h,09h,0B3h,0Eh,34h,2Eh
                db      47h,4Bh,0D0h,46h,0CEh,49h,0CCh,0Eh,30h,49h,4Fh,29h,0CCh,29h,4Ah,49h
                db      0CEh,29h,48h,49h,0CCh,0Eh,2Fh,49h,4Ah,29h,0C7h,29h,43h,49h,0C7h,29h
                db      3Eh,49h,0C3h,2Fh,49h,4Fh,4Ch,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h
                db      49h,49h,0CCh,0Ch,2Dh,4Bh,4Dh,2Bh,0CAh,46h,0CFh,49h,51h,09h,0ADh,2Fh
                db      49h,4Fh,4Ch,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h,49h,49h,0CCh,2Bh
                db      4Ah,4Bh,4Dh,09h,0B2h,09h,30h,06h,0FFh,46h,0CFh,49h,51h,09h,0AEh,4Fh
                db      4Ch,2Fh,49h,0Ch,0ADh,09h,0ADh,0Ch,0ADh,09h,2Dh,29h,49h,49h,0CCh,0Eh
                db      37h,2Bh,4Ah,49h,0CEh,49h,51h,06h,0FFh,26h,0C7h,29h,45h,49h,0CEh,2Eh
                db      49h,4Eh,4Ch,0Ch,0ADh,09h,0ADh,2Bh,4Ah,09h,37h,49h,0CEh,49h,51h,09h
                db      32h,06h,0FFh,26h,0C7h,29h,45h,49h,4Eh,09h,0B7h,51h,4Ch,2Ch,47h,09h
                db      0AFh,09h,0B6h,09h,0BBh,2Ch,45h,09h,0AFh,09h,0B6h,09h,0BBh,51h,4Bh,2Ch
                db      43h,09h,0AFh,09h,0B6h,09h,0BBh,2Ch,42h,09h,0AFh,09h,0B6h,09h,0BBh,0FCh
                db      2Fh,21h,4Bh,47h,0Bh,34h,2Bh,43h,09h,0FFh,09h,3Bh,06h,0FFh,46h,4Ch
                db      26h,0C7h,49h,4Fh,09h,40h,29h,0CCh,49h,4Eh,09h,36h,29h,0CBh,49h,4Ch
                db      09h,3Bh,29h,0C9h,49h,4Eh,09h,42h,29h,0CBh,4Bh,4Fh,2Bh,4Ah,09h,37h
                db      09h,0FFh,09h,3Eh,06h,0FFh,46h,4Eh,26h,0CAh,49h,4Ch,09h,43h,29h,0CAh
                db      49h,4Ah,09h,39h,29h,0C7h,49h,48h,09h,40h,29h,0C5h,49h,45h,09h,39h
                db      29h,0C2h,4Bh,47h,2Bh,43h,09h,2Fh,09h,0FFh,09h,3Bh,06h,0FFh,46h,4Ch
                db      26h,0C7h,49h,4Fh,09h,2Fh,29h,0CCh,49h,51h,09h,30h,29h,0CEh,49h,4Fh
                db      09h,3Ch,29h,0CCh,49h,51h,09h,30h,29h,0CEh,51h,53h,2Eh,4Ch,0Bh,0AFh
                db      06h,0BBh,09h,0AFh,2Eh,4Bh,0Bh,0AFh,06h,0BBh,09h,0AFh,0Ch,30h,2Ch,4Ch
                db      4Bh,0D3h,46h,0D3h,49h,0D3h,2Ch,4Ah,0Ch,37h,49h,0D3h,49h,0CFh,49h,0D1h
                db      0Ch,30h,2Ch,4Ch,4Bh,0D3h,46h,0D3h,49h,0D3h,2Ch,4Ah,0Ch,37h,49h,0D3h
                db      49h,0CFh,49h,0D1h,0Ch,30h,2Ch,4Ch,4Bh,0D3h,46h,0D1h,49h,0CFh,0Ch,30h
                db      2Ch,4Ch,49h,0D1h,49h,0CFh,49h,0CCh,11h,2Fh,51h,4Eh,26h,0CBh,26h,0B3h
                db      26h,0B6h,26h,0B9h,26h,0BBh,26h,0BFh,26h,0C2h,26h,0C5h,26h,0C7h,26h,0CBh
                db      26h,0CEh,26h,0D1h,0FCh,2Fh,21h,4Eh,53h,2Eh,4Fh,0Bh,0BBh,06h,0C0h,09h
                db      0C3h,4Eh,53h,2Eh,51h,09h,0C2h,09h,0C0h,09h,0C2h,4Eh,53h,2Eh,4Fh,0Bh
                db      0C3h,06h,0BBh,09h,0C0h,4Eh,54h,2Eh,51h,09h,0BEh,09h,0BCh,09h,0B9h,4Eh
                db      53h,2Eh,4Fh,0Bh,0BBh,06h,0C0h,09h,0C3h,4Eh,54h,2Eh,4Fh,09h,0C5h,09h
                db      0C3h,09h,0C5h,11h,47h,2Eh,4Fh,4Eh,0D3h,4Eh,53h,2Eh,0CEh,0Ch,30h,4Bh
                db      53h,26h,0C0h,26h,0C3h,26h,0C8h,26h,40h,46h,0D8h,49h,53h,26h,0C3h,26h
                db      0C8h,0Ch,37h,49h,56h,26h,0BEh,26h,0C3h,49h,53h,26h,0C7h,26h,0BEh,49h
                db      4Fh,26h,0C3h,26h,0C7h,0Ch,30h,4Bh,4Ch,26h,0C0h,26h,0C3h,26h,0C8h,26h
                db      40h,46h,0CFh,49h,54h,26h,0C3h,26h,0C8h,0Ch,37h,49h,53h,26h,0BEh,26h
                db      0C3h,49h,4Fh,26h,0C7h,26h,0BEh,49h,4Ah,26h,0C3h,26h,0C7h,2Ch,46h,4Bh
                db      0D1h,46h,0D6h,49h,0D1h,2Ch,41h,49h,0D4h,49h,0D1h,49h,0CDh,2Ch,46h,4Bh
                db      0CAh,46h,0CDh,49h,0D2h,2Ch,41h,49h,0D1h,49h,0CDh,49h,0C8h,0FCh,2Fh,21h
                db      0Eh,3Eh,2Eh,46h,4Bh,0D1h,46h,0CDh,49h,0CAh,51h,4Fh,2Ch,47h,0Ch,0B2h
                db      09h,32h,29h,0C7h,0Ch,32h,2Ch,0C7h,09h,32h,29h,0C7h,0Eh,3Eh,2Eh,46h
                db      4Bh,0D1h,46h,0CDh,49h,0CAh,51h,4Fh,2Ch,47h,0Ch,0B2h,09h,32h,29h,0C7h
                db      0Ch,32h,2Ch,0C7h,09h,32h,29h,0C7h,4Bh,51h,29h,0BEh,0Ch,2Eh,29h,41h
                db      06h,0FFh,46h,0CDh,49h,4Ah,29h,0C6h,4Bh,52h,29h,0BEh,0Ch,37h,29h,43h
                db      06h,0FFh,46h,0CFh,49h,4Ah,29h,0C6h,4Bh,53h,29h,0BEh,0Ch,37h,29h,43h
                db      06h,0FFh,46h,0CFh,49h,4Dh,29h,0C7h,4Bh,54h,29h,0C0h,0Ch,30h,29h,43h
                db      06h,0FFh,46h,0CFh,49h,4Dh,29h,0C8h,4Bh,55h,29h,0C0h,0Ch,2Dh,29h,45h
                db      06h,0FFh,46h,0D1h,49h,4Fh,29h,0C9h,4Bh,56h,29h,0C1h,0Ch,32h,29h,45h
                db      06h,0FFh,46h,0D1h,49h,4Dh,29h,0CAh,49h,58h,09h,30h,29h,0D1h,0Bh,2Eh
                db      29h,4Fh,49h,0D9h,49h,5Bh,29h,4Ah,06h,0FFh,06h,0BAh,49h,5Ch,09h,2Eh
                db      29h,0C8h,0Eh,2Dh,2Bh,49h,4Bh,0DDh,46h,51h,26h,0C9h,49h,51h,29h,0C9h
                db      0Eh,2Eh,2Bh,4Ah,4Bh,0DDh,46h,51h,26h,0CAh,49h,51h,29h,0CAh,0Bh,2Dh
                db      2Bh,49h,4Bh,0DDh,46h,51h,06h,2Fh,26h,0C9h,49h,51h,29h,49h,09h,0B1h
                db      49h,56h,29h,4Dh,09h,0B2h,0Bh,2Eh,29h,4Ch,49h,0D8h,29h,4Ah,49h,59h
                db      06h,0FFh,06h,0BAh,09h,2Eh,29h,48h,49h,0DBh,0Eh,2Dh,2Bh,49h,4Bh,0DDh
                db      46h,51h,26h,0C9h,49h,51h,29h,0C9h,0Eh,2Eh,2Bh,4Ah,4Bh,0DDh,46h,51h
                db      26h,0CAh,49h,51h,29h,0CAh,4Bh,5Dh,0Bh,2Dh,2Bh,0C9h,46h,51h,06h,2Fh
                db      26h,0C9h,49h,51h,29h,49h,09h,0B1h,09h,32h,49h,56h,29h,0CDh,0FFh,00h
                db      00h,00h,0FDh,30h,00h,0FFh,10h,0Ch,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,0B1h
                db      21h,0FFh,1Ch,0EDh,05h,0FFh,24h,00h,10h,0FFh,22h,28h,00h,0FFh,20h,2Ch
                db      01h,0FDh,60h,00h,0FFh,10h,07h,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,91h,21h
                db      0FFh,1Ch,0EDh,05h,0FFh,24h,00h,10h,0FFh,22h,16h,00h,0FFh,20h,78h,00h
                db      0FDh,00h,00h,0FFh,10h,07h,00h,0FFh,12h,0D3h,0FFh,0FFh,16h,0D1h,21h,0FFh
                db      1Ch,0EDh,06h,0FFh,24h,00h,02h,0FFh,22h,0C8h,00h,0FFh,20h,10h,00h,0FFh
                db      0Eh,06h,00h,0FBh,50h,0C3h,0FFh,0FFh,0C4h,09h,04h,00h,30h,0F8h,06h,00h
                db      00h,00h,00h,00h,80h,0BBh,0FFh,0FFh,0C0h,0E0h,06h,00h,00h,00h,0FFh,0FFh
                db      00h,00h,00h,00h,40h,9Ch,0FFh,0FFh,0C4h,09h,08h,00h,48h,0F4h,05h,00h
                db      00h,00h,00h,00h,0C8h,0AFh,0FFh,0FFh,60h,0F0h,0Bh,00h,00h,00h,0FFh,0FFh
                db      00h,00h,00h,00h,0A8h,0DEh,0FFh,0FFh,24h,0FAh,06h,00h,00h,00h,00h,00h
                db      00h,00h,00h,00h,80h,0BBh,0FFh,0FFh,0C0h,0E0h,06h,00h,00h,00h,0FFh,0FFh
                db      00h,00h,00h,00h
; The INT 8 handler the driver replaced.
oldInt8         dd      0A09090Bh

; InstallSoundTimer -- point INT 8 at timerHandler, saving the old vector, and speed up the timer.
InstallSoundTimer:
        push    ds
        push    es
        mov     ax,CODE
        mov     ds,ax
        ; Save the old INT 8 vector.
        mov     ax,3508h
        int     21h
        mov     word ptr cs:[oldInt8],bx
        mov     word ptr cs:[oldInt8+2],es
        ; Install timerHandler.
        push    ds
        mov     dx,CODE
        mov     ds,dx
        mov     dx,offset timerHandler
        mov     ax,2508h
        int     21h
        pop     ds
        ; Put PIT channel 2, the speaker's, in square-wave mode, then reload channel 0 with 13B1h for about 237 ticks a
        ; second; channel 0 keeps the BIOS's mode.
        mov     al,0B6h
        out     43h,al
        mov     ax,13B1h
        out     40h,al
        mov     al,ah
        out     40h,al
        pop     es
        pop     ds
        retf

; UninstallSoundTimer -- put back the old INT 8 handler and the BIOS's timer rate, and silence both banks.
UninstallSoundTimer:
        push    ds
        mov     ax,CODE
        mov     ds,ax
        ; Restore the saved INT 8 vector.
        push    ds
        mov     dx,word ptr cs:[oldInt8]
        mov     ax,word ptr cs:[oldInt8+2]
        mov     ds,ax
        mov     ax,2508h
        int     21h
        pop     ds
        ; Channel 0 back to the BIOS's 18.2 Hz reload, written low byte then high.
        mov     ax,0FFFFh
        out     40h,al
        mov     al,ah
        out     40h,al
        ; Turn off the speaker and set each Tandy channel to full attenuation.
        in      al,61h
        and     al,0FCh
        out     61h,al
        mov     al,9Fh
        out     0C0h,al
        mov     al,0BFh
        out     0C0h,al
        mov     al,0DFh
        out     0C0h,al
        mov     al,0FFh
        out     0C0h,al
        pop     ds
        retf

; timerHandler -- the INT 8 handler. Count down DriverData, run both banks unless a run is already in progress, then
; send every thirteenth tick on to the BIOS handler and acknowledge the others here.
timerHandler:
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax,CODE
        mov     ds,ax
        ; An armed countdown that reaches zero ends the program: set the current video mode again to clear the screen,
        ; print the run-time error at the top left of the screen and exit with code 255.
        cmp     word ptr [DriverData],0
        je      runVoices
        dec     word ptr [DriverData]
        jne     runVoices
        mov     ah,0Fh
        int     10h
        mov     ah,0
        int     10h
        mov     bl,7
        mov     ah,13h
        mov     al,1
        mov     bh,0
        mov     cx,21h
        xor     dx,dx
        mov     bp,CODE
        mov     es,bp
        mov     bp,offset crashMsg
        int     10h
        mov     ah,4Ch
        mov     al,0FFh
        int     21h
; Run both banks, holding off any tick that arrives before they finish.
runVoices:
        cmp     byte ptr [inTick],0
        jne     divideTick
        mov     byte ptr [inTick],1
        call    updateSpeaker
        call    updateTandy
        mov     byte ptr [inTick],0
; Every thirteenth tick the BIOS handler takes over and acknowledges the interrupt itself.
divideTick:
        dec     byte ptr [tickDivider]
        jne     ackTimer
        mov     byte ptr [tickDivider],0Dh
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8]
; Acknowledge the interrupt at the PIC.
ackTimer:
        mov     al,20h
        out     20h,al
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret

; updateSpeaker -- run bank A's voices, then give the speaker to the first voice still sounding: its divisor goes to PIT
; channel 2 and its level's low bits to the gate bits of port 61h. With no sound loaded, no voice sounding or output
; turned off, the gate bits are cleared.
updateSpeaker:
        mov     bx,word ptr [soundId]
        cmp     bx,0
        je      setSpeakerGate
        mov     word ptr [speakerVoice],0
        mov     byte ptr [voiceCount],4
        mov     si,offset freqTableA
        mov     word ptr [freqTable],si
        mov     si,offset voicesA
        mov     word ptr [voiceBase],si
speakerVoiceLoop:
        cmp     word ptr [si].ticks,0
        je      nextSpeakerVoice
        call    stepVoice
        cmp     word ptr [speakerVoice],0
        jne     nextSpeakerVoice
        cmp     word ptr [si].level,0
        je      nextSpeakerVoice
        cmp     word ptr [si].ticks,0
        je      nextSpeakerVoice
        mov     word ptr [speakerVoice],si
nextSpeakerVoice:
        add     si,SIZE TVoice
        dec     byte ptr [voiceCount]
        jne     speakerVoiceLoop
        mov     bl,byte ptr [outputOn]
        cmp     bl,0
        je      setSpeakerGate
        mov     bx,word ptr [speakerVoice]
        cmp     bx,0
        je      setSpeakerGate
        mov     si,bx
        mov     ax,word ptr [si].divisor
        out     42h,al
        mov     al,ah
        out     42h,al
        mov     bx,word ptr [si].level
        and     bl,3
setSpeakerGate:
        in      al,61h
        and     al,0FCh
        or      al,bl
        out     61h,al
        ret

; updateTandy -- run bank B's voices, then send each voice's divisor and attenuation to the Tandy chip. With no sound
; loaded or output turned off, the chip is silenced.
updateTandy:
        mov     bx,word ptr [soundId]
        cmp     bx,0
        je      silenceTandy
        mov     byte ptr [voiceCount],4
        mov     si,offset freqTableB
        mov     word ptr [freqTable],si
        mov     si,offset voicesB
        mov     word ptr [voiceBase],si
tandyVoiceLoop:
        cmp     word ptr [si].ticks,0
        je      nextTandyVoice
        call    stepVoice
nextTandyVoice:
        add     si,SIZE TVoice
        dec     byte ptr [voiceCount]
        jne     tandyVoiceLoop
        mov     al,byte ptr [outputOn]
        cmp     al,0
        je      silenceTandy
        mov     byte ptr [voiceCount],4
        mov     si,offset voicesB
        mov     dl,80h
; The tone channels take a ten-bit divisor in two writes; the noise channel takes one.
tandyOutLoop:
        mov     ax,word ptr [si].divisor
        shr     ax,1
        shr     ax,1
        shr     al,1
        shr     al,1
        shr     al,1
        shr     al,1
        xor     al,dl
        out     0C0h,al
        cmp     dl,0E0h
        je      tandyLevel
        mov     al,ah
        out     0C0h,al
; The attenuation is the inverse of the level's top four bits.
tandyLevel:
        mov     ax,0FFFFh
        sub     ax,word ptr [si].level
        shr     ah,1
        shr     ah,1
        shr     ah,1
        shr     ah,1
        mov     al,ah
        xor     al,dl
        add     al,10h
        out     0C0h,al
        add     dl,20h
        add     si,SIZE TVoice
        dec     byte ptr [voiceCount]
        jne     tandyOutLoop
        ret
; Set each Tandy channel to full attenuation.
silenceTandy:
        mov     al,9Fh
        out     0C0h,al
        mov     al,0BFh
        out     0C0h,al
        mov     al,0DFh
        out     0C0h,al
        mov     al,0FFh
        out     0C0h,al
        ret

; stepVoice -- advance the voice at SI by one tick: step its level and pitch, apply its vibrato, move its envelope on
; and run its script when its step runs out.
stepVoice:
        push    cx
        push    di
        mov     ax,word ptr [si].levelStep
        add     word ptr [si].level,ax
        mov     ax,word ptr [si].slide
        add     word ptr [si].pitch,ax
        ; Vibrato: step the phase through the wave and scale the wave's sample by the depth; the high word of the
        ; product is the offset added to the pitch.
        sub     dx,dx
        mov     ax,word ptr [si].phase
        add     ax,word ptr [si].phaseStep
        je      setDivisor
        cmp     ax,word ptr [si].waveLength
        jb      storePhase
        sub     ax,word ptr [si].waveLength
storePhase:
        mov     word ptr [si].phase,ax
        mov     cl,4
        sar     ax,cl
        add     ax,word ptr [si].wave
        mov     di,ax
        mov     ah,byte ptr [di]
        mov     al,0
        imul    word ptr [si].depth
setDivisor:
        add     dx,word ptr [si].pitch
        mov     word ptr [si].divisor,dx
        ; When the note's gate runs out, the envelope jumps to its release entries.
        cmp     word ptr [si].gateTicks,0
        je      countTicks
        dec     word ptr [si].gateTicks
        jne     countTicks
        mov     word ptr [si].envIndex,10h
        mov     word ptr [si].envTicks,1
countTicks:
        dec     word ptr [si].ticks
        jne     stepEnvelope
        call    runScript
; Move the envelope on when its entry runs out. An entry with a count of -1 sets the level outright, and a level of zero
; also stops the ramp; the next entry follows at once. Any other entry ramps the level by its value for its count of
; ticks.
stepEnvelope:
        cmp     word ptr [si].envTicks,0
        je      stepVoiceDone
        dec     word ptr [si].envTicks
        jne     stepVoiceDone
nextEnvEntry:
        mov     bx,word ptr [si].envelope
        add     bx,word ptr [si].envIndex
        cmp     word ptr [bx+2],-1
        jne     setEnvRamp
        mov     ax,word ptr [bx]
        mov     word ptr [si].level,ax
        cmp     ax,0
        jne     skipEnvEntry
        mov     word ptr [si].levelStep,ax
skipEnvEntry:
        add     word ptr [si].envIndex,4
        jmp     nextEnvEntry
setEnvRamp:
        mov     ax,word ptr [bx]
        mov     word ptr [si].levelStep,ax
        mov     ax,word ptr [bx+2]
        mov     word ptr [si].envTicks,ax
        add     word ptr [si].envIndex,4
stepVoiceDone:
        pop     di
        pop     cx
        ret

; runScript -- run the script of the voice at SI up to its next wait: a chord of notes, or an opSetField that sets the
; voice's ticks. A byte below 0FAh starts a note; 0FAh to 0FFh are opcodes.
runScript:
        mov     di,word ptr [si].script
        cmp     di,0
        jne     startScript
        ret
startScript:
        mov     word ptr [curVoice],si
nextOp:
        mov     bl,byte ptr [di]
        inc     di
        cmp     bl,0FAh
        jae     dispatchOp
        jmp     playNote
dispatchOp:
        sub     bh,bh
        sub     bl,0FAh
        add     bl,bl
        jmp     word ptr [bx+opTable]

; opLoop (0FEh) -- count down the voice field the next byte names and jump to the word after it until the count runs
; out; a count already at zero jumps every time.
opLoop:
        mov     bl,byte ptr [di]
        inc     di
        mov     bh,0
        mov     ax,word ptr [di]
        add     di,2
        cmp     word ptr [bx+si],0
        je      opLoopJump
        dec     word ptr [bx+si]
        je      nextOp
opLoopJump:
        mov     di,ax
        jmp     nextOp

; opSelectVoice (0FDh) -- make the voice at the given offset in the bank the current one, then clear it.
opSelectVoice:
        mov     si,word ptr [di]
        add     di,2
        add     si,word ptr [voiceBase]

; opClearVoice (0FAh) -- clear the current voice's sound settings.
opClearVoice:
        sub     bx,bx
        mov     word ptr [si].pitch,bx
        mov     word ptr [si].slide,bx
        mov     word ptr [si].divisor,bx
        mov     word ptr [si].level,bx
        mov     word ptr [si].levelStep,bx
        mov     word ptr [si].release,bx
        mov     word ptr [si].transpose,bx
        mov     word ptr [si].envelope,bx
        mov     word ptr [si].envIndex,bx
        mov     word ptr [si].envTicks,bx
        mov     word ptr [si].wave,bx
        mov     word ptr [si].phase,bx
        mov     word ptr [si].phaseStep,bx
        mov     word ptr [si].depth,bx
        mov     word ptr [si].waveLength,bx
        jmp     nextOp

; opSetField (0FFh) -- store a word in the voice field the next byte names. Setting the ticks ends the step.
opSetField:
        mov     bl,byte ptr [di]
        inc     di
        mov     bh,0
        mov     ax,word ptr [di]
        inc     di
        inc     di
        mov     word ptr [bx+si],ax
        cmp     bl,0
        jne     nextOp

; End the step: keep the script's place, or, when the voice was given no ticks, end its script.
suspendScript:
        mov     si,word ptr [curVoice]
        cmp     word ptr [si].ticks,0
        jne     saveScriptPtr
        mov     bl,4
        sub     bl,byte ptr [voiceCount]
        sub     bh,bh
        mov     byte ptr [bx+voiceSounds],0
        mov     di,0
saveScriptPtr:
        mov     word ptr [si].script,di
        ret

; opReturn (0FBh) -- resume after the last opCall.
opReturn:
        mov     di,word ptr [returnPtr]
        jmp     nextOp

; opCall (0FCh) -- run the script at the given address, returning to the next byte on opReturn.
opCall:
        mov     ax,word ptr [di]
        add     di,2
        mov     word ptr [returnPtr],di
        mov     di,ax
        jmp     nextOp
; Take the next note of a chord.
nextNote:
        mov     bl,byte ptr [di]
        inc     di

; playNote -- the note byte's top three bits pick the voice in the bank and its low five bits a length from noteLengths,
; multiplied by the current voice's tempo, where a tempo of zero counts as one. The next byte holds the semitone, 7Fh
; for a rest, with bit 7 set on the last note of a chord.
playNote:
        push    di
        mov     al,bl
        mov     cl,5
        shr     al,cl
        mul     byte ptr [voiceSize]
        add     ax,word ptr [voiceBase]
        mov     di,ax
        and     bx,1Fh
        mov     ax,word ptr [si].tempo
        cmp     al,0
        jne     scaleLength
        inc     al
scaleLength:
        mul     byte ptr [bx+noteLengths]
        mov     word ptr [si].ticks,ax
        pop     bx
        push    bx
        mov     al,byte ptr [bx]
        and     ax,7Fh
        cmp     ax,7Fh
        je      noteDone
        mov     cx,word ptr [si].ticks
        mov     word ptr [di].ticks,cx
        sub     cx,word ptr [di].release
        mov     word ptr [di].gateTicks,cx
        add     ax,word ptr [di].transpose
        mov     word ptr [di].envIndex,0
        mov     word ptr [di].envTicks,1
        mov     cx,0FFh
; Split the transposed semitone into an octave and a note; each octave up halves the divisor. Note: the test for the
; noise voice branches to the next instruction either way.
findOctave:
        inc     cl
        sub     ax,0Ch
        jae     findOctave
        add     ax,0Ch
        mov     bx,ax
        add     bx,bx
        cmp     di,offset voicesB+3*SIZE TVoice
        jne     lookUpDivisor
lookUpDivisor:
        add     bx,word ptr [freqTable]
        mov     ax,word ptr [bx]
        shr     ax,cl
        mov     word ptr [di].pitch,ax
        mov     word ptr [di].divisor,ax
; A chord's notes follow one another; the last one ends the step.
noteDone:
        pop     di
        mov     al,byte ptr [di]
        inc     di
        and     al,80h
        jne     chordDone
        jmp     nextNote
chordDone:
        jmp     suspendScript

; ProgramSpeakerVoices -- load sound value into bank A: each voice with a script for it is cleared and starts that
; script on the next tick. Note: returns without removing its parameter from the stack.
ProgramSpeakerVoices:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si,CODE
        mov     ds,si
        mov     si,word ptr [bp+6]
        mov     word ptr [soundId],si
        add     si,si
        add     si,si
        add     si,si
        mov     byte ptr [inTick],1
        mov     byte ptr [voiceCount],4
        mov     di,offset voicesA
loadVoiceA:
        mov     ax,word ptr [si+soundsA]
        cmp     ax,0
        je      nextVoiceA
        mov     bx,SIZE TVoice-2
clearVoiceA:
        mov     word ptr [bx+di],0
        sub     bx,2
        jge     clearVoiceA
        mov     word ptr [di].script,ax
        mov     bl,4
        sub     bl,byte ptr [voiceCount]
        sub     bh,bh
        mov     ax,word ptr [soundId]
        mov     byte ptr [bx+voiceSounds],al
        mov     word ptr [di].ticks,1
nextVoiceA:
        add     di,SIZE TVoice
        add     si,2
        dec     byte ptr [voiceCount]
        jne     loadVoiceA
        mov     byte ptr [inTick],0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf

; ProgramTandyVoices -- load sound value into bank B, as ProgramSpeakerVoices does for bank A. Note: returns without
; removing its parameter from the stack.
ProgramTandyVoices:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si,CODE
        mov     ds,si
        mov     si,word ptr [bp+6]
        mov     word ptr [soundId],si
        add     si,si
        add     si,si
        add     si,si
        mov     byte ptr [inTick],1
        mov     byte ptr [voiceCount],4
        mov     di,offset voicesB
loadVoiceB:
        mov     ax,word ptr [si+soundsB]
        cmp     ax,0
        je      nextVoiceB
        mov     bx,SIZE TVoice-2
clearVoiceB:
        mov     word ptr [bx+di],0
        sub     bx,2
        jge     clearVoiceB
        mov     word ptr [di].script,ax
        mov     bl,4
        sub     bl,byte ptr [voiceCount]
        sub     bh,bh
        mov     ax,word ptr [soundId]
        mov     byte ptr [bx+voiceSounds],al
        mov     word ptr [di].ticks,1
nextVoiceB:
        add     di,SIZE TVoice
        add     si,2
        dec     byte ptr [voiceCount]
        jne     loadVoiceB
        mov     byte ptr [inTick],0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf

; SetVoiceByte -- set outputOn from the low byte of value. Note: returns without removing its parameter from the stack.
SetVoiceByte:
        push    bp
        mov     bp,sp
        push    ax
        push    ds
        mov     ax,CODE
        mov     ds,ax
        mov     ax,word ptr [bp+6]
        mov     byte ptr [outputOn],al
        pop     ds
        pop     ax
        pop     bp
        retf

; Unused bytes after the last routine.
        db      00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h

CODE    ENDS
        END
