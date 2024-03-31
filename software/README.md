# Software

The software currently consists of a common library of subroutines and an implementation of Tetris,
all written directly in Z80 assembly to make efficient use of the limited resources on the machine.
The common library includes routines for basic video handling (clearing the screen, drawing characters
and numbers), controller input, BCD arithmetic, and pseudorandom number generation.

## Assembling

The code is developed using the Pasmo Z80 assembler. The assembled binary image corresponds directly
to the memory map of the system, with the first 8 kilobytes mapped to ROM, and the next 8 kilobytes
mapped to RAM. The code can be built in two modes: ROM mode or RAM mode. In ROM mode, all of the
program code is assembled into the ROM section of the image, and the RAM section is left empty. The
first 8 kilobytes of the image can then be programmed into the EEPROM for standalone operation. To
assemble the code in ROM mode, do:
```
/usr/bin/pasmo --alocal main.asm image.bin
```

In RAM mode, most of the code is placed in the RAM section of the image. The ROM section contains only
the necessary reset and interrupt vectors, and a small bootloader that enables an external programmer
to modify and execute code in RAM by interfacing with the controller input ports. When using the
bootloader, the ROM section of the image need only be programmed once into the EEPROM. Development can
then proceed by using the external programmer to upload the code directly into RAM, without the need to
remove the EEPROM chip for reprogramming. To assemble the code in RAM mode, do:
```
/usr/bin/pasmo --alocal --equ USE_LOADER main.asm image.bin
```
