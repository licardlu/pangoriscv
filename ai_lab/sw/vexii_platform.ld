OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
}
SECTIONS {
    .init : { KEEP(*(.init)) } > RAM
    .text : { *(.text*) *(.rodata*) . = ALIGN(4); } > RAM
    .data : {
        _data_start = .;
        *(.data*) *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM
    _data_load = LOADADDR(.data);
    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    } > RAM
    __global_pointer$ = _data_start + 0x800;
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_bss_end + 8192 <= _stack_top, "Less than 8 KiB CPU stack remains")
    /DISCARD/ : { *(.comment*) *(.eh_frame*) }
}
