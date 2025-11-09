// ALU - 算术逻辑单元
// 支持RV32I所需的所有ALU操作
module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [ 3:0] alu_op,
    output reg  [31:0] alu_result,
    output wire        zero_flag
);

  // ALU操作码定义
  localparam ALU_ADD  = 4'b0000;
  localparam ALU_SUB  = 4'b0001;
  localparam ALU_SLL  = 4'b0010;
  localparam ALU_SLT  = 4'b0011;
  localparam ALU_SLTU = 4'b0100;
  localparam ALU_XOR  = 4'b0101;
  localparam ALU_SRL  = 4'b0110;
  localparam ALU_SRA  = 4'b0111;
  localparam ALU_OR   = 4'b1000;
  localparam ALU_AND  = 4'b1001;

  always_comb begin
    case (alu_op)
      ALU_ADD:  alu_result = operand_a + operand_b;
      ALU_SUB:  alu_result = operand_a - operand_b;
      ALU_SLL:  alu_result = operand_a << operand_b[4:0];
      ALU_SLT:  alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'b1 : 32'b0;
      ALU_SLTU: alu_result = (operand_a < operand_b) ? 32'b1 : 32'b0;
      ALU_XOR:  alu_result = operand_a ^ operand_b;
      ALU_SRL:  alu_result = operand_a >> operand_b[4:0];
      ALU_SRA:  alu_result = $signed(operand_a) >>> operand_b[4:0];
      ALU_OR:   alu_result = operand_a | operand_b;
      ALU_AND:  alu_result = operand_a & operand_b;
      default:  alu_result = 32'b0;
    endcase
  end

  assign zero_flag = (alu_result == 32'b0);

endmodule

