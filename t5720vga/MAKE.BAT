@echo off
cls
if exist t5720vga.com del t5720vga.com

tasm t5720vga.asm
if errorlevel 1 goto 1

tlink /t t5720vga.obj
if errorlevel 1 goto 2
del t5720vga.obj
del t5720vga.map

@echo Success!  
goto end

:1
@echo An assemble error has occurred.  
goto end

:2
@echo A link error has occurred.  
goto end

:end