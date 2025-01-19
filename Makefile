
NAKEN_INCLUDE=../naken_asm/include
PROGRAM=mips
SOURCE= \
  src/memory_bus.v \
  src/peripherals.v \
  src/ram.v \
  src/rom.v \
  src/spi.v

default:
	yosys -q -p "synth_ice40 -top $(PROGRAM) -json $(PROGRAM).json" $(SOURCE) src/mips.v
	nextpnr-ice40 -r --hx8k --json $(PROGRAM).json --package cb132 --asc $(PROGRAM).asc --opt-timing --pcf icefun.pcf
	icepack $(PROGRAM).asc $(PROGRAM).bin

program:
	iceFUNprog $(PROGRAM).bin

blink:
	naken_asm -l -type bin -o rom.bin test/blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lcd:
	naken_asm -l -type bin -o rom.bin -I$(NAKEN_INCLUDE) test/lcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

multiply:
	naken_asm -l -type bin -o rom.bin test/multiply.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

store_byte:
	naken_asm -l -type bin -o rom.bin test/store_byte.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

load_byte:
	naken_asm -l -type bin -o rom.bin test/load_byte.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

alu:
	naken_asm -l -type bin -o rom.bin test/alu.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

clean:
	@rm -f $(PROGRAM).bin $(PROGRAM).json $(PROGRAM).asc *.lst
	@rm -f blink.bin load_byte.bin store_byte.bin test_subroutine.bin
	@rm -f button.bin
	@echo "Clean!"

