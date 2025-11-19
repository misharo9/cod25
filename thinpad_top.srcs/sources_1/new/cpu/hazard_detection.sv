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
    pc_stall    = 1'b0;
    if_id_stall = 1'b0;
    if_id_flush = 1'b0;
    id_ex_flush = 1'b0;

    // 1. 结构冒险 - MEM阶段等待总线：停顿整个流水线（PC 和前端寄存器）
    //    后端流水线在 cpu_core 中通过 mem_wait 单独停顿
    if (mem_master_wait) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
    end
    // 2. 结构冒险 - IF阶段等待总线：停顿前端（PC 与 IF/ID），
    //    不在总线忙时执行分支/跳转或load-use逻辑，避免在 Wishbone 事务未完成时修改PC
    else if (if_master_wait) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
    end
    // 3. 控制冒险 - 分支/跳转成功：
    //    冲刷 IF/ID 和 ID/EX，PC 在下一周期更新为目标地址（前提是总线不忙）
    else if (branch_taken || jump_taken) begin
      if_id_flush = 1'b1;
      id_ex_flush = 1'b1;
    end
    // 4. 数据冒险 - Load-Use：
    //    停顿PC和IF/ID，在ID/EX插入气泡（与文档中“插入一个气泡”的行为一致）
    else if (load_use_hazard) begin
      pc_stall    = 1'b1;
      if_id_stall = 1'b1;
      id_ex_flush = 1'b1;
    end
  end

endmodule

