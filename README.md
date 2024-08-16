# UwU-Uno Loader
UwU-Uno loader is a bootloader for the Arduino Uno, or any others utilizing the ATMEGA328P MCU.

It is part of a 2 lay long project, to use a dictionary in order to modify key words found within the Arduino sketch to "UwU speak."

This bootloader fits within the same 512 bytes as other similar bootloader, but has many removed functions to fit within the small space. The bootloader is only directly comparable with Arduino IDE's implementation of AVR Dude.

Both UwU-Uno and its core bootloader are not supposed to be used outside of a hobbyist  implementation, and should not be used in serious applications or production environments. 512 bytes is plenty small for modern implementations, and there a stable and proven bootloader should be used.

## The Bootloader Itself
The bootloader by itself, kept in `base_bootloader.md`, assembles to 236 bytes. It can be made smaller, but provides a foundation where plenty of space is provided to fit extended functionality into the bootloader.

There are many small assembly optimizations, but also many differences in how commands are used or processed.

### STK500 Optimizations
This bootloader only uses a small subset of the STK500 commands. Of these, many are treated as "generic." Here the bootloader reads up to the 0x20 sync byte in order to provide a way to still process commands we need to implement,  but do not care to process.

Implemented Commands:
 1. STK_LOAD_ADDRESS
 2. STK_PROG_PAGE
 3. STK_READ_SIGN
 4. STK_LEAVE_PROGMODE

Generic Commands:
 1. STK_SYNC
 2. STK_PARAMETER
 3. STK_SET_DEVICE
 4. STK_EXT_PARAMS
 5. SCK_PROG_ENABLE
### Jump Table Optimizations
It permutes used STK500 commands such that the 3 least significant bits are unique. This allows for the commands to be used to address a jump table.

Since the entire bootloader is in the last 256 words of flash, each entry only needs to be 1 byte long. Placing the table at the end of flash makes it so only a simple or operation is needed to address it.

```
	; Encode Command To Jump Table (additions generated with python script)
	mov r30, r17
	sbrc r30, 4
	adiw r30, 14
	sbrc r30, 7
	adiw r30, 5
	ori r30, 0b11111000

	; Load value from the jump table, jump to it
	ldi r31, 0x7F
	lpm r30, Z
  
	ijmp
```

The operations needed to do the permutation is generated using a quick python script.

## UwU-Uno
UwU-Uno supports up to 16 keywords, and up to 8 unique letters it can use to replace with. A table of key words, each entry being 4 bytes, is used to location the translation.

At the end of flash, before the jump table, is a list of up to 8 ASCII characters that will be used to replace other letters with. A simple logic or can also be used to address it.

The first 2 bytes, are a CRC16 checksum of the word we are trying to find, while the next 2 are the number of letters in the word, and location of the translation within the last 256 are of flash respectively.

A translation consist of a string of bytes. The least significant nibble is the number of bytes back from the terminator that the replacement occurs. The second's 3 least significant bits are the index of the letter to replace. The most significant bit is a terminator, and shows the end of the translation.

These tables are produced using a python script as well.

Currently supported Translations:
```
Hello       => Hewwo
LED         => UwU
Button      => Bwuton
Sensor      => Swensr
Temperature => Tempwwature
Voltage     => Wowtage
Error       => Euwou
Press       => Pwess
Release     => Welease
Motor       => Wotor
World       => Wurld
Loop        => Woop
Start       => Stawt
Stop        => Stwp
Connected   => Cownected
Setup       => Sewup
```

## Possible Issues
### Page Boundaries
Key words that occur across the flash's page boundaries, will not be effected. Since the translations are processed one page at a time in a temporary buffer in RAM, there is no logic for if it takes place across them.

### Key World Detection Failures
A CRC16 checksum and key word length are compared in order to detect key works. It is possible this can have a false positive and effect something that is not a string causing glitchy behavior. Its best not to use this bootloader on anything mission critical.

### Page Overrun
After copying the page, of a specified bytes, to the internal buffer in RAM, this buffer is copied to the MCU's internal flash buffer. If the program's size is not exactly a multiple of the page size, instead of it being padded with 0xFF, the data within the previous page will be inserted at the end of the program.

### Unimplemented STK500 commands.
Unimplemented STK500 commands are not often ignored, but if fully unimplemented, will have undefined behavior due to how the jump table is compressed.

This will make AVR Dude very unhappy.

### General Fears of String Replacement
Modifying strings somewhat randomly within an Arduino sketch is not safe. These strings may hold important data, IDs that must match (especially those with outside systems), and so on.

This bootloader will likely work most of the time, but its not something that should be used on any micro controller that serves a critical role.