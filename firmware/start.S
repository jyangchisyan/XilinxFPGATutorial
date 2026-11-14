/* Reset and exception vectors live in the BRAM at address zero. */
    .section .vectors,"ax"
    .global _start
_start:
    brai boot
    .org 0x08
    brai fault
    .org 0x10
    brai fault
    .org 0x18
    brai fault
    .org 0x20
    brai fault

    .section .text.boot,"ax"
boot:
    la r1, r0, _stack_top
    la r13, r0, _SDA_BASE_
    la r2, r0, _SDA2_BASE_
    la r3, r0, __bss_start
    la r4, r0, __bss_end
clear_bss:
    cmpu r5, r4, r3
    bgei r5, run_main
    swi r0, r3, 0
    addik r3, r3, 4
    bri clear_bss
run_main:
    brlid r15, main
    nop
fault:
    bri fault
