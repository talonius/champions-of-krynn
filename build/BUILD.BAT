@ECHO OFF
REM ==========================================================================
REM  Champions of Krynn v1.2 -- THE BUILD.
REM
REM  Runs under DOS: Borland's TASM and TPC and Microsoft's EXEPACK emit the two
REM  files SSI shipped, START.EXE and GAME.OVR, into E:\OBJ under those names.
REM  TPC reads its settings from E:\SRC\TPC.CFG; /B and output paths are below.
REM
REM  Drive letters, assigned by build.sh. Each tool gets a letter
REM  rather than a PATH entry: the environment is charged against TPC's link.
REM      C:  drive_c (game data)       E:  this repository
REM      D:  TPC.EXE and TURBO.TPL     F:  TASM
REM      G:  EXEPACK
REM ==========================================================================
E:
CD \SRC
PATH D:\

REM --- clear units, objects, and the whole-image outputs -------------------
IF EXIST E:\OBJ\*.TPU DEL E:\OBJ\*.TPU
IF EXIST E:\OBJ\*.OBJ DEL E:\OBJ\*.OBJ
IF EXIST E:\OBJ\FIXMAIN.EXE DEL E:\OBJ\FIXMAIN.EXE
IF EXIST E:\OBJ\FIXMAIN.OVR DEL E:\OBJ\FIXMAIN.OVR
IF EXIST E:\OBJ\FIXMAIN.MAP DEL E:\OBJ\FIXMAIN.MAP
IF EXIST E:\OBJ\START.EXE DEL E:\OBJ\START.EXE
IF EXIST E:\OBJ\GAME.OVR DEL E:\OBJ\GAME.OVR
IF EXIST *.TPU DEL *.TPU
IF EXIST *.OBJ DEL *.OBJ

REM --- assembly inputs, one line each --------------------------------------
REM  Keep this list in step with src/*.asm.
F:\TASM BLIT,E:\OBJ\BLIT          > E:\BUILD\LOGS\TASM.OUT
F:\TASM JOYSTICK,E:\OBJ\JOYSTICK >> E:\BUILD\LOGS\TASM.OUT
F:\TASM SNDLOAD,E:\OBJ\SNDLOAD   >> E:\BUILD\LOGS\TASM.OUT
F:\TASM SOUNDDRV,E:\OBJ\SOUNDDRV       >> E:\BUILD\LOGS\TASM.OUT
F:\TASM TEXTREND,E:\OBJ\TEXTREND >> E:\BUILD\LOGS\TASM.OUT

REM --- the compiler ---------------------------------------------------------
REM  /B rebuilds every unit (make cannot see TPC.CFG). /E..\OBJ and /O..\OBJ
REM  are locations: where TPC writes its outputs and finds TASM's .OBJ files.
TPC FIXMAIN.PAS /B /E..\OBJ /O..\OBJ > E:\BUILD\LOGS\TPC_01.OUT

REM --- the shipped names ----------------------------------------------------
REM  TPC names both outputs after the root; SSI shipped them as GAME.OVR and
REM  START.EXE, packed by EXEPACK. FIXMAIN.EXE stays: it is the packer's input.
REN E:\OBJ\FIXMAIN.OVR GAME.OVR
G:\EXEPACK E:\OBJ\FIXMAIN.EXE E:\OBJ\START.EXE > E:\BUILD\LOGS\PACK.OUT
