ENTRY(_start)
MEMORY { ROM (rx) : ORIGIN = 0, LENGTH = 16K
         RAM (rw) : ORIGIN = 0x10000000, LENGTH = 16K }
SECTIONS {
 .text : { *(.text*) *(.rodata*) } > ROM
 .data : { *(.data*) } > RAM AT> ROM
 .bss (NOLOAD) : { *(.bss*) *(COMMON) } > RAM
}
/* demo.S uses no initialized RAM. C startup must copy .data and zero .bss. */
