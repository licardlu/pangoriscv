/* Linker script for the end-to-end ISA regression image.
 * The image is loaded at address 0 into the program RAM; the trap handler has
 * a fixed address so the test cases can load mtvec without relocations.
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;

  .text : {
    *(.text.init)
    *(.text)
  }

  . = 0x00002000;
  .rodata : {
    *(.rodata)
    *(.srodata)
  }

  /* The trap handler must be linked at address 0x3f00 so the tests can load
   * mtvec = 0x3f00 without relocations, and so the image stays inside the
   * 16 KiB program RAM. */
  . = 0x00003f00;
  .trap : {
    *(.trap)
  }

  /DISCARD/ : {
    *(.comment)
    *(.note*)
    *(.riscv.attributes)
    *(.eh_frame*)
    *(.data)
    *(.bss)
  }
}
