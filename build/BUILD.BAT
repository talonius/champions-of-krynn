@ECHO OFF
REM ==========================================================================
REM  Champions of Krynn v1.0 -- THE BUILD.
REM
REM  Runs under DOS: Borland's TASM and TPC emit the two
REM  files SSI shipped, START.EXE and GAME.OVR, into E:\OBJ under those names.
REM  TPC reads compiler settings from E:\SRC\TPC.CFG; the command below
REM  supplies the rebuild mode and output/object directories.
REM
REM  Drive letters, assigned by gametools/build.sh. Each tool gets a letter
REM  rather than a PATH entry: the environment is charged against TPC's link.
REM      C:  drive_c (game data)       E:  the version dir (v10)
REM      D:  TPC.EXE and TURBO.TPL     F:  TASM
REM      H:  this file's directory (v10/build)
REM ==========================================================================
E:
CD \SRC
PATH D:\

REM --- remove cached units, objects and whole-image outputs ----------------
IF EXIST E:\OBJ\*.TPU DEL E:\OBJ\*.TPU
IF EXIST E:\OBJ\*.OBJ DEL E:\OBJ\*.OBJ
IF EXIST E:\OBJ\FIXMAIN.EXE DEL E:\OBJ\FIXMAIN.EXE
IF EXIST E:\OBJ\FIXMAIN.OVR DEL E:\OBJ\FIXMAIN.OVR
IF EXIST E:\OBJ\FIXMAIN.MAP DEL E:\OBJ\FIXMAIN.MAP
IF EXIST E:\OBJ\START.EXE DEL E:\OBJ\START.EXE
IF EXIST E:\OBJ\GAME.OVR DEL E:\OBJ\GAME.OVR
IF EXIST *.TPU DEL *.TPU
IF EXIST *.OBJ DEL *.OBJ

REM --- the assembly inputs, one line each -----------------------------------
REM  gametools/build.sh refuses if this list and src/*.asm disagree.
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
REM  START.EXE, a raw MZ image.
REN E:\OBJ\FIXMAIN.OVR GAME.OVR
REN E:\OBJ\FIXMAIN.EXE START.EXE
