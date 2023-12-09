; Tell the assembler to start all memory calculations at 0x7C00
org 0x7C00

; 16 bit output from assembler
bits 16

%define ENDL 0x0D, 0x0A

start:
  jmp main

; ---------- print ----------
; Output character(s) to screen
; Input: ds:si

print:
  push si
  push ax

.loop:
  lodsb         ; Loads character
  or al, al     ; Is the character null?
  jz .endloop

  mov ah, 0x0e  ; Call bios interrupt
  mov bh, 0     ; Set page number to zero
  int 0x10

  jmp .loop

.endloop:
  pop ax
  pop si
  ret
; --------------------------

main:
  ; Set up data segments
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; Set up stack pointer and stack segment
  mov ss, ax
  mov sp, 0x7C00

  ; Print test message
  mov si, test_msg
  call print

  hlt
.halt:
  jmp .halt

test_msg: db 'Hello world!', ENDL, 0 

; Tell nasm to put 0xAA55 at the end of the file
; to indicate this is the boot sector
times 510-($-$$) db 0
dw 0AA55h
