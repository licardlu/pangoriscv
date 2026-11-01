
RISCV_PREFIX ?= riscv32-unknown-elf-
ifneq ($(strip $(RISCV_PATH)),)
RISCV_TOOL_PREFIX := $(abspath $(RISCV_PATH)/bin)/$(RISCV_PREFIX)
else
RISCV_TOOL_PREFIX := $(RISCV_PREFIX)
endif
RISCV_GCC     ?= $(RISCV_TOOL_PREFIX)gcc
RISCV_AS      ?= $(RISCV_TOOL_PREFIX)as
RISCV_GXX     ?= $(RISCV_TOOL_PREFIX)g++
RISCV_OBJDUMP ?= $(RISCV_TOOL_PREFIX)objdump
RISCV_GDB     ?= $(RISCV_TOOL_PREFIX)gdb
RISCV_AR      ?= $(RISCV_TOOL_PREFIX)ar
RISCV_OBJCOPY ?= $(RISCV_TOOL_PREFIX)objcopy
RISCV_READELF ?= $(RISCV_TOOL_PREFIX)readelf

.PHONY: all
all: $(TARGET)

ASM_SRCS += $(COMMON_DIR)/start.S
ASM_SRCS += $(COMMON_DIR)/trap_entry.S
C_SRCS += $(COMMON_DIR)/init.c
C_SRCS += $(COMMON_DIR)/trap_handler.c
C_SRCS += $(COMMON_DIR)/lib/utils.c
C_SRCS += $(COMMON_DIR)/lib/runtime.c
C_SRCS += $(COMMON_DIR)/lib/xprintf.c
C_SRCS += $(COMMON_DIR)/lib/uart.c
C_SRCS += $(COMMON_DIR)/lib/flash_n25q.c
C_SRCS += $(COMMON_DIR)/lib/spi.c

LINKER_SCRIPT := $(COMMON_DIR)/link.lds

INCLUDES += -I$(COMMON_DIR)

LDFLAGS += -T $(LINKER_SCRIPT) -nostdlib -Wl,--gc-sections -Wl,--check-sections

ASM_OBJS := $(ASM_SRCS:.S=.o)
C_OBJS := $(C_SRCS:.c=.o)

LINK_OBJS += $(ASM_OBJS) $(C_OBJS)
LINK_DEPS += $(LINKER_SCRIPT)

CLEAN_OBJS += $(TARGET) $(LINK_OBJS) $(TARGET).dump $(TARGET).bin

CFLAGS += -march=$(RISCV_ARCH)
CFLAGS += -mabi=$(RISCV_ABI)
CFLAGS += -mcmodel=$(RISCV_MCMODEL) -ffreestanding -fno-builtin -ffunction-sections -fdata-sections

$(TARGET): $(LINK_OBJS) $(LINK_DEPS) Makefile
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) $(LINK_OBJS) -o $@ $(LDFLAGS)
	$(RISCV_OBJCOPY) -O binary $@ $@.bin
	$(RISCV_OBJDUMP) --disassemble-all $@ > $@.dump

$(ASM_OBJS): %.o: %.S
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

$(C_OBJS): %.o: %.c
	$(RISCV_GCC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

.PHONY: clean
clean:
	rm -f $(CLEAN_OBJS)
