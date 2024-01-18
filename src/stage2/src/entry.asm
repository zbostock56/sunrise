bits 16

section .entry

extern __bss_start
extern __end

extern start
global entry

%define ENDL 0x0D, 0x0A

entry:
    cli

    ; save boot drive
    mov [g_boot_drive], dl

    ; setup stack
    mov ax, ds
    mov ss, ax
    mov sp, 0xFFF0
    mov bp, sp

    ; switch to protected mode
    call EnableA20                     ; 2 - Enable A20 gate
    call LoadGDT                       ; 3 - Load GDT

    ; 4 - set protection enable flag in CR0
    mov eax, cr0 
    or al, 1
    mov cr0, eax

    ; 5 - far jump into protected mode
    jmp dword 08h:.pmode

.pmode:
    ; Now inside protected mode
    bits 32

    ; 6 - setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

    ; clear out bss
    mov edi, __bss_start
    mov ecx, __end
    sub ecx, edi
    mov al, 0
    cld
    rep stosb


    ; expect boot drive in dl, send as argument to cstart function
    xor edx, edx
    mov dl, [g_boot_drive]
    push edx
    ; jump to C
    call start

    ; Should never happen
    cli
    hlt

EnableA20:
    bits 16
    ; disable keyboard
    call A20WaitInput
    mov al, KbdControllerDisableKeyboard
    out KbdControllerCommandPort, al

    ; read control output port
    call A20WaitInput
    mov al, KbdControllerReadCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitOutput
    in al, KbdControllerDataPort
    push eax

    ; write control output port
    call A20WaitInput
    mov al, KbdControllerWriteCtrlOutputPort
    out KbdControllerCommandPort, al
    
    call A20WaitInput
    pop eax
    or al, 2                           ; bit 2 = A20 bit
    out KbdControllerDataPort, al

    ; Enable Keyboard
    call A20WaitInput
    mov al, KbdControllerEnableKeyboard
    out KbdControllerCommandPort, al
    
    call A20WaitInput
    ret

A20WaitInput:
    bits 16
    ; Wait until status of bit 2 (input buffer) is 0
    ; by reading from command port, we read status byte
    in al, KbdControllerCommandPort
    test al, 2
    jnz A20WaitInput
    ret

A20WaitOutput:
    bits 16
    ; Wait until status bit 1 (output buffer) is 1 so it can be read
    in al, KbdControllerCommandPort
    test al, 1
    jz A20WaitOutput
    ret

LoadGDT:
    bits 16
    lgdt [g_GDTDesc]
    ret

KbdControllerDataPort                  equ 0x60
KbdControllerCommandPort               equ 0x64
KbdControllerDisableKeyboard           equ 0xAD
KbdControllerEnableKeyboard            equ 0xAE
KbdControllerReadCtrlOutputPort        equ 0xD0
KbdControllerWriteCtrlOutputPort       equ 0xD1

ScreenBuffer                           equ 0xB8000

g_GDT:
    ; Null Descriptor
    dq 0

    ; 32-bit code segment
    dw 0FFFFh                          ; limit (bits 0-15) = 0xFFFFF fo full 32-bit range (disables segmentation)
    dw 0                               ; base (bits 0-15) = 0x0 (disables segmentation)
    db 0                               ; base (bits 16-32) = 0x0 (disables segementation)
    db 10011010b                       ; access (present, ring0, code segment, executable, direction = 0, readable)
    db 11001111b                       ; granularity (4k pages, 32-bit protected mode) + limit (bits 16-19)
    db 0                               ; base high

    ; 32-bit data segment
    dw 0FFFFh                          ; limit (bits 0-15) = 0xFFFFF fo full 32-bit range (disables segmentation)
    dw 0                               ; base (bits 0-15) = 0x0 (disables segmentation)
    db 0                               ; base (bits 16-32) = 0x0 (disables segementation)
    db 10010010b                       ; access (present, ring0, data segment, executable, direction = 0, writable)
    db 11001111b                       ; granularity (4k pages, 32-bit protected mode) + limit (bits 16-19)
    db 0                               ; base high

    ; 16-bit code segment
    dw 0FFFFh                          ; limit (bits 0-15) = 0xFFFFF
    dw 0                               ; base (bits 0-15) = 0x0
    db 0                               ; base (bits 16-32) = 0x0
    db 10011010b                       ; access (present, ring0, code segment, executable, direction = 0, readable)
    db 00001111b                       ; granularity (1b pages, 16-bit protected mode) + limit (bits 16-19)
    db 0                               ; base high

    ; 16-bit data segment
    dw 0FFFFh                          ; limit (bits 0-15) = 0xFFFFF
    dw 0                               ; base (bits 0-15) = 0x0
    db 0                               ; base (bits 16-32) = 0x0
    db 10010010b                       ; access (present, ring0, data segment, executable, direction = 0, writable)
    db 00001111b                       ; granularity (1b pages, 16-bit protected mode) + limit (bits 16-19)
    db 0                               ; base high

g_GDTDesc: dw g_GDTDesc - g_GDT - 1    ; limit = size of GDT
           dd g_GDT                    ; address of GDT

g_boot_drive: db 0

;
; Helper Routines
;

; ---------- print ----------
; Output character(s) to screen
; Input: ds:si

print:
  ;bits 32
  ;x86_enter_real_mode
  bits 16
  push si
  push ax
  push bx

.loop:
  lodsb         ; Loads character
  or al, al     ; Is the character null?
  jz .endloop

  mov ah, 0x0e  ; Call bios interrupt
  mov bh, 0     ; Set page number to zero
  int 0x10

  jmp .loop

.endloop:
  pop bx
  pop ax
  pop si
  
  ;x86_enter_protected_mode
  ;bits 32
  ret
; --------------------------

hit_msg:        db 'Hit!', ENDL, 0
