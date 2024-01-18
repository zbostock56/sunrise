#include "../include/fat.h"
#include "../include/stdio.h"
#include "../include/memdefs.h"
#include "../include/string.h"
#include "../include/memory.h"
#include "../include/ctype.h"
#include "../include/utility.h"

static FAT_data *g_data;
static uint8_t *g_fat = NULL;
static uint32_t g_data_section_lba;

bool FAT_read_boot_sector(DISK* disk) {
    return disk_read_sectors(disk, 0, 1, g_data->BS.boot_sector_bytes);
}

bool FAT_read_fat(DISK *disk) {
    return disk_read_sectors(disk, g_data->BS.boot_sector.reserved_sectors,
                            g_data->BS.boot_sector.sectors_per_fat, g_fat);
}

bool FAT_init(DISK *disk) {
    g_data = (FAT_data *) MEMORY_FAT_ADDR;
    
    /* Read boot sector */
    if (!FAT_read_boot_sector(disk)) {
        printf("FAT: read boot sector failed\r\n");
        return false;
    }

    /* Read file allocation table (FAT) */
    g_fat = (uint8_t *) g_data + sizeof(FAT_data);
    uint32_t fatSize = g_data->BS.boot_sector.bytes_per_sector * 
                       g_data->BS.boot_sector.sectors_per_fat;
    if (sizeof(FAT_data) + fatSize >= MEMORY_FAT_SIZE) {
        printf("FAT: not enough memory to read FAT! Required %lu, only have %u\r\n", 
                sizeof(FAT_data) + fatSize, MEMORY_FAT_SIZE);
        return false;
    }

    if (!FAT_read_fat(disk)) {
        printf("FAT: read FAT failed\r\n");
        return false;
    }

    /* Open root directory of file */
    uint32_t rootDirLba = g_data->BS.boot_sector.reserved_sectors + 
                          g_data->BS.boot_sector.sectors_per_fat * 
                          g_data->BS.boot_sector.fat_count;
    uint32_t rootDirSize = sizeof(FAT_directory_entry) * 
                           g_data->BS.boot_sector.dir_entry_count;

    g_data->root_directory.public.handle = ROOT_DIRECTORY_HANDLE;
    g_data->root_directory.public.is_directory = true;
    g_data->root_directory.public.position = 0;
    g_data->root_directory.public.size = sizeof(FAT_directory_entry) * 
                                         g_data->BS.boot_sector.dir_entry_count;
    g_data->root_directory.opened = true;
    g_data->root_directory.first_cluster = rootDirLba;
    g_data->root_directory.current_cluster = rootDirLba;
    g_data->root_directory.current_cluster = 0;

    if (!disk_read_sectors(disk, rootDirLba, 1, g_data->root_directory.buffer)) {
        printf("FAT: read root directory failed\r\n");
        return false;
    }

    /* Calculate data section */
    uint32_t rootDirSectors = (rootDirSize + g_data->BS.boot_sector.bytes_per_sector - 1) / 
                              g_data->BS.boot_sector.bytes_per_sector;
    g_data_section_lba = rootDirLba + rootDirSectors;

    /* Reset opened file descriptors */
    for (int i = 0; i < MAX_FILE_HANDLES; i++) {
        g_data->opened_files[i].opened = false;
    }
    return true;
}

uint32_t FAT_cluster_to_lba(uint32_t cluster) {
    return g_data_section_lba + (cluster - 2) * 
           g_data->BS.boot_sector.sectors_per_cluster;
}

FAT_file *FAT_open_entry(DISK *disk, FAT_directory_entry *entry) {
    /* Find empty handle */
    int handle = -1;
    for (int i = 0; i < MAX_FILE_HANDLES && handle < 0; i++) {
        if (!g_data->opened_files[i].opened) {
            handle = i;
        }
    }

    /* Out of handles */
    if (handle < 0) {
        printf("FAT: out of file handles\r\n");
        return false;
    }

    /* Setup descriptor before returning to user */
    FAT_file_data *fd = &g_data->opened_files[handle];
    fd->public.handle = handle;
    fd->public.is_directory = (entry->attributes & FAT_ATTRIBUTE_DIRECTORY) != 0;
    fd->public.position = 0;
    fd->public.size = entry->size;
    fd->first_cluster = entry->first_cluster_low + 
                        ((uint32_t) entry->first_cluster_high << 16);
    fd->current_cluster = fd->first_cluster;
    fd->current_sector_in_cluster = 0;

    if (!disk_read_sectors(disk, FAT_cluster_to_lba(fd->current_cluster), 1, fd->buffer)) {
        printf("FAT: open entry failed - read error cluster=%u lba=%u\n", 
               fd->current_cluster, FAT_cluster_to_lba(fd->current_cluster));
        for (int i = 0; i < 11; i++) {
            printf("%c", entry->name[i]);
        }
        printf("\n");
        return false;
    }

    fd->opened = true;
    return &fd->public;
}

uint32_t FAT_next_cluster(uint32_t current_cluster) {    
    uint32_t fatIndex = current_cluster * 3 / 2;
    if (current_cluster % 2 == 0) {
        return (*(uint16_t *) (g_fat + fatIndex)) & 0x0FFF;
    } else {
        return (*(uint16_t *) (g_fat + fatIndex)) >> 4;
    }
}

uint32_t FAT_read(DISK *disk, FAT_file *file, uint32_t byteCount, void *dataOut) {
    /* Get file data */
    FAT_file_data *fd = (file->handle == ROOT_DIRECTORY_HANDLE) 
        ? &g_data->root_directory 
        : &g_data->opened_files[file->handle];

    uint8_t *u8DataOut = (uint8_t *) dataOut;

    /* Don't read past the end of the file */
    if (!fd->public.is_directory || (fd->public.is_directory && fd->public.size != 0)) {
        byteCount = min(byteCount, fd->public.size - fd->public.position);
    }

    while (byteCount > 0) {
        uint32_t leftInBuffer = SECTOR_SIZE - (fd->public.position % SECTOR_SIZE);
        uint32_t take = min(byteCount, leftInBuffer);

        memcpy(u8DataOut, fd->buffer + fd->public.position % SECTOR_SIZE, take);
        u8DataOut += take;
        fd->public.position += take;
        byteCount -= take;

        /* Check if there is more data to read */
        if (leftInBuffer == take) {
            /* Special handling for root directory */
            if (fd->public.handle == ROOT_DIRECTORY_HANDLE) {
                ++fd->current_cluster;
                /* Read next sector */
                if (!disk_read_sectors(disk, fd->current_cluster, 1, fd->buffer)) {
                    printf("FAT: read error!\r\n");
                    break;
                }
            } else {
                /*  Calculate next cluster and sector to read */
                if (++fd->current_sector_in_cluster>= g_data->BS.boot_sector.sectors_per_cluster) {
                    fd->current_sector_in_cluster = 0;
                    fd->current_cluster = FAT_next_cluster(fd->current_cluster);
                }

                if (fd->current_cluster >= 0xFF8) {
                    /* Mark end of file */
                    fd->public.size = fd->public.position;
                    break;
                }

                /* Read next sector */
                if (!disk_read_sectors(disk, FAT_cluster_to_lba(fd->current_cluster) + 
                                       fd->current_sector_in_cluster, 1, fd->buffer)) {
                    printf("FAT: read error!\r\n");
                    break;
                }
            }
        }
    }
    return u8DataOut - (uint8_t *) dataOut;
}

bool FAT_read_entry(DISK *disk, FAT_file *file, FAT_directory_entry *dirEntry) {   
    return FAT_read(disk, file, sizeof(FAT_directory_entry), dirEntry) == sizeof(FAT_directory_entry);
}

void FAT_close(FAT_file *file) {
    if (file->handle == ROOT_DIRECTORY_HANDLE) {
        file->position = 0;
        g_data->root_directory.current_cluster = g_data->root_directory.first_cluster;
    } else {
        g_data->opened_files[file->handle].opened = false;
    }
}

bool FAT_find_file(DISK *disk, FAT_file *file, const char *name, FAT_directory_entry *entryOut) {
    char fatName[12];
    FAT_directory_entry entry;

    /* Convert from normal name to FAT style name */
    memset(fatName, ' ', sizeof(fatName));
    fatName[11] = '\0';

    /* TODO: Account for files that start */
    /* with '.', i.e. .bashrc             */
    const char *ext = strchr(name, '.');
    if (ext == NULL) {
        ext = name + 11;
    }

    for (int i = 0; i < 8 && name[i] && name + i < ext; i++) {
        fatName[i] = toupper(name[i]);
    }

    if (ext != name + 11) {
        for (int i = 0; i < 3 && ext[i + 1]; i++)
            fatName[i + 8] = toupper(ext[i + 1]);
    }

    while (FAT_read_entry(disk, file, &entry)) {
        if (memcmp(fatName, entry.name, 11) == 0) {
            *entryOut = entry;
            return true;
        }        
    }
    
    return false;
}

FAT_file *FAT_open(DISK *disk, const char *path) {
    char name[MAX_PATH_SIZE];

    // ignore leading slash
    if (path[0] == '/') {
        path++;
    }

    FAT_file *current = &g_data->root_directory.public;

    while (*path) {
        /* Extract file name from path */
        bool isLast = false;
        const char *delim = strchr(path, '/');
        if (delim != NULL) {
            memcpy(name, path, delim - path);
            name[delim - path + 1] = '\0';
            path = delim + 1;
        } else {
            unsigned len = strlen(path);
            memcpy(name, path, len);
            name[len + 1] = '\0';
            path += len;
            isLast = true;
        }
        
        /* Find directory entry in current directory */
        FAT_directory_entry entry;
        if (FAT_find_file(disk, current, name, &entry)) {
            FAT_close(current);
            /* Check if directory */
            if (!isLast && entry.attributes & FAT_ATTRIBUTE_DIRECTORY == 0) {
                printf("FAT: %s not a directory\r\n", name);
                return NULL;
            }
            /* Open new directory entry */
            current = FAT_open_entry(disk, &entry);
        } else {
            FAT_close(current);
            printf("FAT: %s not found\r\n", name);
            return NULL;
        }
    }
    return current;
}
