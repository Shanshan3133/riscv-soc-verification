# Human-readable equivalent of build_demo.py. Assemble with -march=rv32i.
.section .text
.globl _start
_start:
    lui x1, 0x20000
    lui x2, 0x20000
    addi x2, x2, 256
    addi x4, x0, 15
    sw x4, 0(x2)
    # Generated image unrolls the following sequence for "RV32I OK\r\n".
    .macro SEND_BYTE byte
1:  lw x3, 8(x1)
    andi x3, x3, 1
    beq x3, x0, 1b
    addi x4, x0, \byte
    sw x4, 0(x1)
    .endm
    SEND_BYTE 82
    SEND_BYTE 86
    SEND_BYTE 51
    SEND_BYTE 50
    SEND_BYTE 73
    SEND_BYTE 32
    SEND_BYTE 79
    SEND_BYTE 75
    SEND_BYTE 13
    SEND_BYTE 10
2:  lw x3, 8(x1)
    andi x3, x3, 1
    beq x3, x0, 2b
    ebreak
