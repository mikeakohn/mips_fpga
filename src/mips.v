// MIPS FPGA Soft Processor
//  Author: Michael Kohn
//   Email: mike@mikekohn.net
//     Web: https://www.mikekohn.net/
//   Board: iceFUN iCE40 HX8K
// License: MIT
//
// Copyright 2025 by Michael Kohn

module mips
(
  output [7:0] leds,
  output [3:0] column,
  input raw_clk,
  //output eeprom_cs,
  //output eeprom_clk,
  //output eeprom_di,
  //input  eeprom_do,
  output speaker_p,
  output speaker_m,
  output ioport_0,
  output ioport_1,
  output ioport_2,
  output ioport_3,
  input  button_reset,
  input  button_halt,
  input  button_program_select,
  input  button_0,
  output spi_clk,
  output spi_mosi,
  input  spi_miso
);

// iceFUN 8x4 LEDs used for debugging.
reg [7:0] leds_value;
reg [3:0] column_value;

assign leds = leds_value;
assign column = column_value;

// Memory bus (ROM, RAM, peripherals).
reg [15:0] mem_address = 0;
reg [31:0] mem_write = 0;
reg [3:0] mem_write_mask = 0;
wire [31:0] mem_read;
//wire mem_data_ready;
reg mem_bus_enable = 0;
reg mem_write_enable = 0;

//wire [7:0] mem_debug;

// Clock.
reg [21:0] count = 0;
reg [4:0] state = 0;
reg [3:0] clock_div;
reg [14:0] delay_loop;
wire clk;
assign clk = clock_div[0];

// Registers.
reg [31:0] registers [31:0];
reg [15:0] pc = 0;
//reg [15:0] pc_current = 0;

// Instruction
reg [31:0] instruction;
wire [5:0] op;
wire [4:0] rs;
wire [4:0] rt;
wire [4:0] rd;
wire [4:0] sa;
wire [5:0] funct;
wire [15:0] uimm16;
wire signed [15:0] simm16;
wire signed [17:0] branch_offset;
wire [2:0] branch_funct;
reg do_branch;
wire [2:0] memory_size;
assign op = instruction[31:26];
assign rs = instruction[25:21];
assign rt = instruction[20:16];
assign rd = instruction[15:11];
assign sa = instruction[10:6];
assign funct = instruction[5:0];
assign uimm16 = instruction[15:0];
assign simm16 = instruction[15:0];
assign branch_offset = { instruction[15:0], 2'b00 };
assign branch_funct = instruction[28:26];

wire [15:0] branch_address;
assign branch_address = $signed(pc) + branch_offset;
reg do_branch;

reg [31:0] source;
reg [31:0] result;

reg [31:0] hi;
reg [31:0] lo;

reg [3:0] alu_op;
reg [2:0] wb;

// Load / Store.
assign memory_size = instruction[28:26];
wire [31:0] ea;
//reg [31:0] ea_aligned;
assign ea = registers[rs] + simm16;

// Debug.
//reg [7:0] debug_0 = 0;
//reg [7:0] debug_1 = 0;
//reg [7:0] debug_2 = 0;
//reg [7:0] debug_3 = 0;

// This block is simply a clock divider for the raw_clk.
always @(posedge raw_clk) begin
  count <= count + 1;
  clock_div <= clock_div + 1;
end

// Debug: This block simply drives the 8x4 LEDs.
always @(posedge raw_clk) begin
  case (count[9:7])
    3'b000: begin column_value <= 4'b0111; leds_value <= ~registers[9][7:0]; end
    3'b010: begin column_value <= 4'b1011; leds_value <= ~registers[9][15:8]; end
    3'b100: begin column_value <= 4'b1101; leds_value <= ~pc[7:0]; end
    3'b110: begin column_value <= 4'b1110; leds_value <= ~state; end
    default: begin column_value <= 4'b1111; leds_value <= 8'hff; end
  endcase
end

parameter STATE_RESET        = 0;
parameter STATE_DELAY_LOOP   = 1;
parameter STATE_FETCH_OP_0   = 2;
parameter STATE_FETCH_OP_1   = 3;
parameter STATE_START_DECODE = 4;
parameter STATE_FETCH_LOAD   = 5;

parameter STATE_STORE_0      = 6;

parameter STATE_ALU          = 7;
parameter STATE_CONTROL      = 8;

parameter STATE_JUMP         = 9;
parameter STATE_BRANCH       = 10;
parameter STATE_WRITEBACK    = 11;

parameter STATE_DEBUG        = 29;
parameter STATE_ERROR        = 30;
parameter STATE_HALTED       = 31;


parameter ALU_OP_NONE  = 0;
parameter ALU_OP_MOV   = 1;
parameter ALU_OP_ADD   = 2;
parameter ALU_OP_SUB   = 3;
parameter ALU_OP_AND   = 4;
parameter ALU_OP_XOR   = 5;
parameter ALU_OP_NOR   = 6;
parameter ALU_OP_OR    = 7;
parameter ALU_OP_SLL   = 8;
parameter ALU_OP_SRL   = 9;
parameter ALU_OP_SRA   = 10;
parameter ALU_OP_SLT   = 11;
parameter ALU_OP_SLTU  = 12;
parameter ALU_OP_MULS  = 13;
parameter ALU_OP_MULU  = 14;
parameter ALU_OP_LUI   = 15;

parameter WB_NONE  = 0;
parameter WB_RD    = 1;
parameter WB_RT    = 2;
parameter WB_HI    = 3;
parameter WB_LO    = 4;
parameter WB_PC    = 5;
parameter WB_PC_26 = 6;
parameter WB_BR    = 7;

// This block is the main CPU instruction execute state machine.
always @(posedge clk) begin
  if (!button_reset)
    state <= STATE_RESET;
  else if (!button_halt)
    state <= STATE_HALTED;
  else
    case (state)
      STATE_RESET:
        begin
          registers[0] <= 0;
          mem_address <= 0;
          mem_write_enable <= 0;
          mem_write <= 0;
          instruction <= 0;
          delay_loop <= 12000;
          state <= STATE_DELAY_LOOP;
        end
      STATE_DELAY_LOOP:
        begin
          // This is probably not needed. The chip starts up fine without it.
          if (delay_loop == 0) begin
            pc <= 16'h4000;
            state <= STATE_FETCH_OP_0;
          end else begin
            delay_loop <= delay_loop - 1;
          end
        end
      STATE_FETCH_OP_0:
        begin
          wb        <= WB_RD;
          alu_op    <= ALU_OP_NONE;
          do_branch <= 0;
          mem_bus_enable   <= 1;
          //mem_write_enable <= 0;
          mem_address <= pc;
          //pc_current = pc;
          pc <= pc + 4;
          state <= STATE_FETCH_OP_1;
        end
      STATE_FETCH_OP_1:
        begin
          mem_bus_enable <= 0;
          instruction <= mem_read;
          state <= STATE_START_DECODE;
        end
      STATE_START_DECODE:
        begin
          if (op == 6'b000000) begin
            // R Type Instructions.

            case (funct[5:4])
              2'b00:
                if (funct[3] == 0) begin
                  case (funct[1:0])
                    2'b00: alu_op <= ALU_OP_SLL;
                    2'b10: alu_op <= ALU_OP_SRL;
                    2'b11: alu_op <= ALU_OP_SRA;
                  endcase

                  source <= funct[2] == 0 ? sa : registers[rs];
                end
              2'b01:
                case (funct[1:0])
                  2'b00: source <= hi;
                  2'b10: source <= lo;
                  default: source <= registers[rs];
                endcase
              2'b10:
                begin
                  case (funct[2:0])
                    3'b000: alu_op <= ALU_OP_ADD;
                    3'b001: alu_op <= ALU_OP_ADD;
                    3'b010: alu_op <= funct[3] == 0 ? ALU_OP_SUB : ALU_OP_SLT;
                    3'b011: alu_op <= funct[3] == 0 ? ALU_OP_SUB : ALU_OP_SLTU;
                    3'b100: alu_op <= ALU_OP_AND;
                    3'b101: alu_op <= ALU_OP_OR;
                    3'b110: alu_op <= ALU_OP_XOR;
                    3'b111: alu_op <= ALU_OP_NOR;
                  endcase

                  source <= registers[rt];
                end
            endcase

            state <= funct[5:3] == 2'b001 ? STATE_CONTROL : STATE_ALU;
          end else begin
            // I Type and J Type Instructions.

            case (op[5:3])
              3'b000:
                begin
                  if (op[2:0] == 3'b010 || op[2:0] == 3'b011) begin
                    // j and jal.
                    state <= STATE_JUMP;
                  end else begin
                    // bltz, bgez, beq, bne, blez, bgtz.
                    source <= registers[rs];
                    state <= STATE_BRANCH;
                  end
                end
              3'b001:
                begin
                  case (op[2:0])
                    3'b000: alu_op <= ALU_OP_ADD;
                    3'b001: alu_op <= ALU_OP_ADD;
                    3'b010: alu_op <= ALU_OP_SLT;
                    3'b011: alu_op <= ALU_OP_SLTU;
                    3'b100: alu_op <= ALU_OP_AND;
                    3'b101: alu_op <= ALU_OP_OR;
                    3'b110: alu_op <= ALU_OP_XOR;
                    3'b111: alu_op <= ALU_OP_LUI;
                  endcase

                  if (op[2:0] < 3'b011)
                    source <= simm16;
                  else
                    source <= uimm16;

                  state <= STATE_ALU;
                end
              3'b100:
                begin
                  // Load (lb, lbu, lh, lhu, lw).
                  mem_bus_enable <= 1;
                  state <= STATE_FETCH_LOAD;
                end
              3'b101:
                begin
                  // Store (sb, sh, sw).
                  state <= STATE_STORE_0;
                end
            endcase

            wb <= WB_RT;

            // This can probably be a wire.
            //ea <= registers[rs] + simm16;
            //mem_address <= registers[rs] + simm16;
            mem_address <= { ea[15:2], 2'b00 };
          end
        end
      STATE_FETCH_LOAD:
        begin
            mem_bus_enable <= 0;

            case (memory_size[1:0])
              2'b00:
                begin
                  case (ea[1:0])
                    0:
                      begin
                        result[7:0] <= mem_read[7:0];
                        result[31:8] <= { {24{ mem_read[7] & ~memory_size[2] } } };
                      end
                    1:
                      begin
                        result[7:0] <= mem_read[15:8];
                        result[31:8] <= { {24{ mem_read[15] & ~memory_size[2] } } };
                      end
                    2:
                      begin
                        result[7:0] <= mem_read[23:16];
                        result[31:8] <= { {24{ mem_read[23] & ~memory_size[2] } } };
                      end
                    3:
                      begin
                        result[7:0] <= mem_read[31:24];
                        result[31:8] <= { {24{ mem_read[31] & ~memory_size[2] } } };
                      end
                  endcase
                end
              2'b01:
                begin
                  case (ea[1])
                    0:
                      begin
                        result[15:0] <= mem_read[15:0];
                        result[31:16] <= { {16{ mem_read[15] & ~memory_size[2] } } };
                      end
                    1:
                      begin
                        result[15:0] <= mem_read[31:16];
                        result[31:16] <= { {16{ mem_read[31] & ~memory_size[2] } } };
                      end
                  endcase
                end
              2'b11:
                begin
                  result <= mem_read;
                end
            endcase

            state <= STATE_WRITEBACK;
        end
      STATE_STORE_0:
        begin
          case (memory_size[1:0])
            2'b00:
              begin
                mem_write[7:0]   <= registers[rt][7:0];
                mem_write[15:8]  <= registers[rt][7:0];
                mem_write[23:16] <= registers[rt][7:0];
                mem_write[31:24] <= registers[rt][7:0];

                mem_write_mask[0] <= ~(ea[1:0] == 0);
                mem_write_mask[1] <= ~(ea[1:0] == 1);
                mem_write_mask[2] <= ~(ea[1:0] == 2);
                mem_write_mask[3] <= ~(ea[1:0] == 3);
              end
            2'b01:
              begin
                mem_write[15:0]  <= registers[rt][15:0];
                mem_write[31:16] <= registers[rt][15:0];

                mem_write_mask[0] <= ea[1:0] == 2;
                mem_write_mask[1] <= ea[1:0] == 2;
                mem_write_mask[2] <= ea[1:0] == 0;
                mem_write_mask[3] <= ea[1:0] == 0;
              end
            2'b11:
              begin
                mem_write <= registers[rt];
                mem_write_mask <= 4'b0000;
              end
          endcase

          wb <= WB_NONE;
          mem_write_enable <= 1;
          mem_bus_enable <= 1;
          state <= STATE_WRITEBACK;
        end
      STATE_ALU:
        begin
          case (alu_op)
            //ALU_OP_NONE:
            ALU_OP_MOV: result <= source;
            ALU_OP_ADD: result <= registers[rs] + source;
            ALU_OP_SUB: result <= registers[rs] - source;
            ALU_OP_AND: result <= registers[rs] & source;
            ALU_OP_XOR: result <= registers[rs] ^ source;
            ALU_OP_NOR: result <= ~(registers[rs] | source);
            ALU_OP_OR:  result <= registers[rs] | source;
            ALU_OP_SLL: result <= registers[rt] << source;
            ALU_OP_SRL: result <= registers[rt] >> source;
            ALU_OP_SRA: result <= $signed(registers[rt]) >>> source;
            ALU_OP_SLT:
              result <= $signed(registers[rs]) < $signed(source) ? 1 : 0;
            ALU_OP_SLTU: result <= registers[rs] < source ? 1 : 0;
            //ALU_OP_MULS: { hi, lo} <= $signed(registers[rs]) * $signed(source);
            //ALU_OP_MULU: { hi, lo} <= registers[rs] * source;
            ALU_OP_LUI: result <= { source, 16'h0000 };
          endcase

          state <= STATE_WRITEBACK;
        end
      STATE_CONTROL:
        begin
          wb <= WB_PC;

          case (funct[2:0])
            3'b000:
              begin
                // jr rs
                result <= registers[rs];
                state <= STATE_WRITEBACK;
              end
            3'b001:
              begin
                // jalr rd, rs (ignores delay slot).
                registers[31] <= pc + 4;
                state <= STATE_WRITEBACK;
              end
            default:
              // break (101)
              // syscall (100)
              state <= STATE_HALTED;
          endcase
        end
      STATE_JUMP:
        begin
          // jal (ignores delay slot).
          if (op[0] == 1) registers[31] <= pc + 4;

          wb <= WB_PC_26;
          state <= STATE_WRITEBACK;
        end
      STATE_BRANCH:
        begin
          case (branch_funct)
            3'b000:
              // bltz (rt == 0), bgez (rt == 1).
              if (rt == 0)
                if ($signed(source) < 0) do_branch <= 1;
              else
                if ($signed(source) >= 0) do_branch <= 1;
            3'b100:
              // beq.
              if (registers[rt] == source) do_branch <= 1;
            3'b101:
              // bne.
              if (registers[rt] != source) do_branch <= 1;
            3'b110:
              // blez.
              if ($signed(source) <= 0) do_branch <= 1;
            3'b110:
              // bgtz.
              if ($signed(source) > 0) do_branch <= 1;
          endcase

          result <= branch_address;
          wb     <= WB_BR;

          state <= STATE_WRITEBACK;
        end
      STATE_WRITEBACK:
        begin
          case (wb)
            WB_RD: if (rd != 0) registers[rd] <= result;
            WB_RT: if (rt != 0) registers[rt] <= result;
            WB_HI: hi <= result;
            WB_LO: lo <= result;
            WB_PC: pc <= result;
            //WB_PC_26: pc[27:2] <= instruction[25:0];
            WB_PC_26: pc[15:2] <= instruction[13:0];
            WB_BR: if (do_branch) pc <= result;
          endcase

          mem_bus_enable <= 0;
          mem_write_enable <= 0;

          state <= STATE_FETCH_OP_0;
        end
      STATE_DEBUG:
        begin
          state <= STATE_DEBUG;
        end
      STATE_ERROR:
        begin
          state <= STATE_ERROR;
        end
      STATE_HALTED:
        begin
          state <= STATE_HALTED;
        end
    endcase
end

memory_bus memory_bus_0(
  .address      (mem_address),
  .data_in      (mem_write),
  .write_mask   (mem_write_mask),
  .data_out     (mem_read),
  //.debug        (mem_debug),
  //.data_ready   (mem_data_ready),
  .bus_enable   (mem_bus_enable),
  .write_enable (mem_write_enable),
  .clk          (clk),
  .raw_clk      (raw_clk),
  .speaker_p    (speaker_p),
  .speaker_m    (speaker_m),
  .ioport_0     (ioport_0),
  .ioport_1     (ioport_1),
  .ioport_2     (ioport_2),
  .ioport_3     (ioport_3),
  .button_0     (button_0),
  .reset        (~button_reset),
  .spi_clk      (spi_clk),
  .spi_mosi     (spi_mosi),
  .spi_miso     (spi_miso)
);

endmodule

