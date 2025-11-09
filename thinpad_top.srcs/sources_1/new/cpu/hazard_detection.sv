// 冒险检测单元 - 检测load-use冒险和结构冒险，生成停顿信号
module hazard_detection (
    // ID阶段的源寄存器
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    
    // ID/EX阶段的load指令信息
    input  wire [4:0] id_ex_rd,
    input  wire       id_ex_mem_read,
    
    // 分支/跳转控制
    input  wire       branch_taken,
    input  wire       jump_taken,
    
    // Wishbone总线状态
    input  wire       if_master_wait,   // IF阶段等待总线
    input  wire       mem_master_wait,  // MEM阶段等待总线
    
    // 停顿和冲刷控制信号
    output reg        pc_stall,         // PC停顿
    output reg        if_id_stall,      // IF/ID寄存器停顿
    output reg        if_id_flush,      // IF/ID寄存器冲刷
    output reg        id_ex_flush       // ID/EX寄存器冲刷
);

  // Load-Use Hazard检测
  wire load_use_hazard;
  assign load_use_hazard = id_ex_mem_read && 
                           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) &&
                           (id_ex_rd != 5'b0);

  always_comb begin
    // 默认值
    pc_stall    = 1'b0;
    if_id_stall = 1'b0;
    if_id_flush = 1'b0;
    id_ex_flush = 1'b0;

    // 优先处理结构冒险（MEM阶段等待总线时，停顿整个流水线）
    if (mem_master_wait) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
      // ID/EX、EX/MEM、MEM/WB也需要停顿，在CPU核心中通过检查mem_wait处理
    end
    // 处理Load-Use Hazard（当MEM不等待时才处理）
    else if (load_use_hazard) begin
      pc_stall    = 1'b1;  // PC停顿
      if_id_stall = 1'b1;  // IF/ID寄存器保持
      id_ex_flush = 1'b1;  // 在ID/EX插入气泡
    end
    // 处理控制冒险（分支/跳转）（当MEM不等待时才处理）
    else if (branch_taken || jump_taken) begin
      if_id_flush = 1'b1;  // 冲刷IF/ID
      id_ex_flush = 1'b1;  // 冲刷ID/EX
    end
    // 处理结构冒险（IF阶段等待总线时，停顿前端流水线）
    else if (if_master_wait) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
    end
  end

endmodule

