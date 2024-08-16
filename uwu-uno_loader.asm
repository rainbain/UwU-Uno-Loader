; MIT License
; 
; Copyright (c) 2024 Sam F.
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

;
; The UwU-Uno Bootloader by rainbain (Sam F.)
; Arduino IDE compatable bootloader that converts text to "uwu" speak.
;

; 512 bytes before the end of flash
.org 0x3F00

ENTRY:
    in r16, 0x34 ; Get reset cause, and clear it
    ldi r17, 0
    out 0x34, r17
    sbrs r16, 3
    rjmp START

    ; Start Arduino Script

    ; Turn off watchdog
    ldi r17, 0
    rcall SET_WATCHDOG

    ; Use the flash wrap around to jump to zero.
    rjmp FLASH_END


    ; Start of the bootloader itself
START:
    ; Enable Watchdog
    ldi r17, 0b00001110
    rcall SET_WATCHDOG

    ; UART Clock Divider
    ldi r16, 0x08
    sts 0xc4, r16
    ldi r16, 0b00000110
    sts 0xc2, r16

    ; UART enable
    ldi r16, 0b00011000
    sts 0xc1, r16
LOOP:
    wdr ; Reset watchdog
    rcall UART_GET

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

    ; Load An Address To Use
STK_LOAD_ADDRESS:
    rcall UART_GET
    mov r2, r17
    rcall UART_GET
    mov r3, r17

    ; Address is in words
    lsl r2
    rol r3

    rjmp STK_GENERIC
    

    ; Programs a 256 byte page
STK_PROG_PAGE:
    ; Load size -_-
    rcall UART_GET
    rcall UART_GET
    mov r25, r17
    rcall UART_GET ; Memory type skipped

    clr r28
    ldi r29, 0x01

    ;
    ; Base UWU State
    ;
    rcall UWU_LOAD_STATE

STK_PROG_PAGE_LOOP:
    ; Value to save to page
    rcall UART_GET

    ; Copy it to RAM so we have a buffer to modify
    st Y+, r17

    ;
    ; START OF UWU CODE
    ;

    ;
    ; Make it lower case, or invalidate if not ascii
    ;
    cpi r17, 123
    brge UWU_INVALIDATE
    cpi r17, 65
    brlt UWU_INVALIDATE

    cpi r17, 91
    brge UWU_LOWER_CASE_SKIP
    ; Second case handled by invalidation

    subi r17, -32
UWU_LOWER_CASE_SKIP:
    ; CRC16 Accumulate
    inc r4
    eor r18, r17
    clr r0
UWU_CRC_LOOP:
    sbrs r18, 0
    rjmp UWU_CRC_EOR_ELSE
    lsr r19
    ror r18
    eor r18, r20
    eor r19, r21
    rjmp UWU_CRC_EOR_SKIP
UWU_CRC_EOR_ELSE:
    lsr r19
    ror r18
UWU_CRC_EOR_SKIP:
    inc r0
    sbrs r0, 3 ; On = 8
    rjmp UWU_CRC_LOOP

    rjmp UWU_SKIP_INVALIDATE

UWU_INVALIDATE:
    ;
    ; On Invalidate, Check Table for entry
    ;
    ldi r31, 0x7F
    ldi r30, ((UWU_KEY_WORDS << 1) & 0xFF)
UWU_KEY_TABLE_LOOP:
    lpm r16, Z+
    lpm r17, Z+
    lpm r7, Z+
    lpm r8, Z+

    ; Exit loop if we see 255
    cpi r16, 0xFF
    breq UUW_INVALIDATE_EXIT

    cp r18, r16
    brne UWU_KEY_TABLE_LOOP
    cp r19, r17
    brne UWU_KEY_TABLE_LOOP
    cp r7, r4
    brne UWU_KEY_TABLE_LOOP

    ;
    ; We have a match!
    ;

    ; Load address of the translation
UWU_TRANSLATION_LOOP:
    mov r30, r8
    push r28 ; We will offset this, save it
    ; Load translation Offset
    lpm r16, Z+
    mov r30, r16
    mov r17, r16
    andi r16, 0b1111 ; Get offset
    sub r28, r16

    ; Load translation letter (iterate too)
    swap r30 ; Swaps the nibbles
    andi r30, 0b0111
    ori r30, 0b11110000

    ; Load our new letter, store it
    lpm r16, Z
    st Y, r16

    ; Recover our memory read head
    pop r28

    ; Next
    inc r8

    ; Was this the last translation?
    sbrs r17, 7
    rjmp UWU_TRANSLATION_LOOP


UUW_INVALIDATE_EXIT:
    rcall UWU_LOAD_STATE
UWU_SKIP_INVALIDATE:


    dec r25 ; We can just subtract the size. We will assume 256 bytes later.
    cpi r25, 0
    brne STK_PROG_PAGE_LOOP
STK_PROG_PAGE_EXIT:
    ; Commit RAM to internal flash buffer
    clr r30
    ldi r31, 0x01
    ldi r17, 0b00000001
STK_PROG_PAGE_COMMIT_LOOP:

    ld r0, Z
    ldd r1, Z+1

    rcall DO_SPM
    adiw r30, 2

    cpi r30, 0x80
    brne STK_PROG_PAGE_COMMIT_LOOP

    mov r30, r2
    mov r31, r3

    ; Erase page and write
    ldi r17, 0b00000011
    rcall DO_SPM_AWAIT
    ldi r17, 0b00000101
    rcall DO_SPM_AWAIT

    ; Were done here
    rjmp STK_GENERIC


    ; Read the Signature of the MCU
STK_READ_SIGN:
    rcall UART_GET
    ldi r17, 0x14
    rcall UART_SEND
    ldi r17, 0x1E
    rcall UART_SEND
    ldi r17, 0x95
    rcall UART_SEND
    ldi r17, 0x0F
    rcall UART_SEND
    rjmp STK_GENERIC_OK

    ; Get some parameter
STK_PARAMETER:
    rcall UART_GET
    rcall UART_GET
    ldi r17, 0x14
    rcall UART_SEND
    ldi r17, 0xB0
    rcall UART_SEND

    rjmp STK_GENERIC_OK

STK_LEAVE_PROGMODE:
    ; Make watchdog expire fast, 16ms
    ldi r17, 0b00001000
    rcall SET_WATCHDOG

    ; Go ahead and just go over to the generic code


STK_GENERIC:
    ; Read till we see sync
    rcall UART_GET
    cpi r17, 0x20
    brne STK_GENERIC

    ; Sync, OK
    ldi r17, 0x14
    rcall UART_SEND
STK_GENERIC_OK:
    ldi r17, 0x10
    rcall UART_SEND

    rjmp LOOP


; Sets the value in r17 to the watchdog
; Curropts the value in r16
SET_WATCHDOG:
    ldi r16, 0b00011000
    sts 0x60, r16
    sts 0x60, r17
    ret

; Writes the value in r17 as a SPM operation
DO_SPM_AWAIT:
    in r16, 0x37
    sbrc r16, 0
    rjmp DO_SPM_AWAIT
DO_SPM:
    out 0x37, r17
    spm
    ret

; Trasmitts the value in r17
; Curropts the value in r16
UART_SEND:
    lds r16, 0xc0
    sbrs r16, 5
    rjmp UART_SEND
    sts 0xc6, r17
    ret

; Recives the value in r17
; Curropts the value in r16
UART_GET:
    lds r16, 0xc0
    sbrs r16, 7
    rjmp UART_GET
    lds r17, 0xc6
    ret

; Sets up the state machine to a base state
UWU_LOAD_STATE:
    ldi r18, 0xFF ; CRC16 Checksum
    ldi r19, 0xFF 
    ldi r20, 0x01 ; 16 bit EOR value
    ldi r21, 0xA0
    clr r4
    ret

UWU_KEY_WORDS:
        .db 246, 52, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 0
        .db 155, 102, 3, ((UWU_TRANSLATIONS << 1)&0xFF) + 2
        .db 114, 100, 6, ((UWU_TRANSLATIONS << 1)&0xFF) + 5
        .db 7, 246, 6, ((UWU_TRANSLATIONS << 1)&0xFF) + 7
        .db 49, 176, 11, ((UWU_TRANSLATIONS << 1)&0xFF) + 11
        .db 53, 164, 7, ((UWU_TRANSLATIONS << 1)&0xFF) + 13
        .db 126, 190, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 15
        .db 10, 121, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 18
        .db 122, 242, 7, ((UWU_TRANSLATIONS << 1)&0xFF) + 19
        .db 121, 18, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 20
        .db 65, 239, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 21
        .db 1, 125, 4, ((UWU_TRANSLATIONS << 1)&0xFF) + 22
        .db 79, 98, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 23
        .db 118, 174, 4, ((UWU_TRANSLATIONS << 1)&0xFF) + 24
        .db 79, 207, 9, ((UWU_TRANSLATIONS << 1)&0xFF) + 25
        .db 88, 105, 5, ((UWU_TRANSLATIONS << 1)&0xFF) + 26
        .db 255, 255
UWU_TRANSLATIONS:
        .db 4, 131, 20, 3, 146, 6, 149, 6, 37, 52, 195, 8, 135, 8, 134, 21, 4, 146, 133, 136, 134, 149, 133, 131, 131, 136, 132
        
; uwu letter table and 8 byte long jump table at the end of flash
.org 0x3FF8
UWU_LETTER_TABLE:
        .db 119, 117, 101, 110, 115, 0, 0, 0
CMD_JUMP_TABLE:
    .db (STK_READ_SIGN & 0xFF), (STK_PARAMETER & 0xFF)
    .db (STK_GENERIC & 0xFF), (STK_LOAD_ADDRESS & 0xFF)
    .db (STK_PROG_PAGE & 0xFF), (STK_GENERIC & 0xFF)
    .db (STK_GENERIC & 0xFF), (STK_LEAVE_PROGMODE & 0xFF)
FLASH_END: