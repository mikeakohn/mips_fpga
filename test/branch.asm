.mips
.little_endian

.org 0x4000
main:
  li $s0, 0x4000
  li $t0, 1

  ;bltz $t0, less_than_zero
  ;bgez $t0, greater_than_eqaul_zero
  ;bgtz $t0, greater_than_zero
  blez $t0, less_than_equal_zero
  li $t1, 7
  break

less_than_zero:
  li $t1, 9
  break

greater_than_eqaul_zero:
  li $t1, 16
  break

greater_than_zero:
  li $t1, 0x80
  break

less_than_equal_zero:
  li $t1, 0x81
  break

