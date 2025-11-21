// 冒险检测单元 - 检测load-use冒险、结构冒险和控制冒险，生成停顿/冲刷信号
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
    output reg        id_ex_stall,      // ID/EX寄存器停顿
    output reg        ex_mem_stall,     // EX/MEM寄存器停顿
    output reg        mem_wb_stall,     // MEM/WB寄存器停顿
    output reg        if_id_flush,      // IF/ID寄存器冲刷
    output reg        id_ex_flush       // ID/EX寄存器冲刷
);

  // Load-Use Hazard检测
  wire load_use_hazard;
  assign load_use_hazard = id_ex_mem_read &&
                           (id_ex_rd != 5'b0) &&
                           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

  always_comb begin
    // 默认值：无停顿、无冲刷
    pc_stall     = 1'b0;
    if_id_stall  = 1'b0;
    id_ex_stall  = 1'b0;
    ex_mem_stall = 1'b0;
    mem_wb_stall = 1'b0;
    if_id_flush  = 1'b0;
    id_ex_flush  = 1'b0;

    // 1. 结构冒险 - 总线忙（IF或MEM等待）：停顿整个流水线
    //    参考样例代码：mem_busy时停顿所有阶段
    if (if_master_wait || mem_master_wait) begin
      pc_stall     = 1'b1;
      if_id_stall  = 1'b1;
      id_ex_stall  = 1'b1;
      ex_mem_stall = 1'b1;
      mem_wb_stall = 1'b1;
      // 总线忙时不处理其他冒险
    end
    // 2. 控制冒险 - 分支/跳转成功：
    //    冲刷 IF/ID 和 ID/EX（清除错误路径上的指令）
    else if (branch_taken || jump_taken) begin
      if_id_flush = 1'b1;  // 冲刷IF/ID中可能已取回的错误指令
      id_ex_flush = 1'b1;  // 冲刷ID/EX中的指令
    end
    // 3. 数据冒险 - Load-Use：
    //    停顿PC和IF/ID，在ID/EX插入气泡
    else if (load_use_hazard) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
      id_ex_flush = 1'b1;
    end
  end

endmodule

