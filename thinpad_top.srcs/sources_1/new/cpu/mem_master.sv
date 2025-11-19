// MEM Master - 数据访存的Wishbone Master接口
// 负责Load/Store指令的内存访问
module mem_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                    clk,
    input  wire                    rst,
    
    // CPU侧接口
    input  wire [ADDR_WIDTH-1:0]   addr,         // 访存地址
    input  wire [DATA_WIDTH-1:0]   write_data,   // 写入数据
    input  wire [DATA_WIDTH/8-1:0] byte_enable,  // 字节使能
    input  wire                    mem_read,     // 读使能
    input  wire                    mem_write,    // 写使能
    output reg  [DATA_WIDTH-1:0]   read_data,    // 读取的数据
    output wire                    wait_flag,    // 等待标志
    
    // Wishbone Master接口
    output reg  [ADDR_WIDTH-1:0]   wb_adr_o,
    input  wire [DATA_WIDTH-1:0]   wb_dat_i,
    output reg  [DATA_WIDTH-1:0]   wb_dat_o,
    output reg                     wb_we_o,
    output reg  [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg                     wb_stb_o,
    input  wire                    wb_ack_i,
    output reg                     wb_cyc_o
);

  // 三态状态机：
  // IDLE:   空闲，等待新的访存请求
  // BUSY:   已经向 Wishbone 发出请求，等待 ACK
  // DONE:   本次访存已经结束，给 CPU 一个周期的缓冲时间更新流水线寄存器
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    BUSY  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t state;

  // 来自 CPU 的访存请求信号（可能在一次访存期间保持为 1）
  wire req = mem_read | mem_write;

  // 使用"已处理"标志来跟踪当前请求是否已被处理
  // 这样可以正确处理连续的访存指令，即使它们有相同的地址和操作类型
  logic req_served;                   // 当前请求是否已被处理
  logic [ADDR_WIDTH-1:0]   addr_d;    // 上一拍的地址
  logic [DATA_WIDTH-1:0]   wdata_d;   // 上一拍的写数据
  logic [DATA_WIDTH/8-1:0] be_d;      // 上一拍的字节使能
  logic mem_write_d;                  // 上一拍的写使能
  
  // 检测访存请求的变化：检查地址、数据、字节使能、操作类型
  wire addr_changed = (addr != addr_d);
  wire data_changed = (write_data != wdata_d);
  wire be_changed   = (byte_enable != be_d);
  wire op_changed   = (mem_write != mem_write_d);
  wire req_changed  = addr_changed || data_changed || be_changed || op_changed;
  
  // 检测新的访存请求：req=1 且 (未被处理 或 请求内容改变)
  wire new_req = req && (!req_served || req_changed);

  // Wishbone信号和数据寄存器
  always_ff @(posedge clk) begin
    if (rst) begin
      state        <= IDLE;
      req_served   <= 1'b0;
      addr_d       <= '0;
      wdata_d      <= '0;
      be_d         <= '0;
      mem_write_d  <= 1'b0;
      wb_adr_o     <= '0;
      wb_dat_o     <= '0;
      wb_we_o      <= 1'b0;
      wb_sel_o     <= '0;
      wb_stb_o     <= 1'b0;
      wb_cyc_o     <= 1'b0;
      read_data    <= '0;
    end else begin
      case (state)
        // 空闲：如果有访存请求，则锁存当前地址/数据/控制信号并向总线发起一次新的请求
        IDLE: begin
          if (new_req) begin
            // 发起新请求时，保存当前请求的信息（用于下次比较）
            addr_d      <= addr;
            wdata_d     <= write_data;
            be_d        <= byte_enable;
            mem_write_d <= mem_write;
            req_served  <= 1'b1;          // 标记请求已被处理
            
            // 锁存地址/数据/控制信号并向总线发起请求
            wb_adr_o    <= addr;
            wb_dat_o    <= write_data;
            wb_we_o     <= mem_write;     // 1=写，0=读
            wb_sel_o    <= byte_enable;
            wb_stb_o    <= 1'b1;
            wb_cyc_o    <= 1'b1;
            state       <= BUSY;
          end else if (!req) begin
            // 如果req=0，清除"已处理"标志
            req_served <= 1'b0;
          end
        end

        // BUSY：等待从设备的 ACK，整个请求期间保持所有 Wishbone 输出不变
        BUSY: begin
          if (wb_ack_i) begin
            // 收到应答
            if (!wb_we_o) begin  // 读操作时锁存数据
              read_data <= wb_dat_i;
            end
            // 结束当前总线周期
            wb_stb_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            // 进入 DONE 状态：给 CPU 一个周期时间，让其更新流水线寄存器
            state    <= DONE;
          end
          // 否则保持 BUSY 状态，继续等待
        end

        // DONE：一次访存已经结束，但本周期内不再接受新的请求
        // 下一拍自动回到 IDLE，此时 CPU 已经将新的访存指令推进到 EX/MEM
        DONE: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // 等待标志：当处于 BUSY 或 DONE 状态时为高
  // DONE 状态需要保持等待，确保流水线寄存器中的旧访存信号完全清除
  // 这样下一次访存请求才能被正确检测（避免 req 信号一直为 1 导致检测不到上升沿）
  assign wait_flag = (state == BUSY) || (state == DONE);

endmodule