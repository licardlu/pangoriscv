OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;

  .text : {
    *(.text*)
  }

  /DISCARD/ : {
    *(.data*)
    *(.bss*)
    *(.comment)
    *(.note*)
    *(.riscv.attributes)
    *(.eh_frame)
  }
}
