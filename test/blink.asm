.mips
.little_endian

.org 0x4000
main:
  li $a0, 0x8000

main_loop:
  li $t1, 1
  sb $t1, 0x20($a0)
  jal delay
  nop

  li $t1, 0
  sb $t1, 0x20($a0)
  jal delay
  nop

  j main_loop
  nop

delay:
  li $t0, 0x30000
delay_loop:
  addi $t0, $t0, -1
  bne $t0, $zero, delay_loop
  nop
  jr $ra
  nop

