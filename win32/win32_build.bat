@echo off

set SHARED_COMPILER_FLAGS=/DUNICODE -MT -nologo -Gm- -GR- -EHa- -Od -Oi -WX -W4 /wd4100 /D_CRT_SECURE_NO_WARNINGS /I ..\..\
set SHARED_LINKER_FLAGS=""

set WIN32_PLATFORM_COMPILER_FLAGS=""
set WIN32_PLATFORM_LINKER_FLAGS=-incremental:no -opt:ref user32.lib gdi32.lib winmm.lib
set WIN32_PLATFORM_OUTPUT_FILE=""
set WIN32_PLATFORM_SOURCE_FILES=""

set GAME_COMPILER_FLAGS=""
set GAME_LINKER_FLAGS=""
set GAME_OUTPUT_FILE=""
set GAME_SOURCE_FILES=""


if not exist build  mkdir build
pushd build

REM cl /DUNICODE /I ..\..\ -Zi ..\source\win32_main.cpp user32.lib gdi32.lib

cl %SHARED_COMPILER_FLAGS% ..\..\main.cpp /link /DLL 
cl %SHARED_COMPILER_FLAGS% ..\source\win32_main.cpp /link %WIN32_PLATFORM_LINKER_FLAGS%


popd