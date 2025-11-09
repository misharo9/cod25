// 控制单元 - 根据opcode生成所有控制信号
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    
    // 控制信号
    output reg        reg_write,    // 寄存器写使能
    output reg        mem_read,     // 内存读使能
    output reg        mem_write,    // 内存写使能
    output reg        alu_src,      // ALU第二个操作数来源 (0: rs2, 1: imm)
    output reg        alu_src_a,    // ALU第一个操作数来源 (0: rs1, 1: PC)
    output reg  [1:0] result_src,   // 写回数据来源 (00: ALU, 01: MEM, 10: PC+4)
    output reg  [2:0] imm_type,     // 立即数类型
    output reg  [3:0] alu_op,       // ALU操作码
    output reg        branch,       // 分支指令
    output reg        jump,         // 跳转指令
    output reg        jalr,         // jalr指令
    output reg        lui           // lui指令
);

  // opcode定义
  localparam OP_LUI    = 7'b0110111;
  localparam OP_AUIPC  = 7'b0010111;
  localparam OP_JAL    = 7'b1101111;
  localparam OP_JALR   = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD   = 7'b0000011;
  localparam OP_STORE  = 7'b0100011;
  localparam OP_IMM    = 7'b0010011;
  localparam OP_REG    = 7'b0110011;

  // 立即数类型
  localparam IMM_I = 3'b000;
  localparam IMM_S = 3'b001;
  localparam IMM_B = 3'b010;
  localparam IMM_U = 3'b011;
  localparam IMM_J = 3'b100;

  // ALU操作码
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

  // result_src定义
  localparam RESULT_ALU  = 2'b00;
  localparam RESULT_MEM  = 2'b01;
  localparam RESULT_PC4  = 2'b10;

  always_comb begin
    // 默认值
    reg_write  = 1'b0;
    mem_read   = 1'b0;
    mem_write  = 1'b0;
    alu_src    = 1'b0;
    alu_src_a  = 1'b0;
    result_src = RESULT_ALU;
    imm_type   = IMM_I;
    alu_op     = ALU_ADD;
    branch     = 1'b0;
    jump       = 1'b0;
    jalr       = 1'b0;
    lui        = 1'b0;

    case (opcode)
      OP_LUI: begin
        // LUI: rd = imm (实际上是0 + imm)
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        alu_src_a  = 1'b0;  // 不使用
        imm_type   = IMM_U;
        alu_op     = ALU_ADD;
        result_src = RESULT_ALU;
        lui        = 1'b1;
      end

      OP_AUIPC: begin
        // AUIPC: rd = PC + imm
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        alu_src_a  = 1'b1;  // 使用PC
        imm_type   = IMM_U;
        alu_op     = ALU_ADD;
        result_src = RESULT_ALU;
      end

      OP_JAL: begin
        // JAL: rd = PC + 4, PC = PC + imm
        reg_write  = 1'b1;
        jump       = 1'b1;
        imm_type   = IMM_J;
        result_src = RESULT_PC4;
      end

      OP_JALR: begin
        // JALR: rd = PC + 4, PC = rs1 + imm
        reg_write  = 1'b1;
        jalr       = 1'b1;
        jump       = 1'b1;
        alu_src    = 1'b1;
        imm_type   = IMM_I;
        result_src = RESULT_PC4;
      end

      OP_BRANCH: begin
        // Branch指令
        branch   = 1'b1;
        imm_type = IMM_B;
        case (funct3)
          3'b000:  alu_op = ALU_SUB;  // BEQ
          3'b001:  alu_op = ALU_SUB;  // BNE
          3'b100:  alu_op = ALU_SLT;  // BLT
          3'b101:  alu_op = ALU_SLT;  // BGE
          3'b110:  alu_op = ALU_SLTU; // BLTU
          3'b111:  alu_op = ALU_SLTU; // BGEU
          default: alu_op = ALU_SUB;
        endcase
      end

      OP_LOAD: begin
        // Load指令
        reg_write  = 1'b1;
        mem_read   = 1'b1;
        alu_src    = 1'b1;
        imm_type   = IMM_I;
        alu_op     = ALU_ADD;
        result_src = RESULT_MEM;
      end

      OP_STORE: begin
        // Store指令
        mem_write = 1'b1;
        alu_src   = 1'b1;
        imm_type  = IMM_S;
        alu_op    = ALU_ADD;
      end

      OP_IMM: begin
        // 立即数运算指令
        reg_write  = 1'b1;
        alu_src    = 1'b1;
        imm_type   = IMM_I;
        result_src = RESULT_ALU;
        case (funct3)
          3'b000:  alu_op = ALU_ADD;  // ADDI
          3'b010:  alu_op = ALU_SLT;  // SLTI
          3'b011:  alu_op = ALU_SLTU; // SLTIU
          3'b100:  alu_op = ALU_XOR;  // XORI
          3'b110:  alu_op = ALU_OR;   // ORI
          3'b111:  alu_op = ALU_AND;  // ANDI
          3'b001:  alu_op = ALU_SLL;  // SLLI
          3'b101: begin
            if (funct7[5]) alu_op = ALU_SRA;  // SRAI
            else           alu_op = ALU_SRL;  // SRLI
          end
          default: alu_op = ALU_ADD;
        endcase
      end

      OP_REG: begin
        // 寄存器运算指令
        reg_write  = 1'b1;
        alu_src    = 1'b0;
        result_src = RESULT_ALU;
        case (funct3)
          3'b000: begin
            if (funct7[5]) alu_op = ALU_SUB;  // SUB
            else           alu_op = ALU_ADD;  // ADD
          end
          3'b001:  alu_op = ALU_SLL;  // SLL
          3'b010:  alu_op = ALU_SLT;  // SLT
          3'b011:  alu_op = ALU_SLTU; // SLTU
          3'b100:  alu_op = ALU_XOR;  // XOR
          3'b101: begin
            if (funct7[5]) alu_op = ALU_SRA;  // SRA
            else           alu_op = ALU_SRL;  // SRL
          end
          3'b110:  alu_op = ALU_OR;   // OR
          3'b111:  alu_op = ALU_AND;  // AND
          default: alu_op = ALU_ADD;
        endcase
      end

      default: begin
        // NOP
        reg_write = 1'b0;
      end
    endcase
  end

endmodule

