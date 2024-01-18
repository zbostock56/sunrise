#pragma once

#include <stdint.h>

void __attribute__((cdecl)) x86_panic();
void __attribute__((cdecl)) x86_outb(uint16_t, uint8_t );
uint8_t __attribute__((cdecl)) x86_inb(uint16_t );
uint8_t  __attribute__((cdecl)) x86_disk_get_drive_params(uint8_t, uint8_t *, 
                                                        uint16_t *, uint16_t *,
                                                        uint16_t *);
uint8_t __attribute__((cdecl)) x86_disk_reset(uint8_t drive);
uint8_t __attribute__((cdecl)) x86_disk_read(uint8_t, uint16_t, uint16_t,
                                          uint16_t, uint8_t, void *);