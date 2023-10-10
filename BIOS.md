## Intro
Back in the days I was lucky enough to buy one of these together with expansion bay. Plugged it a few times, tinkered with SNES emulation, tried with nVidia Quadro NVS 280, expanded memory to 1GB did some other stuff and put it in the closet for years. Recently I've given it a second chance by fitting 2.5" HDD inside and SoundBlaster PCI card. It's nice Windows 98SE / XP box. The only drawback is BIOS. For some reason HP severly limited available options.

## Challenge
Enable options responsible for `VGA Share Memory Size` and `IRQ Resources` at least, anything useful at most.

## Tools of trade
- AWDFLASH v8.83 (DOS)
- BIOS Patcher v4.23 (DOS)
- CBROM V2.07 (DOS)
- LHA v2.55 (DOS)
- CBROM v1.98 (Windows)
- Award BIOS Editor (Windows)
- Hex Editor
- C/C++ environment

## BIOS Structure
We deal with `Phoenix AwardBIOS v6.00PG` - 4Mbit image.
```
CBROM V2.07 (C)Award Software 2000 All Rights Reserved.

              ******** 240HV112.BIN BIOS component ********

 No. Item-Name         Original-Size   Compressed-Size Original-File-Name 
================================================================================
  0. System BIOS       20000h(128.00K)12B63h(74.85K)240hv112.BIN
  1. XGROUP CODE       0D200h(52.50K)089EDh(34.48K)awardext.rom
  2. ACPI table        0359Eh(13.40K)01510h(5.27K)ACPITBL.BIN
  3. YGROUP ROM        09DB0h(39.42K)04A23h(18.53K)awardeyt.rom
  4. GROUP ROM[ 0]     04820h(18.03K)02020h(8.03K)_EN_CODE.BIN
  5. LOGO BitMap       2443Ch(145.06K)00994h(2.39K)hp75.bmp
  6. VGA ROM[1]        08000h(32.00K)042F6h(16.74K)VGA23600.ROM
  7. PCI driver[A]     0A800h(42.00K)062F2h(24.74K)PXEB.LOM
  8. OEM0 CODE         00D0Fh(3.26K)0087Ch(2.12K)int15_32.bin
  9. Other(4045:0000)  007DAh(1.96K)00801h(2.00K)rom32.bin

  Total compress code space  = 4D000h(308.00K)
  Total compressed code size = 2F49Ch(189.15K)
  Remain compress code space = 1DB64h(118.85K)

 ****** On Board VGA ROM In BootBlock ******

                          ** Micro Code Information **
Update ID  CPUID  |  Update ID  CPUID  |  Update ID  CPUID  |  Update ID  CPUID
------------------+--------------------+--------------------+-------------------
```
 Main BIOS module aka `240hv112.BIN` is located at `0x20000`. It's compressed [LHA](https://github.com/jca02266/lha/blob/master/header.doc.md) archive followed by other modules that are easily spotted (try searching for `-lh5-` and `-lh0-` tags). Non relocateable parts are at `0x6D000` - this is something related to decompression, on board VGA ROM and fonts. There's a boot block at `0x7E000`.

## Tinkering
Main BIOS module can be easily extracted with 7-Zip while opening BIOS file as archive. As for modules, use CBROM for Windows to extract (literally!) all except `rom32.bin`. This one should be extracted with DOS version to get vaild file. Here's batch file:
```
@ECHO OFF
SET file=240HV112.BIN
CBROM.EXE %file% /XGROUP Extract
CBROM.EXE %file% /ACPI Extract
CBROM.EXE %file% /YGROUP Extract
CBROM.EXE %file% /GROUP Extract
CBROM.EXE %file% /LOGO Extract
CBROM.EXE %file% /VGA Extract
CBROM.EXE %file% /PCI Extract
CBROM.EXE %file% /OEM0 Extract
CBROM.EXE %file% /other 4045:0 Extract /ERR
```
This can also be achieved with hex editor if you prefer the hard way.

While CBROM (Windows) handles decompression/compression and inserting of the modules you're on your own when it comes to main module - `240hv112.BIN`. In the next step we'll remove all modules from the BIOS file. Here's batch file:
```
@ECHO OFF
SET file=240HV112.BIN
CBROM.EXE %file% /NoCompress Release
CBROM.EXE %file% /OEM0 Release
CBROM.EXE %file% /PCI Release
CBROM.EXE %file% /VGA Release
CBROM.EXE %file% /LOGO Release
CBROM.EXE %file% /GROUP Release
CBROM.EXE %file% /YGROUP Release
CBROM.EXE %file% /ACPI Release
CBROM.EXE %file% /XGROUP Release
CBROM.EXE %file% /D
```
Such file will serve as a base for further modifications. After applying changes to main module it needs to be compressed with LHA v2.55 for DOS, which creates 1:1 archive. [Header fields](https://github.com/jca02266/lha/blob/master/header.doc.md) responsible for `time` and `date` are used as `segment:offset` pair so they need to be restored. For sake of completeness you might also want to restore OS ID field and then recalculate header checksum to end up with valid archive. Such file can be inserted back at `0x20000`. Make sure ther're no leftovers of previous version. Then we reconstruct BIOS image:
```
@ECHO OFF
SET file=240HV112.BIN
CBROM.EXE %file% /XGROUP awardext.rom
CBROM.EXE %file% /ACPI ACPITBL.BIN
CBROM.EXE %file% /YGROUP awardeyt.rom
CBROM.EXE %file% /GROUP _EN_CODE.BIN
CBROM.EXE %file% /LOGO hp75.bmp
CBROM.EXE %file% /VGA VGA23600.ROM
CBROM.EXE %file% /PCI PXEB.LOM
CBROM.EXE %file% /OEM0 int15_32.bin
CBROM.EXE %file% /NoCompress rom32.bin
CBROM.EXE %file% /D
```
Output should be valid and accepted by `AWDFLASH`. While flashing I used original parameters `awdflash.exe 240HV112.bin /py /sn /cp /sb` that prevent overwriting boot block - some sort of security measure I guess.

## Findings
- `_EN_CODE.BIN` contains all the options and descriptions visible in BIOS menu and more. There're some control codes like moving cursor, jumping to other string, etc. but nothing to enable / disable menu entries. The most important thing is its structure. There's main array of pointers to sub arrays that contain pointers to mentioned strings. To refer to a string you need two, byte sized, indexes that are stored as a word.

- `240hv112.BIN` unsurprisingly contains a lot of interesting stuff.