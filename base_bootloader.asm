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
; The UwU-Uno Bootloader Base by rainbain (Sam F.)
; A very small and simple STK500 bootloader compatable with Arduino IDE.
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
    mov r28, r17
    rcall UART_GET
    mov r29, r17

    ; Address is in words
    lsl r28
    rol r29

    rjmp STK_GENERIC
    

    ; Programs a 256 byte page
STK_PROG_PAGE:
    ; Load size -_-
    rcall UART_GET
    mov r27, r17
    rcall UART_GET
    mov r26, r17
    rcall UART_GET ; Memory type skipped

    mov r30, r28
    mov r31, r29
STK_PROG_PAGE_LOOP:
    ; Value to save to page
    rcall UART_GET
    mov r0, r17
    rcall UART_GET
    mov r1, r17

    ; Write SPM tmp page
    ldi r17, 0b00000001
    rcall DO_SPM

    ; Iterate
    adiw r30, 2
    sbiw r26, 2


    ; Only comparing the lower half, as the highest value at this point is 0x00FF
    cpi r26, 0
    brne STK_PROG_PAGE_LOOP
STK_PROG_PAGE_EXIT:
    ; Erase page and write
    mov r30, r28
    mov r31, r29
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

; 8 byte long jump table at the end of flash
.org 0x3FFC
CMD_JUMP_TABLE:
    .db (STK_READ_SIGN & 0xFF), (STK_PARAMETER & 0xFF)
    .db (STK_GENERIC & 0xFF), (STK_LOAD_ADDRESS & 0xFF)
    .db (STK_PROG_PAGE & 0xFF), (STK_GENERIC & 0xFF)
    .db (STK_GENERIC & 0xFF), (STK_LEAVE_PROGMODE & 0xFF)
FLASH_END: