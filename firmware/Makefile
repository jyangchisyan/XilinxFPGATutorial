TOOLCHAIN ?= /tools/Xilinx/Vitis/2024.2/gnu/microblaze/lin/bin/mb-
CC := $(TOOLCHAIN)gcc
OUT := ../build/firmware
CFLAGS := -Os -g -Wall -Wextra -Werror -ffreestanding -fno-builtin -fno-stack-protector -mlittle-endian -mcpu=v11.0 -mxl-soft-mul -mno-xl-barrel-shift -mxl-soft-div -mno-xl-reorder -G 0

.PHONY: all clean
all: $(OUT)/app.elf
$(OUT)/app.elf: start.S main.c linker.ld
	mkdir -p $(OUT)
	$(CC) $(CFLAGS) -nostdlib -nostartfiles -Wl,--no-relax,-T,linker.ld,-Map,$(OUT)/app.map start.S main.c -o $@
	$(TOOLCHAIN)size $@
	$(TOOLCHAIN)objdump -d $@ > $(OUT)/app.dis
clean:
	rm -rf $(OUT)
