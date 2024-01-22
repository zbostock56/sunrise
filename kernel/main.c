#include <stdint.h>
#include "memory.h"
#include "stdio.h"

extern void _init();

void start() {
    _init();

    clear_screen();
    printf("Hello from the kernel!!");
    for (;;);
}