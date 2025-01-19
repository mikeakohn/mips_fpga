.mips
.little_endian

.org 0x4000
main:
  li $a0, 0xc089
  li $t0, 100

  sb $t0, 1($a0)
  lb $t1, 1($a0)
  ;sh $t1, 0($a0)
  ;lh $t1, 2($a0)

  break

