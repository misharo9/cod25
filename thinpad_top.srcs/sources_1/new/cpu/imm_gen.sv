// 立即数生成器 - 根据指令类型生成符号扩展的立即数
module imm_gen (
    input  wire [31:0] instruction,
    input  wire [ 2:0] imm_type,
    output reg  [31:0] immediate
);

  // 立即数类型
  localparam IMM_I = 3'b000;  // I-type
  localparam IMM_S = 3'b001;  // S-type
  localparam IMM_B = 3'b010;  // B-type
  localparam IMM_U = 3'b011;  // U-type
  localparam IMM_J = 3'b100;  // J-type

  always_comb begin
    case (imm_type)
      IMM_I: begin
        // I-type: imm[11:0] = inst[31:20]
        immediate = {{20{instruction[31]}}, instruction[31:20]};
      end
      
      IMM_S: begin
        // S-type: imm[11:0] = {inst[31:25], inst[11:7]}
        immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
      end
      
      IMM_B: begin
        // B-type: imm[12:0] = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
        immediate = {{19{instruction[31]}}, instruction[31], instruction[7], 
                     instruction[30:25], instruction[11:8], 1'b0};
      end
      
      IMM_U: begin
        // U-type: imm[31:0] = {inst[31:12], 12'b0}
        immediate = {instruction[31:12], 12'b0};
      end
      
      IMM_J: begin
        // J-type: imm[20:0] = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
        immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                     instruction[20], instruction[30:21], 1'b0};
      end
      
      default: immediate = 32'b0;
    endcase
  end

endmodule

