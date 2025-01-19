.mips
.little_endian

.org 0x4000

main:
  li $a1, 5
  li $a2, 7
  jal multiply
  nop
  move $t1, $a3
  break

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
  jr $ra
  nop

