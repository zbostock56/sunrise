#include <stdint.h>
#include "../include/stdio.h"
#include "../include/x86.h"
#include "../include/disk.h"
#include "../include/fat.h"
#include "../include/memdefs.h"
#include "../include/memory.h"


uint8_t *kernel_load_buffer = (uint8_t *) MEMORY_LOAD_KERNEL;
uint8_t *kernel = (uint8_t *) MEMORY_KERNEL_ADDR;

typedef void (* kernel_start)();

void __attribute__((cdecl)) start(uint16_t boot_drive, void *partition) {

    clear_screen();

    printf("---------- Sunrise Bootloader ----------\r\n");
    printf("Booting from drive %d\r\n", boot_drive);

    DISK disk;
    PARTITION part;

    if (!disk_initialize(&disk, boot_drive)) {
        printf("Disk initialization error!");
        goto infinite_loop;
    }

    MBR_detect_partition(&part, &disk, partition);
    if (!FAT_init(&part)) {
        printf("FAT initialization error!");
        goto infinite_loop;
    }
    /* Load kernel into memory */
    FAT_FILE *fd = FAT_open(&part, "/kernel.bin");
    uint32_t read;
    uint8_t *kernel_buffer = kernel;
    while ((read = FAT_read(&part, fd, MEMORY_LOAD_SIZE, kernel_load_buffer))) {
        memcpy(kernel_buffer, kernel_load_buffer, read);
        kernel_buffer += read;
    }
    FAT_close(fd);

    /* Hand over control to the kernel */
    kernel_start ks = (kernel_start) kernel;
    ks();

    /* Should never reach here */
    infinite_loop:
        for (;;);
}
