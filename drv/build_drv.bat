@echo off
echo Deleting *.bak
del *.bak

echo Deleting old files
del *.drv
del *.os

echo Building drivers...

echo keyboard.asm -> keyboard.drv
"C:\Program Files (x86)\nasm\nasm" keyboard.asm -t -f bin -o keyboard.drv

echo cmd.asm -> cmd.os
"C:\Program Files (x86)\nasm\nasm" cmd.asm -t -f bin -o cmd.os

echo drvata.asm -> ata.drv
"C:\Program Files (x86)\nasm\nasm" drvata.asm -t -f bin -o ata.drv

echo Coping to a:\
rem copy *.drv a:\
rem copy *.os a:\

echo Done
pause
