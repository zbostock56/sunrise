ASM=nasm

SRC_DIR=src
BUILD_DIR=./build
EXEC=main_floppy.img

.PHONY: run clean

$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)  $(BUILD_DIR)/main.bin	
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/$(EXEC)
	truncate -s 1440k $(BUILD_DIR)/$(EXEC)

$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/main.bin

$(BUILD_DIR):  
	mkdir -p $(BUILD_DIR)

run:
	qemu-system-i386 -fda $(BUILD_DIR)/$(EXEC)

clean:
	rm -rf $(BUILD_DIR)
