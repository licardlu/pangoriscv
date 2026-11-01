OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { ram (rwx) : ORIGIN = 0x80000000, LENGTH = 64K }
SECTIONS {
  .text : { KEEP(*(.text.init)) *(.text .text.*) } > ram
  .rodata : { *(.rodata .rodata.*) *(.srodata .srodata.*) } > ram
  .data : { *(.data .data.*) . = ALIGN(8); PROVIDE(__global_pointer$ = . + 0x800); *(.sdata .sdata.*) } > ram
  .bss (NOLOAD) : { . = ALIGN(8); _bss_start = .; *(.bss .bss.* .sbss .sbss.* COMMON) . = ALIGN(8); _bss_end = .; } > ram
  _stack_top = ORIGIN(ram) + LENGTH(ram);
}
