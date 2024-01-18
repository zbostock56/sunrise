#pragma once

#include "disk.h"
#include <stdint.h>
#include <stdbool.h>

#define SECTOR_SIZE             (512)
#define MAX_PATH_SIZE           (256)
#define MAX_FILE_HANDLES        (10)
#define ROOT_DIRECTORY_HANDLE   (-1)

typedef struct {
    uint8_t name[11];
    uint8_t attributes;
    uint8_t _reserved;
    uint8_t created_time_tenths;
    uint16_t created_time;
    uint16_t created_date;
    uint16_t accessed_date;
    uint16_t first_cluster_high;
    uint16_t modified_time;
    uint16_t modified_date;
    uint16_t first_cluster_low;
    uint32_t size;
} __attribute__((packed)) FAT_directory_entry;

typedef struct {
    int handle;
    bool is_directory;
    uint32_t position;
    uint32_t size;
} FAT_file;

enum FAT_Attributes {
    FAT_ATTRIBUTE_READ_ONLY         = 0x01,
    FAT_ATTRIBUTE_HIDDEN            = 0x02,
    FAT_ATTRIBUTE_SYSTEM            = 0x04,
    FAT_ATTRIBUTE_VOLUME_ID         = 0x08,
    FAT_ATTRIBUTE_DIRECTORY         = 0x10,
    FAT_ATTRIBUTE_ARCHIVE           = 0x20,
    FAT_ATTRIBUTE_LFN               = FAT_ATTRIBUTE_READ_ONLY | FAT_ATTRIBUTE_HIDDEN | FAT_ATTRIBUTE_SYSTEM | FAT_ATTRIBUTE_VOLUME_ID
};

typedef struct {
    /* BIOS Parameter Block */
    uint8_t boot_jump_instructions[3];
    uint8_t oem_identifier[8];
    uint16_t bytes_per_sector;
    uint8_t sectors_per_cluster;
    uint16_t reserved_sectors;
    uint8_t fat_count;
    uint16_t dir_entry_count;
    uint16_t total_sectors;
    uint8_t media_descriptor_type;
    uint16_t sectors_per_fat;
    uint16_t sectors_per_track;
    uint16_t heads;
    uint32_t hidden_sectors;
    uint32_t large_sector_count;

    /* Extended Boot Record */
    uint8_t drive_number;
    uint8_t _reserved;
    uint8_t signiture;
    uint32_t volume_id;
    uint8_t volume_label[11];
    uint8_t system_id[8];
} __attribute__((packed)) FAT_boot_sector;

typedef struct {
    uint8_t buffer[SECTOR_SIZE];
    FAT_file public;
    bool opened;
    uint32_t first_cluster;
    uint32_t current_cluster;
    uint32_t current_sector_in_cluster;
} FAT_file_data;

typedef struct {
    union {
        FAT_boot_sector boot_sector;
        uint8_t boot_sector_bytes[SECTOR_SIZE];
    } BS;
    FAT_file_data root_directory;
    FAT_file_data opened_files[MAX_FILE_HANDLES];
} FAT_data;

bool FAT_init(DISK *);
FAT_file *FAT_open(DISK *, const char *);
uint32_t FAT_read(DISK *, FAT_file *, uint32_t, void *);
bool FAT_read_entry(DISK *, FAT_file *, FAT_directory_entry *);
void FAT_close(FAT_file *);
