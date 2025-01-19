MIPS
====

This is an implementation of a MIPS CPU implemented in Verilog
to be run on an FPGA. The board being used here is an iceFUN with
a Lattice iCE40 HX8K FPGA.

This project was created by forking the RISC-V FPGA project and
simply changing the opcodes to do MIPS instead.

https://www.mikekohn.net/micro/mips_fpga.php

Features
========

IO, Button input, speaker tone generator, SPI, and Mandelbrot acceleration.

Opcodes
=======

R Type
------

    sll   rd, rt, sa 000000 00000 ttttt ddddd aaaaa 000000
    srl   rd, rt, sa 000000 00000 ttttt ddddd aaaaa 000010
    sra   rd, rt, sa 000000 00000 ttttt ddddd aaaaa 000011
    sllv  rd, rt, rs 000000 sssss ttttt ddddd 00000 000100
    srlv  rd, rt, rs 000000 sssss ttttt ddddd 00000 000110
    srav  rd, rt, rs 000000 sssss ttttt ddddd 00000 000111
    jr    rs         000000 sssss 00000 00000 hhhhh 001000
    jalr  rd, rs     000000 sssss 00000 ddddd hhhhh 001001
    syscall          000000 xxxxx xxxxx xxxxx xxxxx 001100
    break            000000 xxxxx xxxxx xxxxx xxxxx 001101
    div   rs, rt     000000 sssss ttttt 00000 00000 011010 (not implemented)
    divu  rs, rt     000000 sssss ttttt 00000 00000 011011 (not implemented)
    mfhi  rd         000000 00000 00000 ddddd 00000 010000
    mthi  rs         000000 sssss 00000 00000 00000 010001
    mflo  rd         000000 00000 00000 ddddd 00000 010010
    mtlo  rs         000000 sssss 00000 00000 00000 010011
    mult  rs, rt     000000 sssss ttttt 00000 00000 011000
    multu rs, rt     000000 sssss ttttt 00000 00000 011001
    add   rd, rs, rt 000000 sssss ttttt ddddd 00000 100000
    addu  rd, rs, rt 000000 sssss ttttt ddddd 00000 100001
    sub   rd, rs, rt 000000 sssss ttttt ddddd 00000 100010
    subu  rd, rs, rt 000000 sssss ttttt ddddd 00000 100011
    and   rd, rs, rt 000000 sssss ttttt ddddd 00000 100100
    or    rd, rs, rt 000000 sssss ttttt ddddd 00000 100101
    xor   rd, rs, rt 000000 sssss ttttt ddddd 00000 100110
    nor   rd, rs, rt 000000 sssss ttttt ddddd 00000 100111
    slt   rd, rs, rt 000000 sssss ttttt ddddd 00000 101010
    sltu  rd, rs, rt 000000 sssss ttttt ddddd 00000 101011

I Type
------

    bltz  rt, rs, label 000001 sssss 00000 iiiiiiii iiiiiiii
    bgez  rt, rs, label 000001 sssss 00001 iiiiiiii iiiiiiii
    beq   rt, rs, label 000100 sssss ttttt iiiiiiii iiiiiiii
    bne   rt, rs, label 000101 sssss ttttt iiiiiiii iiiiiiii
    blez  rt, rs, label 000110 sssss 00000 iiiiiiii iiiiiiii
    bgtz  rt, rs, label 000111 sssss 00000 iiiiiiii iiiiiiii
    addi  rt, rs, imm   001000 sssss ttttt iiiiiiii iiiiiiii
    addiu rt, rs, imm   001001 sssss ttttt iiiiiiii iiiiiiii
    slti  rt, rs, imm   001010 sssss ttttt iiiiiiii iiiiiiii
    sltiu rt, rs, imm   001011 sssss ttttt iiiiiiii iiiiiiii
    andi  rt, rs, imm   001100 sssss ttttt iiiiiiii iiiiiiii
    ori   rt, rs, imm   001101 sssss ttttt iiiiiiii iiiiiiii
    xori  rt, rs, imm   001110 sssss ttttt iiiiiiii iiiiiiii
    lui   rt, imm       001111 00000 ttttt iiiiiiii iiiiiiii
    lb    rt, rs, label 100000 sssss ttttt iiiiiiii iiiiiiii
    lh    rt, rs, label 100001 sssss ttttt iiiiiiii iiiiiiii
    lw    rt, rs, label 100011 sssss ttttt iiiiiiii iiiiiiii
    lbu   rt, rs, label 100100 sssss ttttt iiiiiiii iiiiiiii
    lhu   rt, rs, label 100101 sssss ttttt iiiiiiii iiiiiiii
    sb    rt, rs, label 101000 sssss ttttt iiiiiiii iiiiiiii
    sh    rt, rs, label 101001 sssss ttttt iiiiiiii iiiiiiii
    sw    rt, rs, label 101011 sssss ttttt iiiiiiii iiiiiiii

J Type
------

    j   label 000010 ii iiiiiiii iiiiiiii iiiiiiii
    jal label 000011 ii iiiiiiii iiiiiiii iiiiiiii

Registers
=========

    $0         $zero
    $1         $at
    $2  - $3   $v0-$v1
    $4  - $7   $a0-$a3
    $8  - $15  $t0-$t7
    $16 - $23  $s0-$s7
    $24 - $25  $t8-$t9
    $26 - $27  $k0-$k1
    $28        $gp
    $29        $sp
    $30        $fp
    $31        $ra

Memory Map
==========

This implementation of the RISC-V has 4 banks of memory. Each address
contains a 16 bit word instead of 8 bit byte like a typical CPU.

* Bank 0: 0x0000 RAM (4096 bytes)
* Bank 1: 0x4000 ROM
* Bank 2: 0x8000 Peripherals
* Bank 3: 0xc000 RAM (4096 bytes)

On start-up by default, the chip will load a program from a AT93C86A
2kB EEPROM with a 3-Wire (SPI-like) interface but wll run the code
from the ROM. To start the program loaded to RAM, the program select
button needs to be held down while the chip is resetting.

The peripherals area contain the following:

* 0x8000: input from push button
* 0x8004: SPI TX buffer
* 0x8008: SPI RX buffer
* 0x800c: SPI control: bit 2: 8/16, bit 1: start strobe, bit 0: busy
* 0x8020: ioport_A output (in my test case only 1 pin is connected)
* 0x8024: MIDI note value (60-96) to play a tone on the speaker or 0 to stop
* 0x8028: ioport_B output (3 pins)

IO
--

iport_A is just 1 output in my test circuit to an LED.
iport_B is 3 outputs used in my test circuit for SPI (RES/CS/DC) to the LCD.

MIDI
----

The MIDI note peripheral allows the iceFUN board to play tones at specified
frequencies based on MIDI notes.

SPI
---

The SPI peripheral has 3 memory locations. One location for reading
data after it's received, one location for filling the transmit buffer,
and one location for signaling.

For signaling, setting bit 1 to a 1 will cause whatever is in the TX
buffer to be transmitted. Until the data is fully transmitted, bit 0
will be set to 1 to let the user know the SPI bus is busy.

There is also the ability to do 16 bit transfers by setting bit 2 to 1.

