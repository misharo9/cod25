// 前递单元 - 检测数据冒险并生成前递信号
module forwarding_unit (
    // EX阶段的源寄存器
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    
    // EX/MEM阶段的目标寄存器和控制信号
    input  wire [4:0] ex_mem_rd,
    input  wire       ex_mem_reg_write,
    
    // MEM/WB阶段的目标寄存器和控制信号
    input  wire [4:0] mem_wb_rd,
    input  wire       mem_wb_reg_write,
    
    // 前递选择信号
    output reg  [1:0] forward_a,  // rs1的前递控制
    output reg  [1:0] forward_b   // rs2的前递控制
);

  // 前递选择编码
  localparam FORWARD_NONE   = 2'b00;  // 不前递，使用ID/EX寄存器的值
  localparam FORWARD_EX_MEM = 2'b01;  // 从EX/MEM阶段前递
  localparam FORWARD_MEM_WB = 2'b10;  // 从MEM/WB阶段前递

  always_comb begin
    // 默认不前递
    forward_a = FORWARD_NONE;
    forward_b = FORWARD_NONE;

    // EX hazard (EX/MEM -> EX)
    // 如果EX/MEM阶段要写寄存器，且目标寄存器不是x0，且与当前EX阶段的rs1匹配
    if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) begin
      forward_a = FORWARD_EX_MEM;
    end
    // MEM hazard (MEM/WB -> EX)
    // 如果MEM/WB阶段要写寄存器，且目标寄存器不是x0，且与当前EX阶段的rs1匹配
    // 注意：EX hazard优先级更高，所以只有在没有EX hazard时才检查MEM hazard
    else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1)) begin
      forward_a = FORWARD_MEM_WB;
    end

    // 同样的逻辑应用于rs2
    if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) begin
      forward_b = FORWARD_EX_MEM;
    end
    else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2)) begin
      forward_b = FORWARD_MEM_WB;
    end
  end

endmodule

