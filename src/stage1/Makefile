TARGET_ASMFLAGS += -f elf $(TARGET_FS)
TARGET_LINKFLAGS += -T linker.ld -nostdlib

.PHONY: all clean

all: stage1

stage1: $(BUILD_DIR)/stage1.bin

SRC_ASM=$(wildcard *.asm)
OBJ_ASM=$(patsubst %.asm, $(BUILD_DIR)/$(STAGE1_DIR)/asm/%.obj, $(SRC_ASM))

#
#	Link .obj files from stage1
#
$(BUILD_DIR)/$(STAGE1): $(OBJ_ASM)
	@$(TARGET_LD) $(TARGET_LINKFLAGS) -Wl,-Map=$(BUILD_DIR)/stage1.map -o $@ $^ $(TARGET_LIBS)
	@echo "--> Created:   stage1.bin"

#
#	Build .asm files from stage1
#
$(BUILD_DIR)/$(STAGE1_DIR)/asm/%.obj: %.asm
	@$(TARGET_ASM) $(TARGET_ASMFLAGS) -o $@ $<
	@echo "--> Assembled: " $<

clean:
	@rm -rf $(BUILD_DIR)/$(STAGE1_DIR)
