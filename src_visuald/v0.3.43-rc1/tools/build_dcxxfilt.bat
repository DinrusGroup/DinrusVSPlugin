@echo off
rem unpack and configure binutils 2.25+
rem don't use spaces in path names!

setlocal
if "%DMDINSTALLDIR%" == "" set DMDINSTALLDIR=m:\s\d\rainers
if "%DMD%" == "" set DMD=%DMDINSTALLDIR%\windows\bin\dmd
if "%BINUTILS%" == "" set BINUTILS=c:\s\cpp\cxxfilt

if "%CONFIG%" == "" set CONFIG=Debug

set OUTDIR=..\bin\%CONFIG%
set LIBIBERTY=%BINUTILS%\libiberty

%DMD% -c -m32mscoff -of%OUTDIR%\dcxxfilt.obj dcxxfilt.d || exit /B 1

set SRC=
set SRC=%SRC% %LIBIBERTY%\d-demangle.c
set SRC=%SRC% %LIBIBERTY%\cp-demangle.c %LIBIBERTY%\cplus-dem.c 
set SRC=%SRC% %LIBIBERTY%\xmalloc.c %LIBIBERTY%\xstrdup.c %LIBIBERTY%\xexit.c 
set SRC=%SRC% %LIBIBERTY%\safe-ctype.c 
set SRC=%SRC% %LIBIBERTY%\alloca.c

set COPT=-I %BINUTILS% -I %BINUTILS%\include -I %BINUTILS%\binutils -DHAVE_CONFIG_H
set LIB=%LIB%;%DMDINSTALLDIR%\lib32
cl /Ox /Fe%OUTDIR%\dcxxfilt.exe /Fo%OUTDIR%\ %COPT% %SRC% %OUTDIR%\dcxxfilt.obj dbghelp.lib
