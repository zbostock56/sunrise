; Tell the assembler to start all memory calculations at 0x7C00
org 0x7C00

; 16 bit output from assembler
bits 16

%define ENDL 0x0D, 0x0A

;
; ---------- FAT12 Headers ----------
;
jmp short start 
nop

; BIOS Parameter Block
bpb_oem:                      db 'MSWIN4.1'
bpb_bytes_per_sector:         dw 512
bpb_sectors_per_cluster:      db 1
bpb_reserved_sectors:         dw 1
bpb_fat_count:                db 2
bpb_dir_entries_count:        dw 0E0h
bpb_total_sectors:            dw 2880  ; 2880 * 512 = 1.44 MB
bpb_media_descriptor:         db 0F0h  ; 0xF0 = 3.5" floppy
bpb_sectors_per_fat:          dw 9
bpb_sectors_per_track:        dw 18
bpb_heads:                    dw 2
bpb_hidden_sectors:           dd 0
bpb_large_sector_count:       dd 0

; Extended Boot Record
ebr_drive_number:             db 0
db 0                                             ; Implicitly reserved byte
ebr_signiture:                db 28h             ; Serial number, value doesn't matter
ebr_volume_id:                db 01h, 02h, 03h, 04h
ebr_volume_label:             db 'sunrise_bl '   ; Must be 11 bytes
ebr_system_id:                db 'FAT12   '      ; Must be 8 bytes 
; ------------------------------


;
; Entry point from BIOS
;
start:
  jmp main

;
; Helper Routines
;

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

;
; Disk I/O Routines
;

; ---------- lba_to_chs ----------
; Output: 
;   - cx [bits 0 - 5]: sector number
;   - cx [bits 6 - 15]: cylinder
;   - dh: head
; Input: 
;   - LBA address (ax) 
; Desc:
;   Sector = (LBA % sectors_per_track) + 1
;   Head = (LBA / sectors_per_track) % heads
;   cylinder = (LBA / sectors_per_track) / heads

lba_to_chs:
  push ax
  push dx

  xor dx, dx                        ; Set dx to zero
  div word [bpb_sectors_per_track]  ; ax = LBA / sectors_per_track
                                    ; dx = remainer of division

  inc dx                            ; Perform increment as described in desc
  mov cx, dx

  xor dx, dx                        ; Set dx to zero
  div word [bpb_heads]              ; ax = (LBA / sectors_per_track) / heads = cylinder
                                    ; dx = (LBA / sectors_per_track) % heads = head
  mov dh, dl                        ; move lower bits of ax (signified by dl)
  mov ch, al                        ; ch = cylinder (lower 8 bits)
                                    ; Next three operations set bits as described in desc
  shl ah, 6
  or cl, ah

  pop ax
  mov dl, al                        ; Restore dl
  pop ax
  ret
; --------------------------------

; ---------- disk_read ----------
; Input:
;   - ax: LBA address
;   - cl: Number of sectors to read (up to 128)
;   - dl: Drive number
;   - es:bx: Location to store the data read

disk_read:
  push ax
  push bx
  push cx
  push dx
  push di

  push cx                      ; Temporarily save cl (number of sectors to read)
  call lba_to_chs
  pop ax                       ; al = number of sectors to read

  mov ah, 02h
  mov di, 3                    ; Retry count (floppies are unreliable)

.loop:
  pusha                        ; Not sure what registers BIOS interrupt will use
  stc                          ; Set carry flag (some BIOS's don't do it)
  int 13h 
  jnc .success                 ; If carry flag is cleared, operation successful
  popa 
  call disk_reset              ; Reset the floppy controller
  dec di 
  test di, di                  ; Test loop condition
  jnz .loop

.fail:
  ; All booting attempts failed
  jmp floppy_error

.success:
  popa
  pop di
  pop dx
  pop cx
  pop bx
  pop ax
  ret
; -------------------------------

; ---------- disk_reset -----------
; Input:
;   - dl: drive_number
disk_reset: 
  pusha
  mov ah, 0
  stc
  int 13h
  jc floppy_error
  popa
  ret

; --------------------------------


;
; Error Handlers
;
floppy_error:
  mov si, read_failed_msg
  call print
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0
  int 16h                     ; Await keypress
  jmp 0FFFFh:0                ; Jump to beginning of bios (should reboot system)


;
; Main function
;
main:
  ; Set up data segments
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; Set up stack pointer and stack segment
  mov ss, ax
  mov sp, 0x7C00

  ; Test read from floppy
  mov [ebr_drive_number], dl

  mov ax, 1
  mov cl, 1
  mov bx, 0x7E00
  call disk_read

  ; Print test message
  mov si, welcome_msg
  call print

  cli
  hlt


welcome_msg: db 'Welcome to sunrise bootloader!', ENDL, 0 
read_failed_msg: db 'Floppy read error!', ENDL, 0

; Tell nasm to put 0xAA55 at the end of the file
; to indicate this is the boot sector
times 510-($-$$) db 0
dw 0AA55h
