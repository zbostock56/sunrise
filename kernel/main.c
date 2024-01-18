#include <stdint.h>
#include "memory.h"
#include "stdio.h"

extern uint8_t __bss_start;
extern uint8_t __end;

void __attribute__((section(".entry"))) start(uint16_t boot_drive) {
    memset(&__bss_start, 0, (&__end) - (&__bss_start));
    clear_screen();
    printf("Hello from the kernel!!");
    for (;;);
}