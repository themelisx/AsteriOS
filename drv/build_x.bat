@echo off
echo Deleting *.bak
del *.bak

echo Deleting old files
del winmgr.os

echo Building...

echo winmgr.asm
"C:\Program Files (x86)\nasm\nasm" winmgr.asm -t -f bin -o winmgr.os

echo Done
pause
