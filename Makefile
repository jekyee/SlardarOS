NASM := nasm
COMPILER_PATH := /usr/local/gcc-4.8.1-for-linux32/bin
COMPILER_PREFIX := $(COMPILER_PATH)/i586-pc-linux-
CC := $(COMPILER_PREFIX)gcc
CXX := $(COMPILER_PREFIX)g++
LD := $(COMPILER_PREFIX)ld
OBJCOPY := $(COMPILER_PREFIX)objcopy
OBJDUMP := $(COMPILER_PREFIX)objdump
HD := hdiutil
DD := dd
CP := cp
RM := rm
QEMU := qemu-system-i386
GDB := i386-linux-gdb
MKDIR := mkdir
PYTHON := python
V := @

C_FLAGS := -fno-builtin -Wall -ggdb -gstabs -nostdinc -fno-stack-protector -O0 -nostdinc

BUILD_DIR := generated
BOOT_DIR := boot
UTILS_DIR := utils
BOOT_SECTOR_BIN := bootSector.bin
BOOT_LOADER_BIN := loader.bin
OS_IMAGE := SlardarOS.img
EMPTY_IMAGE := empty.img
MOUNT_DIR := /Volumes/SlardarOS/
KERNEL_BIN := kernel.bin

KERNEL_INC_DIR := .
KERNEL_LIB_DIR := .
KERNEL_DIR := kernel
KERNEL_SRC = $(foreach dir,$(subst :, ,$(KERNEL_DIR)),$(wildcard $(dir)/*.cpp))
KERNEL_OBJ_DIR = $(addprefix $(BUILD_DIR)/,$(subst :, ,$(KERNEL_DIR)))
KERNEL_OBJS = $(addprefix $(BUILD_DIR)/,$(subst .cpp,.o,$(KERNEL_SRC)))
KERNEL_DEPS = $(KERNEL_SRC:.cpp=.cpp.d)

CXX_FLAGS := -I$(KERNEL_INC_DIR) -ffreestanding -O0 -Wall -Wextra -fno-exceptions -fno-rtti -ggdb

.PHONY: qemu debug os bootSector bootLoader osImage clean kernel

debug: osImage
	$(V) ttab -w eval '$(GDB) -x $(BUILD_DIR)/gdb.cmd'
	$(V) $(QEMU) -s -S -fda $(BUILD_DIR)/$(OS_IMAGE)
qemu: osImage
	$(V) $(QEMU) -fda $(BUILD_DIR)/$(OS_IMAGE)

os: osImage

bootSector:
	$(V) $(NASM) -I $(BOOT_DIR)/ $(BOOT_DIR)/bootSector.asm -o $(BUILD_DIR)/$(BOOT_SECTOR_BIN)

bootLoader:
	$(V) $(CC) -m32 $(C_FLAGS) -c $(BOOT_DIR)/bootLoader.S -o $(BUILD_DIR)/bootLoader.S.o
	$(V) $(CC) -m32 $(C_FLAGS) -c $(BOOT_DIR)/bootLoader.c -o $(BUILD_DIR)/bootLoader.c.o
	$(V) $(LD) -m elf_i386 -nostdlib -N -e start -Ttext 0x9000 -o $(BUILD_DIR)/bootLoader.o $(BUILD_DIR)/bootLoader.S.o $(BUILD_DIR)/bootLoader.c.o
	$(V) $(OBJCOPY) -S -O binary $(BUILD_DIR)/bootLoader.o $(BUILD_DIR)/$(BOOT_LOADER_BIN)
	$(V) $(OBJDUMP) -S -D $(BUILD_DIR)/bootLoader.o > $(BUILD_DIR)/bootLoader.dump
	$(V) $(PYTHON) $(UTILS_DIR)/gdbCmd.py

kernel: kernelDir $(KERNEL_OBJS)
	$(V) $(CXX) -o $(BUILD_DIR)/kernel.bin $(KERNEL_OBJS)

kernelDir:
	$(V) $(MKDIR) -p $(KERNEL_OBJ_DIR)

$(BUILD_DIR)/%.o: %.cpp $(BUILD_DIR)/%.cpp.d
	$(V) $(CXX) $(CXX_FLAGS) -o $@ -c $<

$(BUILD_DIR)/%.cpp.d: %.cpp
	$(V) $(CXX) $(CXX_FLAGS) $< -MM > $(BUILD_DIR)/$<.d

osImage: buildDir bootSector bootLoader kernel
	$(V) $(DD) if=/dev/zero of=$(BUILD_DIR)/$(EMPTY_IMAGE) bs=512 count=2880
	$(V) $(DD) if=$(BUILD_DIR)/$(BOOT_SECTOR_BIN) of=$(BUILD_DIR)/$(OS_IMAGE) bs=512 count=1
	$(V) $(DD) if=$(BUILD_DIR)/$(EMPTY_IMAGE) of=$(BUILD_DIR)/$(OS_IMAGE) skip=1 seek=1 bs=512 count=2879
	$(V) $(HD) attach $(BUILD_DIR)/$(OS_IMAGE)
	$(V) $(CP) $(BUILD_DIR)/$(BOOT_LOADER_BIN) $(MOUNT_DIR)/$(BOOT_LOADER_BIN)
	$(V) $(CP) $(BUILD_DIR)/$(KERNEL_BIN) $(MOUNT_DIR)/$(KERNEL_BIN)
	$(V) $(HD) detach $(MOUNT_DIR)

buildDir:
	$(V) $(MKDIR) -p $(BUILD_DIR)

clean:
	$(V) $(RM) $(BUILD_DIR)/*.o
	$(V) $(RM) $(BUILD_DIR)/*.bin
	$(V) $(RM) $(BUILD_DIR)/*.dump
	$(V) $(RM) $(BUILD_DIR)/*.img
	$(V) $(RM) $(BUILD_DIR)/*.cmd
	$(V) $(RM) $(addsuffix /*.o,$(KERNEL_OBJ_DIR))