// CPU核心 - 五级流水线RV32I处理器
module cpu_core #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire clk,
    input  wire rst,
    
    // IF Master接口
    output wire [ADDR_WIDTH-1:0]   if_wb_adr_o,
    input  wire [DATA_WIDTH-1:0]   if_wb_dat_i,
    output wire [DATA_WIDTH-1:0]   if_wb_dat_o,
    output wire                    if_wb_we_o,
    output wire [DATA_WIDTH/8-1:0] if_wb_sel_o,
    output wire                    if_wb_stb_o,
    input  wire                    if_wb_ack_i,
    output wire                    if_wb_cyc_o,
    
    // MEM Master接口
    output wire [ADDR_WIDTH-1:0]   mem_wb_adr_o,
    input  wire [DATA_WIDTH-1:0]   mem_wb_dat_i,
    output wire [DATA_WIDTH-1:0]   mem_wb_dat_o,
    output wire                    mem_wb_we_o,
    output wire [DATA_WIDTH/8-1:0] mem_wb_sel_o,
    output wire                    mem_wb_stb_o,
    input  wire                    mem_wb_ack_i,
    output wire                    mem_wb_cyc_o
);

  // =========== Pipeline Wires and Registers ===========
  // Hazard Control Signals
  wire pc_stall;
  wire if_id_stall;
  wire if_id_flush;
  wire id_ex_flush;

  // IF/ID Pipeline Register
  reg [31:0] if_id_pc;
  reg [31:0] if_id_pc_plus_4;
  reg [31:0] if_id_instruction;
  
  // ID/EX Pipeline Register
  reg [31:0] id_ex_pc;
  reg [31:0] id_ex_pc_plus_4;
  reg [31:0] id_ex_rs1_data;
  reg [31:0] id_ex_rs2_data;
  reg [31:0] id_ex_immediate;
  reg [4:0]  id_ex_rs1;
  reg [4:0]  id_ex_rs2;
  reg [4:0]  id_ex_rd;
  reg [2:0]  id_ex_funct3;
  reg        id_ex_reg_write;
  reg        id_ex_mem_read;
  reg        id_ex_mem_write;
  reg        id_ex_alu_src;
  reg        id_ex_alu_src_a;
  reg [1:0]  id_ex_result_src;
  reg [3:0]  id_ex_alu_op;
  reg        id_ex_branch;
  reg        id_ex_jump;
  reg        id_ex_jalr;
  reg        id_ex_lui;
  
  // EX/MEM Pipeline Register
  reg [31:0] ex_mem_alu_result;
  reg [31:0] ex_mem_rs2_data;
  reg [31:0] ex_mem_pc_plus_4;
  reg [4:0]  ex_mem_rd;
  reg [2:0]  ex_mem_funct3;
  reg        ex_mem_reg_write;
  reg        ex_mem_mem_read;
  reg        ex_mem_mem_write;
  reg [1:0]  ex_mem_result_src;
  
  // MEM/WB Pipeline Register
  reg [31:0] mem_wb_alu_result;
  reg [31:0] mem_wb_mem_data;
  reg [31:0] mem_wb_pc_plus_4;
  reg [4:0]  mem_wb_rd;
  reg [2:0]  mem_wb_funct3;
  reg        mem_wb_reg_write;
  reg [1:0]  mem_wb_result_src;

  // =========== IF Stage ===========
  reg  [31:0] pc_reg;
  reg  [31:0] if_pc_reg;  // IF阶段指令对应的PC（在取指请求时锁存）
  wire [31:0] pc_next;
  wire [31:0] pc_plus_4;
  wire [31:0] if_instruction;
  wire        if_wait;
  wire        if_req;
  
  assign pc_plus_4 = pc_reg + 4;
  // IF Master内部有状态机控制，只有在IDLE状态时才会响应req信号发起新请求
  // 因此可以保持if_req始终为真（除了复位）
  assign if_req = !rst;
  
  // IF Master实例
  if_master u_if_master (
    .clk(clk),
    .rst(rst),
    .pc(pc_reg),
    .req(if_req),
    .flush(if_id_flush),  // 当IF/ID需要flush时，也取消IF Master的取指
    .instruction(if_instruction),
    .wait_flag(if_wait),
    .wb_adr_o(if_wb_adr_o),
    .wb_dat_i(if_wb_dat_i),
    .wb_dat_o(if_wb_dat_o),
    .wb_we_o(if_wb_we_o),
    .wb_sel_o(if_wb_sel_o),
    .wb_stb_o(if_wb_stb_o),
    .wb_ack_i(if_wb_ack_i),
    .wb_cyc_o(if_wb_cyc_o)
  );
  
  // =========== IF/ID Pipeline Register ===========
  
  // =========== ID Stage ===========
  wire [6:0]  id_opcode;
  wire [4:0]  id_rd;
  wire [2:0]  id_funct3;
  wire [4:0]  id_rs1;
  wire [4:0]  id_rs2;
  wire [6:0]  id_funct7;
  
  assign id_opcode = if_id_instruction[6:0];
  assign id_rd     = if_id_instruction[11:7];
  assign id_funct3 = if_id_instruction[14:12];
  assign id_rs1    = if_id_instruction[19:15];
  assign id_rs2    = if_id_instruction[24:20];
  assign id_funct7 = if_id_instruction[31:25];
  
  // 控制信号
  wire        id_reg_write;
  wire        id_mem_read;
  wire        id_mem_write;
  wire        id_alu_src;
  wire        id_alu_src_a;
  wire [1:0]  id_result_src;
  wire [2:0]  id_imm_type;
  wire [3:0]  id_alu_op;
  wire        id_branch;
  wire        id_jump;
  wire        id_jalr;
  wire        id_lui;
  
  // 控制单元
  control u_control (
    .opcode(id_opcode),
    .funct3(id_funct3),
    .funct7(id_funct7),
    .reg_write(id_reg_write),
    .mem_read(id_mem_read),
    .mem_write(id_mem_write),
    .alu_src(id_alu_src),
    .alu_src_a(id_alu_src_a),
    .result_src(id_result_src),
    .imm_type(id_imm_type),
    .alu_op(id_alu_op),
    .branch(id_branch),
    .jump(id_jump),
    .jalr(id_jalr),
    .lui(id_lui)
  );
  
  // 立即数生成
  wire [31:0] id_immediate;
  imm_gen u_imm_gen (
    .instruction(if_id_instruction),
    .imm_type(id_imm_type),
    .immediate(id_immediate)
  );
  
  // 寄存器堆
  wire [31:0] id_rs1_data;
  wire [31:0] id_rs2_data;
  wire [4:0]  wb_rd_addr;
  wire [31:0] wb_rd_data;
  wire        wb_reg_write;
  
  regfile u_regfile (
    .clk(clk),
    .rst(rst),
    .rs1_addr(id_rs1),
    .rs1_data(id_rs1_data),
    .rs2_addr(id_rs2),
    .rs2_data(id_rs2_data),
    .rd_addr(wb_rd_addr),
    .rd_data(wb_rd_data),
    .reg_write(wb_reg_write)
  );
  
  // =========== ID/EX Pipeline Register ===========
  
  // =========== EX Stage ===========
  // 前递
  wire [1:0] forward_a;
  wire [1:0] forward_b;
  wire [31:0] ex_operand_a;
  wire [31:0] ex_operand_b_forwarded;
  wire [31:0] ex_operand_b;
  wire [31:0] ex_alu_result;
  
  // 前递单元
  forwarding_unit u_forwarding (
    .id_ex_rs1(id_ex_rs1),
    .id_ex_rs2(id_ex_rs2),
    .ex_mem_rd(ex_mem_rd),
    .ex_mem_reg_write(ex_mem_reg_write),
    // MEM/WB 阶段的前递直接使用流水线寄存器中的信息，
    // 避免被写回路径上的额外条件（如 mem_wait）屏蔽，从而导致使用旧值。
    .mem_wb_rd(mem_wb_rd),
    .mem_wb_reg_write(mem_wb_reg_write),
    .forward_a(forward_a),
    .forward_b(forward_b)
  );
  
  // 前递多路选择器
  assign ex_operand_a = (forward_a == 2'b00) ? id_ex_rs1_data :
                        (forward_a == 2'b01) ? ex_mem_alu_result :
                        wb_rd_data;
                        
  assign ex_operand_b_forwarded = (forward_b == 2'b00) ? id_ex_rs2_data :
                                  (forward_b == 2'b01) ? ex_mem_alu_result :
                                  wb_rd_data;
  
  // ALU源操作数选择
  assign ex_operand_b = id_ex_alu_src ? id_ex_immediate : ex_operand_b_forwarded;
  
  // ALU
  wire ex_zero;
  
  // ALU第一个操作数选择
  // LUI: 0 + imm
  // AUIPC: PC + imm
  // 其他: rs1_data + ...
  wire [31:0] ex_alu_operand_a;
  assign ex_alu_operand_a = id_ex_lui       ? 32'b0 :
                            id_ex_alu_src_a ? id_ex_pc :
                            ex_operand_a;
  
  alu u_alu (
    .operand_a(ex_alu_operand_a),
    .operand_b(ex_operand_b),
    .alu_op(id_ex_alu_op),
    .alu_result(ex_alu_result),
    .zero_flag(ex_zero)
  );
  
  // 分支判断
  wire ex_branch_taken;
  branch_unit u_branch (
    .funct3(id_ex_funct3),
    .rs1_data(ex_operand_a),
    .rs2_data(ex_operand_b_forwarded),
    .branch(id_ex_branch),
    .branch_taken(ex_branch_taken)
  );
  
  // 跳转和分支目标地址
  wire [31:0] ex_branch_target;
  wire [31:0] ex_jump_target;
  wire        ex_pc_src;
  
  assign ex_branch_target = id_ex_pc + id_ex_immediate;
  assign ex_jump_target = id_ex_jalr ? (ex_alu_result & ~32'b1) : ex_branch_target;
  assign ex_pc_src = (ex_branch_taken || id_ex_jump || id_ex_jalr);
  
  // =========== MEM Stage ===========
  wire [31:0] mem_read_data_raw;
  wire        mem_wait;
  wire [3:0]  mem_byte_enable;
  wire [31:0] mem_write_data;
  
  // 字节使能生成（根据funct3和地址低2位）
  assign mem_byte_enable = (ex_mem_funct3 == 3'b000) ? (4'b0001 << ex_mem_alu_result[1:0]) :  // LB/SB
                           (ex_mem_funct3 == 3'b001) ? (4'b0011 << ex_mem_alu_result[1:0]) :  // LH/SH
                           (ex_mem_funct3 == 3'b010) ? 4'b1111 :                               // LW/SW
                           4'b1111;
  
  // Store数据对齐
  assign mem_write_data = (ex_mem_funct3 == 3'b000) ? {4{ex_mem_rs2_data[7:0]}} :   // SB
                          (ex_mem_funct3 == 3'b001) ? {2{ex_mem_rs2_data[15:0]}} :  // SH
                          ex_mem_rs2_data;                                            // SW
  
  // MEM Master实例
  mem_master u_mem_master (
    .clk(clk),
    .rst(rst),
    .addr(ex_mem_alu_result),
    .write_data(mem_write_data),
    .byte_enable(mem_byte_enable),
    .mem_read(ex_mem_mem_read),
    .mem_write(ex_mem_mem_write),
    .read_data(mem_read_data_raw),
    .wait_flag(mem_wait),
    .wb_adr_o(mem_wb_adr_o),
    .wb_dat_i(mem_wb_dat_i),
    .wb_dat_o(mem_wb_dat_o),
    .wb_we_o(mem_wb_we_o),
    .wb_sel_o(mem_wb_sel_o),
    .wb_stb_o(mem_wb_stb_o),
    .wb_ack_i(mem_wb_ack_i),
    .wb_cyc_o(mem_wb_cyc_o)
  );
  
  // =========== MEM/WB Pipeline Register ===========
  
  // =========== WB Stage ===========
  logic [31:0] wb_mem_data_aligned;
  
  // Load数据对齐和符号扩展
  always_comb begin
    case (mem_wb_funct3)
      3'b000: begin  // LB
        case (mem_wb_alu_result[1:0])
          2'b00: wb_mem_data_aligned = {{24{mem_wb_mem_data[7]}}, mem_wb_mem_data[7:0]};
          2'b01: wb_mem_data_aligned = {{24{mem_wb_mem_data[15]}}, mem_wb_mem_data[15:8]};
          2'b10: wb_mem_data_aligned = {{24{mem_wb_mem_data[23]}}, mem_wb_mem_data[23:16]};
          2'b11: wb_mem_data_aligned = {{24{mem_wb_mem_data[31]}}, mem_wb_mem_data[31:24]};
        endcase
      end
      3'b001: begin  // LH
        case (mem_wb_alu_result[1])
          1'b0: wb_mem_data_aligned = {{16{mem_wb_mem_data[15]}}, mem_wb_mem_data[15:0]};
          1'b1: wb_mem_data_aligned = {{16{mem_wb_mem_data[31]}}, mem_wb_mem_data[31:16]};
        endcase
      end
      3'b010: wb_mem_data_aligned = mem_wb_mem_data;  // LW
      3'b100: begin  // LBU
        case (mem_wb_alu_result[1:0])
          2'b00: wb_mem_data_aligned = {24'b0, mem_wb_mem_data[7:0]};
          2'b01: wb_mem_data_aligned = {24'b0, mem_wb_mem_data[15:8]};
          2'b10: wb_mem_data_aligned = {24'b0, mem_wb_mem_data[23:16]};
          2'b11: wb_mem_data_aligned = {24'b0, mem_wb_mem_data[31:24]};
        endcase
      end
      3'b101: begin  // LHU
        case (mem_wb_alu_result[1])
          1'b0: wb_mem_data_aligned = {16'b0, mem_wb_mem_data[15:0]};
          1'b1: wb_mem_data_aligned = {16'b0, mem_wb_mem_data[31:16]};
        endcase
      end
      default: wb_mem_data_aligned = mem_wb_mem_data;
    endcase
  end
  
  // 写回数据选择
  assign wb_rd_data = (mem_wb_result_src == 2'b00) ? mem_wb_alu_result :
                      (mem_wb_result_src == 2'b01) ? wb_mem_data_aligned :
                      mem_wb_pc_plus_4;
  
  assign wb_rd_addr = mem_wb_rd;
  // 写回使能直接来自 MEM/WB 寄存器
  // 当流水线因为 mem_wait 停顿时，MEM/WB 也被冻结，多次写回相同值是安全的
  assign wb_reg_write = mem_wb_reg_write;
  
  // =========== 冒险检测 ===========
  
  hazard_detection u_hazard (
    .if_id_rs1(id_rs1),
    .if_id_rs2(id_rs2),
    .id_ex_rd(id_ex_rd),
    .id_ex_mem_read(id_ex_mem_read),
    .branch_taken(ex_branch_taken),
    .jump_taken(id_ex_jump || id_ex_jalr),
    .if_master_wait(if_wait),
    .mem_master_wait(mem_wait),
    .pc_stall(pc_stall),
    .if_id_stall(if_id_stall),
    .if_id_flush(if_id_flush),
    .id_ex_flush(id_ex_flush)
  );
  
  // =========== PC更新 ===========
  assign pc_next = ex_pc_src ? ex_jump_target : pc_plus_4;

  always_ff @(posedge clk) begin
    if (rst) begin
      pc_reg <= 32'h8000_0000;  // 复位PC到BaseRAM起始地址
    end else if (!pc_stall) begin
      // 只有在没有PC停顿时才更新PC
      // pc_stall由hazard_detection单元控制，会在需要时停顿PC
      pc_reg <= pc_next;
    end
  end
  
  // IF阶段PC锁存：在IF Master不等待时更新，等待时保持（确保对应正在取的指令）
  always_ff @(posedge clk) begin
    if (rst) begin
      if_pc_reg <= 32'h8000_0000;
    end else if (!if_wait) begin
      // 当IF Master不在等待时（IDLE或刚完成取指），更新为当前PC
      // 这样在IF Master发起新请求时，if_pc_reg对应该请求的地址
      if_pc_reg <= pc_reg;
    end
    // 当IF Master在等待时（BUSY），if_pc_reg保持不变，锁存正在取指的地址
  end
  
  // =========== 流水线寄存器更新 ===========
  // IF/ID
  always_ff @(posedge clk) begin
    if (rst || if_id_flush) begin
      if_id_pc <= 32'b0;
      if_id_pc_plus_4 <= 32'b0;
      if_id_instruction <= 32'h0000_0013;  // NOP指令
    end else if (!if_id_stall && !if_wait) begin
      // 正常更新 - 使用if_pc_reg而不是pc_reg，确保PC值对应正在取的指令
      // 注意：不需要检查mem_wait，因为如果mem_wait为真，if_id_stall也会为真
      if_id_pc <= if_pc_reg;
      if_id_pc_plus_4 <= if_pc_reg + 4;
      if_id_instruction <= if_instruction;
    end
    // 如果有stall/wait，IF/ID保持不变（隐式的else，什么都不做）
  end
  
  // ID/EX
  always_ff @(posedge clk) begin
    if (rst || id_ex_flush) begin
      id_ex_pc <= 32'b0;
      id_ex_pc_plus_4 <= 32'b0;
      id_ex_rs1_data <= 32'b0;
      id_ex_rs2_data <= 32'b0;
      id_ex_immediate <= 32'b0;
      id_ex_rs1 <= 5'b0;
      id_ex_rs2 <= 5'b0;
      id_ex_rd <= 5'b0;
      id_ex_funct3 <= 3'b0;
      id_ex_reg_write <= 1'b0;
      id_ex_mem_read <= 1'b0;
      id_ex_mem_write <= 1'b0;
      id_ex_alu_src <= 1'b0;
      id_ex_alu_src_a <= 1'b0;
      id_ex_result_src <= 2'b0;
      id_ex_alu_op <= 4'b0;
      id_ex_branch <= 1'b0;
      id_ex_jump <= 1'b0;
      id_ex_jalr <= 1'b0;
      id_ex_lui <= 1'b0;
    end else if (!if_id_stall) begin
      // ID/EX在IF/ID不停顿时更新
      // 如果IF/ID停顿，ID/EX也必须停顿，否则会重复执行IF/ID中的指令
      // 注意：mem_wait会导致if_id_stall，因此不需要单独检查mem_wait
      id_ex_pc <= if_id_pc;
      id_ex_pc_plus_4 <= if_id_pc_plus_4;
      id_ex_rs1_data <= id_rs1_data;
      id_ex_rs2_data <= id_rs2_data;
      id_ex_immediate <= id_immediate;
      id_ex_rs1 <= id_rs1;
      id_ex_rs2 <= id_rs2;
      id_ex_rd <= id_rd;
      id_ex_funct3 <= id_funct3;
      id_ex_reg_write <= id_reg_write;
      id_ex_mem_read <= id_mem_read;
      id_ex_mem_write <= id_mem_write;
      id_ex_alu_src <= id_alu_src;
      id_ex_alu_src_a <= id_alu_src_a;
      id_ex_result_src <= id_result_src;
      id_ex_alu_op <= id_alu_op;
      id_ex_branch <= id_branch;
      id_ex_jump <= id_jump;
      id_ex_jalr <= id_jalr;
      id_ex_lui <= id_lui;
    end
    // 否则：停顿（保持不变）
  end
  
  // EX/MEM
  always_ff @(posedge clk) begin
    if (rst) begin
      ex_mem_alu_result <= 32'b0;
      ex_mem_rs2_data <= 32'b0;
      ex_mem_pc_plus_4 <= 32'b0;
      ex_mem_rd <= 5'b0;
      ex_mem_funct3 <= 3'b0;
      ex_mem_reg_write <= 1'b0;
      ex_mem_mem_read <= 1'b0;
      ex_mem_mem_write <= 1'b0;
      ex_mem_result_src <= 2'b0;
    end else if (!mem_wait && !if_id_stall) begin
      // 正常更新：当MEM不等待且流水线不停顿时
      ex_mem_alu_result <= ex_alu_result;
      ex_mem_rs2_data <= ex_operand_b_forwarded;
      ex_mem_pc_plus_4 <= id_ex_pc_plus_4;
      ex_mem_rd <= id_ex_rd;
      ex_mem_funct3 <= id_ex_funct3;
      ex_mem_reg_write <= id_ex_reg_write;
      ex_mem_mem_read <= id_ex_mem_read;
      ex_mem_mem_write <= id_ex_mem_write;
      ex_mem_result_src <= id_ex_result_src;
    end
    // 否则：mem_wait=1或停顿时保持不变
  end
  
  // MEM/WB
  always_ff @(posedge clk) begin
    if (rst) begin
      mem_wb_alu_result <= 32'b0;
      mem_wb_mem_data <= 32'b0;
      mem_wb_pc_plus_4 <= 32'b0;
      mem_wb_rd <= 5'b0;
      mem_wb_funct3 <= 3'b0;
      mem_wb_reg_write <= 1'b0;
      mem_wb_result_src <= 2'b0;
    end else if (!mem_wait && !if_id_stall) begin
      // MEM/WB更新：在MEM不等待且IF/ID不停顿时更新
      // 当访存完成时（mem_wait变为假），立即更新以获取访存结果
      mem_wb_alu_result <= ex_mem_alu_result;
      mem_wb_mem_data <= mem_read_data_raw;
      mem_wb_pc_plus_4 <= ex_mem_pc_plus_4;
      mem_wb_rd <= ex_mem_rd;
      mem_wb_funct3 <= ex_mem_funct3;
      mem_wb_reg_write <= ex_mem_reg_write;
      mem_wb_result_src <= ex_mem_result_src;
    end
  end

endmodule

