# CoreMark port makefile: RV32IMC bare metal, 紫光同创 PG2L100H SoC
#
# 用法（在 firmware/coremark 目录下）：
#   make PORT_DIR=../port ITERATIONS=7000 CC=riscv-none-elf-gcc
# 产物：coremark.elf
#
# 注意：这里是"能编出可用的 ELF"。要与仓库里冻结的 8 lane 镜像逐字节一致，
# 请用仓库根目录的 `python scripts/build.py firmware --iterations 7000`，
# 它才是记录在 release_manifest.json 里的权威构建路径。本文件与它保持同一组
# 优化选项，正常情况下 ram_sha256 应当相同（见 README）。

OUTFLAG = -o
COUT    = -c
OBJOUT  = -o
OFLAG   = -o
OEXT    = .o
EXE     = .elf

# 交叉编译器。xpack 的 riscv-none-elf-gcc 自带 riscv32-unknown-elf-* 别名。
CC ?= riscv-none-elf-gcc
AS ?= $(CC)

# 与 scripts/build.py 完全一致的优化选项。改这里必须同步改那个脚本。
PORT_CFLAGS = -O2 -fno-common -funroll-loops -finline-functions \
              -funroll-all-loops -falign-functions=8 -falign-jumps=8 -falign-loops=8 \
              -finline-limit=1000 -mtune=sifive-7-series -ffast-math \
              -fno-tree-loop-distribute-patterns --param=fsm-scale-path-stmts=3 \
              -march=rv32imc_zicsr_zifencei -mabi=ilp32 -fno-builtin

FLAGS_STR = $(PORT_CFLAGS)

# OPATH 由主 Makefile 提供（默认 ./），编译产物和 compiler_flags.h 都落在那里。
CFLAGS = $(PORT_CFLAGS) -nostdlib -nostartfiles -ffreestanding \
         -I$(PORT_DIR) -I. \
         -include $(OPATH)compiler_flags.h

# 链接：自定义 link.ld + 起始汇编 + libgcc（64 位乘除与软件浮点辅助例程）
LFLAGS_END = -nostdlib -nostartfiles -ffreestanding \
             -T $(PORT_DIR)/link.ld $(PORT_DIR)/start.S -lgcc

PORT_SRCS = $(PORT_DIR)/core_portme.c $(PORT_DIR)/ee_printf.c $(PORT_DIR)/start.S

# 迭代次数默认取交付档 7000。命令行 make ITERATIONS=xxx 可覆盖。
# 120.461538 MHz 下 7000 迭代约 10.87 s，满足"单次运行 ≥10 s"的赛题要求。
ITERATIONS ?= 7000

vpath %.c $(PORT_DIR)
vpath %.S $(PORT_DIR)

LOAD = echo "Load coremark.elf via PDS download (SRAM config) and open the UART at 115200 8N1."
RUN  = echo "Reset the board; CoreMark prints to UART0 at 115200 8N1."

# CoreMark 会把 COMPILER_FLAGS 打印在报告头里。生成一个头文件而不是在命令行上
# 塞引号，避免不同 shell/Make 版本的转义差异。
port_prebuild:
	@echo '#define COMPILER_FLAGS "'$(FLAGS_STR)'"' > $(OPATH)compiler_flags.h
