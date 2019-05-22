@echo off

REM Compiler switches: https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=vs-2019

REM WX     - Treat warnings as errors.
REM wdxxx  - Disable warning xxxx.
REM Zi     - Generate debug information.
REM Oi     - Use intrinsics.
REM EHsc   - 
REM EHa    - 
REM nologo - Don't show compiler info when compiling.
REM subsystem:windows,5.1 - Make compatible with Windows XP.
REM MD     - Dynamically link CRT.
REM MT     - Statically link CRT. Required to make compatiable with other Windows versions.
REM opt:ref - Try to remove unused code.
REM Gm-    - Disable minimal rebuild.
REM GR-    - Disable run-time type information, RTTI.
REM Fm     - Creates a map file at specified path.
REM LD     - Creates a dynamic-link library.
REM LDd    - Creates a debug dynamic-link library.
REM incremental:no - Turns off incremental builds.
REM Od     - Disables optimization.

REM ---- WARNINGS ----
REM C4244 - 
REM C4201 - Non-standard extension used.
REM C4100 - Unreferenced formal parameter.
REM C4189 - Local variable is initialized but not referenced.

set WARNINGS=-W4 -WX -wd4100
set DEBUG=-Zi -Od

set SHARED_COMPILER_FLAGS=-Od -Oi -Zi -MT -nologo -Gm- -GR- -EHa- -DUNICODE -D_CRT_SECURE_NO_WARNINGS -I ..\..\   %WARNINGS%
set SHARED_LINKER_FLAGS=

set WIN32_COMPILER_FLAGS=
set WIN32_LINKER_FLAGS=-incremental:no -opt:ref user32.lib gdi32.lib winmm.lib
set WIN32_OUTPUT_FILE=
set WIN32_SOURCE_FILES=..\source\win32_main.cpp

set GAME_COMPILER_FLAGS=-LDd
set GAME_LINKER_FLAGS=-DLL
set GAME_OUTPUT_FILE=
set GAME_SOURCE_FILES=..\..\main.cpp


if not exist build  mkdir build
pushd build

cl  %SHARED_COMPILER_FLAGS%  %GAME_COMPILER_FLAGS%   %GAME_SOURCE_FILES%   -link  %SHARED_LINKER_FLAGS%  %GAME_LINKER_FLAGS%
cl  %SHARED_COMPILER_FLAGS%  %WIN32_COMPILER_FLAGS%  %WIN32_SOURCE_FILES%  -link  %SHARED_LINKER_FLAGS%  %WIN32_LINKER_FLAGS%


popd