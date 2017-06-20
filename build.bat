@echo off

echo Deleting old kernel
del kernel.os

echo Deleting *.bak
del *.bak

echo Building Kernel...
"C:\Program Files (x86)\nasm\nasm" kernel.asm -O0 -t -f bin -o kernel.os

rem copy kernel.os a:\ 

echo Done
pause
