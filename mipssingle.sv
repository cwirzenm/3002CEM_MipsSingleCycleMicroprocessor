// mipssingle.sv

// Single-cycle MIPS processor

module mips(input  logic clk, reset,
            input  logic [31:0] instr, readdata,
            output logic memwrite,
            output logic [31:0] pc, aluout, writedata);

  logic alusrc, regdst, regwrite, jump, pcsrc, zero, gtz, zeroext;
  logic [1:0] memtoreg;
  logic [3:0] alucontrol;

  controller c(zero, gtz, instr[31:26], instr[5:0], 
               memwrite, pcsrc, alusrc, 
               regdst, regwrite, jump, zeroext,
               memtoreg, alucontrol);
  datapath dp(clk, reset,  pcsrc,
              alusrc, regdst, regwrite, jump,
              zeroext, memtoreg, alucontrol,
              instr[10:6], instr, readdata,
              zero, gtz, pc, aluout, writedata);
endmodule

module controller(input  logic zero, gtz,
                  input  logic [5:0] op, funct,
                  output logic memwrite, pcsrc, alusrc,
                  output logic regdst, regwrite, jump, zeroext,
                  output logic [1:0] memtoreg,
                  output logic [3:0] alucontrol);
  
  logic branch, bgtz;
  logic [2:0] aluop;

  maindec md(op, memwrite, branch, alusrc, bgtz, regdst, 
             regwrite, jump, zeroext, aluop, memtoreg);
  aludec  ad(funct, aluop, alucontrol);

  assign pcsrc = (branch & zero) | (bgtz & gtz);
endmodule

module maindec(input  logic [5:0] op,
               output logic memwrite, branch, alusrc, bgtz,
               output logic regdst, regwrite, jump, zeroext,
               output logic [2:0] aluop, 
               output logic [1:0] memtoreg);

  logic [12:0] controls;

  assign {regwrite, regdst, zeroext, alusrc, branch, memwrite,
          memtoreg, jump, aluop, bgtz} = controls;

  always_comb
    case(op)
      6'b000000: controls <= 13'b1100000001000; // RTYPE
      6'b100011: controls <= 13'b1001001000000; // LW
      6'b101011: controls <= 13'b0001010000000; // SW
      6'b000100: controls <= 13'b0000100000010; // BEQ
      6'b001000: controls <= 13'b1001000000000; // ADDI
      6'b000010: controls <= 13'b0000000010000; // J
      6'b000111: controls <= 13'b0000000000011; // BGTZ
      6'b100001: controls <= 13'b1001001100000; // LH
      6'b100100: controls <= 13'b1001000100000; // LBU
      6'b001110: controls <= 13'b1011000000110; // XORI
      6'b001100: controls <= 13'b1011000000100; // ANDI
      default:   controls <= 13'bxxxxxxxxxxxxx; // illegal op
    endcase
endmodule

module aludec(input  logic [5:0] funct,
              input  logic [2:0] aluop,
              output logic [3:0] alucontrol);

  always_comb
    case(aluop)
      3'b000: alucontrol <= 4'b0010;  // add (for lw/sw/addi/lh/lbu)
      3'b001: alucontrol <= 4'b1010;  // sub (for beq/bgtz)
      3'b010: alucontrol <= 4'b0000;  // and (for andi)
      3'b011: alucontrol <= 4'b0110;  // xor (for xori)
      default: case(funct)            // R-type instructions
          6'b100000: alucontrol <= 4'b0010; // add
          6'b100010: alucontrol <= 4'b1010; // sub
          6'b100100: alucontrol <= 4'b0000; // and
          6'b100101: alucontrol <= 4'b0001; // or
          6'b101010: alucontrol <= 4'b1011; // slt
          6'b000010: alucontrol <= 4'b0100; // srl
          6'b001000: alucontrol <= 4'b0101; // jr
          default:   alucontrol <= 4'bxxxx; // ???
        endcase
    endcase
endmodule

module datapath(input  logic clk, reset, pcsrc, alusrc,
                input  logic regdst, regwrite, jump, zeroext,
                input  logic [1:0] memtoreg,
                input  logic [3:0] alucontrol,
                input  logic [4:0] shamt,
                input  logic [31:0] instr, readdata,
                output logic zero, gtz,
                output logic [31:0] pc, aluout, writedata);

  logic jren;
  logic [4:0] writereg;
  logic [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  logic [31:0] zeroimm, signimm, signimmsh, imm, srca, srcb, result, lh, lbu;

  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(imm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc, pcnextbr);
  mux4 #(32)  pcmux(pcnextbr, srca, {pcplus4[31:28], instr[25:0], 2'b00}, 
                    srca, {jump, jren}, pcnext);

  // register file logic
  regfile     rf(clk, regwrite, instr[25:21], instr[20:16], 
                 writereg, result, srca, writedata);
  mux2 #(5)   wrmux(instr[20:16], instr[15:11],
                    regdst, writereg);
  signext     lhext(readdata[15:0], lh);
  zeroext1b   lbuext(readdata[7:0], lbu);
  mux4 #(32)  resmux(aluout, lbu, readdata, lh, memtoreg, result);
  signext     se(instr[15:0], signimm);
  zeroext2b   ze(instr[15:0], zeroimm);
  mux2 #(32)  signorzero(signimm, zeroimm, zeroext, imm);
   
  // ALU logic
  mux2 #(32)  srcbmux(writedata, imm, alusrc, srcb);
  alu         alu(srca, srcb, shamt, alucontrol, aluout, zero, gtz, jren);
endmodule

module regfile(input  logic clk, we3, 
               input  logic [4:0] ra1, ra2, wa3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[31:0];

  always_ff @(posedge clk)
    if (we3) rf[wa3] <= wd3;	

  assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
  assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

module adder(input  logic [31:0] a, b,
             output logic [31:0] y);

  assign y = a + b;
endmodule

module sl2(input  logic [31:0] a,
           output logic [31:0] y);

  // shift left by 2
  assign y = {a[29:0], 2'b00};
endmodule

module signext(input  logic [15:0] a,
               output logic [31:0] y);
              
  assign y = {{16{a[15]}}, a};
endmodule

module zeroext1b(input  logic [7:0] a,
                 output logic [31:0] y);

  assign y = {24'b0, a};
endmodule

module zeroext2b(input  logic [15:0] a,
                 output logic [31:0] y);

  assign y = {16'b0, a};
endmodule

module flopr #(parameter WIDTH = 8)
              (input  logic clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux4 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3,
              input  logic [1:0] s,
              output logic [WIDTH-1:0] y);
              
  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module alu(input  logic [31:0] a, b,
           input  logic [4:0] shamt,
           input  logic [3:0] alucontrol,
           output logic [31:0] result,
           output logic zero, gtz, jren);

  logic [31:0] condinvb, sum;

  assign condinvb = alucontrol[3] ? ~b : b;
  assign sum = a + condinvb + alucontrol[3];

  always_comb
    case (alucontrol[2:0])
      3'b000: result = a & b;
      3'b001: result = a | b;
      3'b010: result = sum;
      3'b011: result = sum[31];
      3'b100: result = b >> shamt;
      3'b110: result = a ^ b;
    endcase
   
  always_comb
    case (alucontrol[3:0])
      4'b0101: jren <= 1;
      default: jren <= 0;
    endcase

  assign zero = (result == 32'b0);
  assign gtz = ~(result[31] | zero);
endmodule
