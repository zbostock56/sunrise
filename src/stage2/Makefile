TARGET_ASMFLAGS += -f elf
TARGET_CFLAGS += -ffreestanding -nostdlib
TARGET_LIBS += -lgcc
TARGET_LINKFLAGS += -T linker.ld -nostdlib

SRC_C=$(wildcard src/*.c)
SRC_ASM=$(wildcard src/*.asm)
OBJ_C=$(patsubst %.c, $(BUILD_DIR)/$(STAGE2_DIR)/c/%.obj, $(SRC_C))
OBJ_ASM=$(patsubst %.asm, $(BUILD_DIR)/$(STAGE2_DIR)/asm/%.obj, $(SRC_ASM))

.PHONY: all stage2 clean dirs

all: stage2

stage2: $(BUILD_DIR)/$(STAGE2)

#
#	Link .obj files from stage2
#
$(BUILD_DIR)/$(STAGE2): $(OBJ_ASM) $(OBJ_C)
	@$(TARGET_LD) $(TARGET_LINKFLAGS) -Wl,-Map=$(BUILD_DIR)/stage2.map -o $@ $^ $(TARGET_LIBS)
	@echo "--> Created:   stage2.bin"

#
#	Build .c files from stage2
#
$(BUILD_DIR)/$(STAGE2_DIR)/c/%.obj: %.c
	@$(TARGET_CC) $(TARGET_CFLAGS) -I $(abspath ./include) -c -o $@ $<
	@echo "--> Compiled: " $<

#
#	Build .asm files from stage2
#
$(BUILD_DIR)/$(STAGE2_DIR)/asm/%.obj: %.asm
	@$(TARGET_ASM) $(TARGET_ASMFLAGS) -o $@ $<
	@echo "--> Assembled: " $<

clean:
	@rm -rf $(BUILD_DIR)/$(STAGE2)
