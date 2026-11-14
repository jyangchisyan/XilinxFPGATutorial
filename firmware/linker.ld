ENTRY(_start)
MEMORY { bram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K }
SECTIONS
{
    .vectors 0 : { KEEP(*(.vectors)) } > bram
    .text 0x50 : { *(.text.boot) *(.text*) } > bram
    .rodata : { *(.rodata*) } > bram
    .sdata2 : { _SDA2_BASE_ = .; *(.sdata2*) } > bram
    .data : { *(.data*) } > bram
    .sdata : { _SDA_BASE_ = .; *(.sdata*) } > bram
    .bss (NOLOAD) : {
        . = ALIGN(4); __bss_start = .;
        *(.sbss*) *(.bss*) *(COMMON)
        . = ALIGN(4); __bss_end = .;
    } > bram
    _stack_top = ORIGIN(bram) + LENGTH(bram) - 16;
    ASSERT(__bss_end <= _stack_top - 4096, "Firmware leaves less than 4 KiB stack")
}
