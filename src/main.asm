; Tell the assembler to start all memory calculations at 0x7C00
org 0x7C00

; 16 bit output from assembler
bits 16

main:
  hlt
.halt:
  jmp .halt

; Tell nasm to put 0xAA55 at the end of the file
times 510-($-$$) db 0
dw 0AA55h
