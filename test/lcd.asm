.mips
.little_endian

.include "lcd/ssd1331.inc"

;; Set to 0xc000 for eeprom.
;.org 0xc000
.org 0x4000

;; Registers.
BUTTON     equ 0x00
SPI_TX     equ 0x04
SPI_RX     equ 0x08
SPI_CTL    equ 0x0c
PORT0      equ 0x20
SOUND      equ 0x24
SPI_IO     equ 0x28

;; Bits in SPI_CTL.
SPI_BUSY   equ 0x01
SPI_START  equ 0x02
SPI_16     equ 0x04

;; Bits in SPI_IO.
LCD_RES    equ 0x01
LCD_DC     equ 0x02
LCD_CS     equ 0x04

;; Bits in PORT0
LED0       equ 0x01

.define mandel mulw

.macro send_command(value)
  li $a0, value
  jal lcd_send_cmd
  nop
.endm

.macro square_fixed(result, var)
.scope
  move $a1, var
  andi $at, $a1, 0x8000
  beqz $at, not_signed
  nop
  xori $a1, $a1, 0xffff
  addi $a1, $a1, 1
  andi $a1, $a1, 0xffff
not_signed:
  move $a2, $a1
  jal multiply
  nop
  move $a1, $a3
  move result, $a3
.ends
.endm

.macro multiply_signed(var_0, var_1)
.scope
  move $a1, var_0
  move $a2, var_1
  li $t2, 0x0000
  andi $t1, $a1, 0x8000
  beqz $t1, not_signed_0
  nop
  xori $t2, $t2, 1
  xori $a1, $a1, 0xffff
  addi $a1, $a1, 1
  andi $a1, $a1, 0xffff
not_signed_0:
  li $t1, 0x8000
  and $t1, $t1, $a2
  beqz $t1, not_signed_1
  nop
  xori $t2, $t2, 1
  xori $a2, $a2, 0xffff
  addi $a2, $a2, 1
  andi $a2, $a2, 0xffff
not_signed_1:
  jal multiply
  nop
  beqz $t2, dont_add_sign
  nop
  xori $a3, $a3, 0xffff
  addi $a3, $a3, 1
  andi $a3, $a3, 0xffff
dont_add_sign:
.ends
.endm

start:
  ;; Point gp to peripherals.
  li $gp, 0x8000
  ;; Clear LED.
  li $t0, 1
  sw $t0, PORT0($gp)

main:
  jal lcd_init
  nop
  jal lcd_clear
  nop

  li $s2, 0
main_while_1:
  lw $t0, BUTTON($gp)
  andi $t0, $t0, 1
  bnez $t0, run
  nop
  xori $s2, $s2, 1
  sb $s2, PORT0($gp)
  jal delay
  nop
  j main_while_1
  nop

run:
  jal lcd_clear_2
  nop
  jal mandelbrot
  nop
  li $s2, 1
  j main_while_1
  nop

lcd_init:
  move $s1, $ra
  li $t0, LCD_CS
  sw $t0, SPI_IO($gp)
  jal delay
  nop
  li $t0, LCD_CS | LCD_RES
  sw $t0, SPI_IO($gp)

  send_command(SSD1331_DISPLAY_OFF)
  send_command(SSD1331_SET_REMAP)
  send_command(0x72)
  send_command(SSD1331_START_LINE)
  send_command(0x00)
  send_command(SSD1331_DISPLAY_OFFSET)
  send_command(0x00)
  send_command(SSD1331_DISPLAY_NORMAL)
  send_command(SSD1331_SET_MULTIPLEX)
  send_command(0x3f)
  send_command(SSD1331_SET_MASTER)
  send_command(0x8e)
  send_command(SSD1331_POWER_MODE)
  send_command(SSD1331_PRECHARGE)
  send_command(0x31)
  send_command(SSD1331_CLOCKDIV)
  send_command(0xf0)
  send_command(SSD1331_PRECHARGE_A)
  send_command(0x64)
  send_command(SSD1331_PRECHARGE_B)
  send_command(0x78)
  send_command(SSD1331_PRECHARGE_C)
  send_command(0x64)
  send_command(SSD1331_PRECHARGE_LEVEL)
  send_command(0x3a)
  send_command(SSD1331_VCOMH)
  send_command(0x3e)
  send_command(SSD1331_MASTER_CURRENT)
  send_command(0x06)
  send_command(SSD1331_CONTRAST_A)
  send_command(0x91)
  send_command(SSD1331_CONTRAST_B)
  send_command(0x50)
  send_command(SSD1331_CONTRAST_C)
  send_command(0x7d)
  send_command(SSD1331_DISPLAY_ON)
  jr $s1
  nop

lcd_clear:
  move $s1, $ra
  li $t1, 96 * 64
  li $a0, 0xff0f
lcd_clear_loop:
  jal lcd_send_data
  nop
  addi $t1, $t1, -1
  bnez $t1, lcd_clear_loop
  nop
  jr $s1
  nop

lcd_clear_2:
  move $s1, $ra
  li $t1, 96 * 64
  li $a0, 0xf00f
lcd_clear_loop_2:
  jal lcd_send_data
  nop
  addi $t1, $t1, -1
  bnez $t1, lcd_clear_loop_2
  nop
  jr $s1
  nop

;; multiply($a1, $a2) -> $a3
multiply:
  li $a3, 0
  li $t0, 16
multiply_repeat:
  andi $at, $a1, 1
  beqz $at, multiply_ignore_bit
  nop
  addu $a3, $a3, $a2
multiply_ignore_bit:
  sll $a2, $a2, 1
  srl $a1, $a1, 1
  addi $t0, $t0, -1
  bnez $t0, multiply_repeat
  nop
  sra $a3, $a3, 10
  andi $a3, $a3, 0xffff
  jr $ra
  nop

mandelbrot:
  move $s1, $ra

  ;; final int DEC_PLACE = 10;
  ;; final int r0 = (-2 << DEC_PLACE);
  ;; final int i0 = (-1 << DEC_PLACE);
  ;; final int r1 = (1 << DEC_PLACE);
  ;; final int i1 = (1 << DEC_PLACE);
  ;; final int dx = (r1 - r0) / 96; (0x0020)
  ;; final int dy = (i1 - i0) / 64; (0x0020)

  ;; for (y = 0; y < 64; y++)
  li $s3, 64
  ;; int i = -1 << 10;
  li $s5, 0xfc00
mandelbrot_for_y:

  ;; for (x = 0; x < 96; x++)
  li $s2, 96
  ;; int r = -2 << 10;
  li $s4, 0xf800
mandelbrot_for_x:
  ;; zr = r;
  ;; zi = i;
  move $s6, $s4
  move $s7, $s5

  ;; for (int count = 0; count < 15; count++)
  li $a0, 15
mandelbrot_for_count:
  ;; zr2 = (zr * zr) >> DEC_PLACE;
  square_fixed($t6, $s6)

  ;; zi2 = (zi * zi) >> DEC_PLACE;
  square_fixed($t7, $s7)

  ;; if (zr2 + zi2 > (4 << DEC_PLACE)) { break; }
  ;; cmp does: 4 - (zr2 + zi2).. if it's negative it's bigger than 4.
  addu $at, $t6, $t7
  slti $at, $at, 4 << 10
  beqz $at, mandelbrot_stop
  nop

  ;; tr = zr2 - zi2;
  subu $t5, $t6, $t7
  andi $t5, $t5, 0xffff

  ;; ti = ((zr * zi * 2) >> DEC_PLACE) << 1;
  multiply_signed($s6, $s7)
  sll $a3, $a3, 1
  andi $a3, $a3, 0xffff

  ;; zr = tr + curr_r;
  addu $s6, $t5, $s4
  andi $s6, $s6, 0xffff

  ;; zi = ti + curr_i;
  addu $s7, $a3, $s5
  andi $s7, $s7, 0xffff

  addi $a0, $a0, -1
  bnez $a0, mandelbrot_for_count
  nop
mandelbrot_stop:

  sll $a0, $a0, 1
  li $at, colors
  addu $a0, $at, $a0
  lhu $a0, 0($a0)

  jal lcd_send_data
  nop

  addi $s4, $s4, 0x0020
  andi $s4, $s4, 0xffff
  addi $s2, $s2, -1
  bnez $s2, mandelbrot_for_x
  nop

  addi $s5, $s5, 0x0020
  andi $s5, $s5, 0xffff
  addi $s3, $s3, -1
  bnez $s3, mandelbrot_for_y
  nop

  jr $s1
  nop

;; lcd_send_cmd($a0)
lcd_send_cmd:
  li $t0, LCD_RES
  sw $t0, SPI_IO($gp)
  sw $a0, SPI_TX($gp)
  li $t0, SPI_START
  sw $t0, SPI_CTL($gp)
lcd_send_cmd_wait:
  lw $t0, SPI_CTL($gp)
  andi $t0, $t0, SPI_BUSY
  bnez $t0, lcd_send_cmd_wait
  nop
  li $t0, LCD_CS | LCD_RES
  sw $t0, SPI_IO($gp)
  jr $ra
  nop

;; lcd_send_data($a0)
lcd_send_data:
  li $t0, LCD_DC | LCD_RES
  sw $t0, SPI_IO($gp)
  sw $a0, SPI_TX($gp)
  li $t0, SPI_16 | SPI_START
  sw $t0, SPI_CTL($gp)
lcd_send_data_wait:
  lw $t0, SPI_CTL($gp)
  andi $t0, $t0, SPI_BUSY
  bnez $t0, lcd_send_data_wait
  nop
  li $t0, LCD_CS | LCD_RES
  sw $t0, SPI_IO($gp)
  jr $ra
  nop

delay:
  li $t0, 65536
delay_loop:
  addi $t0, $t0, -1
  bnez $t0, delay_loop
  nop
  jr $ra
  nop

;; colors is referenced by address instead of an offset, which makes this
;; program not relocatable.
colors:
  dc16 0x0000
  dc16 0x000c
  dc16 0x0013
  dc16 0x0015
  dc16 0x0195
  dc16 0x0335
  dc16 0x04d5
  dc16 0x34c0
  dc16 0x64c0
  dc16 0x9cc0
  dc16 0x6320
  dc16 0xa980
  dc16 0xaaa0
  dc16 0xcaa0
  dc16 0xe980
  dc16 0xf800

