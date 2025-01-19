.mips
.little_endian

.org 0x4000
main:
  li $s0, 0x4000
  lh $t1, 6($s0)
  ;lb $t1, -3($s0)
  break

