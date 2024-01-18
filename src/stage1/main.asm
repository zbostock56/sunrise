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
                              db 0               ; Implicitly reserved byte
ebr_signiture:                db 29h             ; Serial number, value doesn't matter
ebr_volume_id:                db 01h, 02h, 03h, 04h
ebr_volume_label:             db 'sunrise_bl '   ; Must be 11 bytes
ebr_system_id:                db 'FAT12   '      ; Must be 8 bytes 
; ------------------------------


;
; Entry point from BIOS
;
start:
  ; Set up data segments
  mov ax, 0
  mov ds, ax
  mov es, ax

  ; Set up stack pointer and stack segment
  mov ss, ax
  mov sp, 0x7C00

  ; Fixing the oddities with some BIOSes loading
  ; 07C0:0000 instead of 0000:7C00
  push es
  push word .after
  retf

.after:
  ; Read drive information (sectors per track and head count)
  ; from BIOS rather than relying on potentially corrupted
  ; disk image
  mov [ebr_drive_number], dl

  push es
  mov ah, 08h
  int 13h
  jc floppy_error
  pop es

  and cl, 0x3F                                   ; Remove top two bits
  xor ch, ch
  mov [bpb_sectors_per_track], cx                ; Sector count

  inc dh
  mov [bpb_heads], dh                            ; Head count

  ; Read FAT root directory
  ; LBA Root directory location (in LBA) = reserved + fats * sectors_per_fat
  mov ax, [bpb_sectors_per_fat]
  mov bl, [bpb_fat_count]
  xor bh, bh
  mul bx                                        ; ax = (fats * sectors_per_fat)
  add ax, [bpb_reserved_sectors]                ; ax = LBA of root directory
  push ax

  ; Size of root directory = (32 * number_of_entries) / bytes_per_sector
  mov ax, [bpb_dir_entries_count]
  shl ax, 5                                     ; ax *= 32
  xor dx, dx                                    ; dx = 0
  div word [bpb_bytes_per_sector]               ; number of sectors to be read

  test dx, dx                                   ; if (dx != 0) => Add 1
  jz .root_dir
  inc ax                                        ; in this case, the final sector is only partially
                                                ; filled with entries, to mitigate this, add one
                                                ; to the number of sectors to read in order to get
                                                ; all data and not overwrite things in memory

.root_dir:
  mov cl, al                                    ; cl = number of sectors to read = size of root dir
  pop ax                                        ; ax = LBA of root dir
  mov dl, [ebr_drive_number]                    ; dl = drive number (already saved from earlier)
  mov bx, buffer                                ; es:bx = buffer
  call disk_read

  ; Find stage2.bin
  xor bx, bx                                    ; Holds how many entries have been searched
  mov di, buffer                                ; File name is first field in structure, therefore
                                                ; di = file name

.search_stage2:
  mov si, stage2_bin_fn
  mov cx, 11
  push di
  repe cmpsb
  pop di
  je .found_stage2

  add di, 32
  inc bx
  cmp bx, [bpb_dir_entries_count]
  jl .search_stage2

  ; stage2 binary was not found
  jmp stage2_not_found

.found_stage2:
  ; di should still point to directory entry structure
  mov ax, [di + 26]                             ; Lower first cluster field has offset 26
  mov [stage2_cluster], ax

  ; load FAT (file allocation table) from disk into memory
  mov ax, [bpb_reserved_sectors]
  mov bx, buffer
  mov cl, [bpb_sectors_per_fat]
  mov dl, [ebr_drive_number]
  call disk_read

  ; read the stage2 binary and process FAT chain
  mov bx, STAGE2_LOAD_SEGMENT
  mov es, bx
  mov bx, STAGE2_LOAD_OFFSET

.load_stage2_loop:
  ; Read next cluster
  mov ax, [stage2_cluster]
  add ax, 31

  mov cl, 1
  mov dl, [ebr_drive_number]
  call disk_read

  add bx, [bpb_bytes_per_sector]

  ; Compute location of next cluster
  mov ax, [stage2_cluster]
  mov cx, 3
  mul cx
  mov cx, 2
  div cx                                         ; ax = index entry in FAT, dx = cluster mod 2

  mov si, buffer
  add si, ax
  mov ax, [ds:si]                                ; read entry from FAT table at index ax

  or dx, dx
  jz .even

.odd:
  shr ax, 4
  jmp .next_cluster_after

.even:
  and ax, 0x0FFF

.next_cluster_after:
  cmp ax, 0x0FF8
  jae .read_finish

  mov [stage2_cluster], ax
  jmp .load_stage2_loop

.read_finish:
  ; jump to stage2 bootloader
  mov dl, [ebr_drive_number]                     ; boot device in dl

  mov ax, STAGE2_LOAD_SEGMENT                    ; set segment registers
  mov ds, ax
  mov es, ax

  ; far jump to stage2 bootloader
  jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

  jmp wait_key_and_reboot                        ; should never happen
  cli
  hlt
;
; ---- END START FUNCTION ----
;


;
; Helper Routines
;

; ---------- print ----------
; Output character(s) to screen
; Input: ds:si

print:
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

stage2_not_found:
  mov si, stage2_not_found_msg
  call print
  jmp wait_key_and_reboot

halt:
  mov si, halting_msg
  call print
  cli
  hlt

; Message String Constants
read_failed_msg:             db 'Floppy read error!', ENDL, 0
stage2_not_found_msg:        db 'STAGE2.BIN not found!', ENDL, 0
halting_msg:                 db 'Halting...', ENDL, 0

; General Constants
stage2_bin_fn:               db 'STAGE2  BIN'
stage2_cluster:              dw 0

; equ = no memory will be allocated for the constant
; Same as preprocessor define in C
STAGE2_LOAD_SEGMENT          equ 0x0
STAGE2_LOAD_OFFSET           equ 0x500

; Tell nasm to put 0xAA55 at the end of the file
; to indicate this is the boot sector
times 510-($-$$) db 0
dw 0AA55h


buffer: