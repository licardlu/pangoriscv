RISCV_ARCH := rv32im
RISCV_ABI := ilp32
RISCV_MCMODEL := medlow

TARGET := coremark

C_SRCS := \
	core_list_join.c \
	core_main.c \
	core_matrix.c \
	core_state.c \
	core_util.c \
	core_portme.c \

CFLAGS := -O2 -fno-common -funroll-loops -finline-functions --param max-inline-insns-auto=20 -falign-functions=4 -falign-jumps=4 -falign-loops=4
CFLAGS += -DFLAGS_STR=\""$(CFLAGS)"\"
ITERATIONS ?= 10000
CFLAGS += -DITERATIONS=$(ITERATIONS)
ifeq ($(findstring -DVALIDATION_RUN,$(CFLAGS))$(findstring -DPROFILE_RUN,$(CFLAGS))$(findstring -DPERFORMANCE_RUN,$(CFLAGS)),)
CFLAGS += -DPERFORMANCE_RUN=1
endif

COMMON_DIR = ..
TOOLCHAIN_DIR = ../../..
include ../common.mk
