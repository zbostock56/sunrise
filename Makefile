ASM=nasm

SRC_DIR=src
BUILD_DIR=./build
EXEC=main_floppy.img
BL=bootloader.bin
KERNEL=kernel.bin
KERNEL_DIR=kernel

.PHONY: run clean kernel bootloader floppy_img bd


floppy_img: $(BUILD_DIR)/$(EXEC)
kernel: $(BUILD_DIR)/$(KERNEL)
bootloader: $(BUILD_DIR)/$(BL)
bd: $(BUILD_DIR)

#
# Floppy Image
#
$(BUILD_DIR)/$(EXEC): bootloader kernel 
	dd if=/dev/zero of=$(BUILD_DIR)/$(EXEC) bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/$(EXEC)
	dd if=$(BUILD_DIR)/$(BL) of=$(BUILD_DIR)/$(EXEC) conv=notrunc
	mcopy -i $(BUILD_DIR)/$(EXEC) $(BUILD_DIR)/$(KERNEL) "::kernel.bin"

#
# Test Kernel
#
$(BUILD_DIR)/$(KERNEL): bd
	$(ASM) $(KERNEL_DIR)/main.asm -f bin -o $(BUILD_DIR)/$(KERNEL)

#
# Bootloader
#
$(BUILD_DIR)/$(BL): bd 
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/$(BL)

#
# Build Directory
#
$(BUILD_DIR):  
	mkdir -p $(BUILD_DIR)

run:
	qemu-system-i386 -fda $(BUILD_DIR)/$(EXEC)

clean:
	rm -rf $(BUILD_DIR)
