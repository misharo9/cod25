// IF Master - 指令取指的Wishbone Master接口
// 负责从指令内存中获取指令
module if_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                    clk,
    input  wire                    rst,
    
    // CPU侧接口
    input  wire [ADDR_WIDTH-1:0]   pc,           // 程序计数器
    input  wire                    req,          // 请求信号
    input  wire                    flush,        // 冲刷信号（分支/跳转时取消当前取指）
    output reg  [DATA_WIDTH-1:0]   instruction,  // 返回的指令
    output wire                    wait_flag,    // 等待标志（总线未就绪）
    
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

  typedef enum logic {
    IDLE,
    BUSY
  } state_t;

  state_t state;

  // Wishbone信号和指令寄存器
  always_ff @(posedge clk) begin
    if (rst) begin
      state       <= IDLE;
      wb_adr_o    <= '0;
      wb_dat_o    <= '0;
      wb_we_o     <= 1'b0;
      wb_sel_o    <= '0;
      wb_stb_o    <= 1'b0;
      wb_cyc_o    <= 1'b0;
      instruction <= '0;
    end else if (flush) begin
      // 分支/跳转时，取消当前取指，清除指令寄存器
      wb_stb_o    <= 1'b0;
      wb_cyc_o    <= 1'b0;
      instruction <= 32'h0000_0013;  // 插入NOP（addi x0, x0, 0）
      state       <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (req) begin
            // 发起新的读请求
            wb_adr_o <= pc;
            wb_we_o  <= 1'b0;       // 读操作
            wb_sel_o <= 4'b1111;    // 全字节选择
            wb_stb_o <= 1'b1;
            wb_cyc_o <= 1'b1;
            state    <= BUSY;
          end
        end
        
        BUSY: begin
          if (wb_ack_i) begin
            // 收到应答，锁存指令数据
            instruction <= wb_dat_i;
            wb_stb_o    <= 1'b0;
            wb_cyc_o    <= 1'b0;
            state       <= IDLE;
          end
          // 否则保持BUSY状态，继续等待
        end
      endcase
    end
  end

  // 等待标志：当处于BUSY状态时为高
  assign wait_flag = (state == BUSY);

endmodule


