@echo off
echo Deleting *.bak
del *.bak

echo Deleting old files
del *.exe

echo Building...

"C:\Program Files (x86)\nasm\nasm" memtest.asm -t -f bin -o memtest.exe
rem "C:\Program Files (x86)\nasm\nasm" ata.asm -t -f bin -o ata.exe

echo Coping to a:\
rem copy *.exe a:\

echo Done
pause
