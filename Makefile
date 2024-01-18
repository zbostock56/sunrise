include build_helpers/config.mk

#include build_helpers/toolchain.mk

.PHONY: all run clean kernel bootloader floppy_img bd drivers

all: floppy_img #drivers_fat12

floppy_img: $(BUILD_DIR)/$(IMG)
kernel: $(BUILD_DIR)/$(KERNEL)
bootloader: stage1 stage2
bd: $(BUILD_DIR)
#drivers_fat12: $(BUILD_DIR)/drivers/

#
# Floppy Image
# @mcopy -i $@ test.txt "::test.txt"
# @mmd -i $@ "::mydir"
# @mcopy -i $@ test.txt "::mydir/test.txt"
#
$(BUILD_DIR)/$(IMG): bootloader kernel 
	@dd if=/dev/zero of=$@ bs=512 count=2880
	@mkfs.fat -F 12 -n "NBOS" $@
	@dd if=$(BUILD_DIR)/$(STAGE1) of=$@ conv=notrunc
	@mcopy -i $@ $(BUILD_DIR)/$(STAGE2) "::stage2.bin"
	@mcopy -i $@ $(BUILD_DIR)/$(KERNEL) "::kernel.bin"
	@echo "--> Created: " $@

#
# Test Kernel
#
$(BUILD_DIR)/$(KERNEL): $(BUILD_DIR)
	@$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))

#
# Bootloader
#
stage1: $(BUILD_DIR)/$(STAGE1)
stage2: $(BUILD_DIR)/$(STAGE2)

$(BUILD_DIR)/$(STAGE1): bd
	@$(MAKE) -C $(SRC_DIR)/$(STAGE1_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))

$(BUILD_DIR)/$(STAGE2): bd
	@$(MAKE) -C $(SRC_DIR)/$(STAGE2_DIR) BUILD_DIR=$(abspath $(BUILD_DIR))

#
# Drivers
#
$(BUILD_DIR)/drivers:
	@mkdir -p $(BUILD_DIR)/drivers
	@$(MAKE) -C drivers BUILD_DIR=$(abspath $(BUILD_DIR))

#
# Build Directory
#
$(BUILD_DIR):  
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/$(STAGE2_DIR)/c/src
	@mkdir -p $(BUILD_DIR)/$(STAGE2_DIR)/asm/src

#
# Run on virtualization software
#
run:
	qemu-system-i386 -drive format=raw,file=$(BUILD_DIR)/$(IMG),if=floppy

#
# Debug using Bochs
#
debug:
	bochs -f bochs_config

clean:
	@$(MAKE) -C $(SRC_DIR)/$(STAGE1_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	@$(MAKE) -C $(SRC_DIR)/$(STAGE2_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	@$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	@rm -rf $(BUILD_DIR)
