include build_helpers/config.mk

#include build_helpers/toolchain.mk

.PHONY: all run clean kernel bootloader floppy_image bd drivers disk

all: floppy_image disk_image #drivers_fat12

floppy_image: $(BUILD_DIR)/$(IMG)
disk_image: $(BUILD_DIR)/$(DISK)
bootloader: stage1 stage2
kernel: $(BUILD_DIR)/$(KERNEL)
bd: $(BUILD_DIR)
#drivers_fat12: $(BUILD_DIR)/drivers/

#
# Floppy Image
#
$(BUILD_DIR)/$(IMG): bootloader kernel 
	@./build_helpers/floppy_image.sh $@
	@echo "--> Created: " $@

#
#	Disk Image
#
$(BUILD_DIR)/$(DISK): bootloader kernel
	@./build_helpers/disk_image.sh $@ $(MAKE_DISK_SIZE)
	@echo "--> Created: " $@

#
# Test Kernel
#
$(BUILD_DIR)/$(KERNEL): $(BUILD_DIR)
	@$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(BUILD_DIR)

#
# Bootloader
#
stage1: $(BUILD_DIR)/$(STAGE1)
stage2: $(BUILD_DIR)/$(STAGE2)

$(BUILD_DIR)/$(STAGE1): bd
	@$(MAKE) -C $(SRC_DIR)/$(STAGE1_DIR) BUILD_DIR=$(BUILD_DIR)

$(BUILD_DIR)/$(STAGE2): bd
	@$(MAKE) -C $(SRC_DIR)/$(STAGE2_DIR) BUILD_DIR=$(BUILD_DIR)

#
# Drivers
#
$(BUILD_DIR)/drivers:
	@mkdir -p $(BUILD_DIR)/drivers
	@$(MAKE) -C drivers BUILD_DIR=$(BUILD_DIR)

#
# Build Directory
#
$(BUILD_DIR):  
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/$(STAGE2_DIR)/c/src
	@mkdir -p $(BUILD_DIR)/$(STAGE2_DIR)/asm/src
	@mkdir -p $(BUILD_DIR)/$(STAGE1_DIR)/asm/src

#
# Run on virtualization software
#
run_floppy:
	qemu-system-i386 -drive format=raw,file=$(BUILD_DIR)/$(IMG),if=floppy

run_disk:
	qemu-system-i386 -hda $(BUILD_DIR)/$(DISK)

#
# Debug using Bochs
#
debug_floppy:
	bochs -f debug/bochs_floppy_config

debug_disk:
	bochs -f debug/bochs_disk_config

clean:
	@$(MAKE) -C $(SRC_DIR)/$(STAGE1_DIR) BUILD_DIR=$(BUILD_DIR) clean
	@$(MAKE) -C $(SRC_DIR)/$(STAGE2_DIR) BUILD_DIR=$(BUILD_DIR) clean
	@$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(BUILD_DIR) clean
	@rm -rf $(BUILD_DIR)
