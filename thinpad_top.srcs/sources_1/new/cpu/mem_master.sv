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

  typedef enum logic {
    IDLE,
    BUSY
  } state_t;

  state_t state;

  wire req = mem_read | mem_write;

  // Wishbone信号和数据寄存器
  always_ff @(posedge clk) begin
    if (rst) begin
      state     <= IDLE;
      wb_adr_o  <= '0;
      wb_dat_o  <= '0;
      wb_we_o   <= 1'b0;
      wb_sel_o  <= '0;
      wb_stb_o  <= 1'b0;
      wb_cyc_o  <= 1'b0;
      read_data <= '0;
    end else begin
      case (state)
        IDLE: begin
          if (req) begin
            // 发起新的访存请求
            wb_adr_o <= addr;
            wb_dat_o <= write_data;
            wb_we_o  <= mem_write;      // 1=写，0=读
            wb_sel_o <= byte_enable;
            wb_stb_o <= 1'b1;
            wb_cyc_o <= 1'b1;
            state    <= BUSY;
          end
        end
        
        BUSY: begin
          if (wb_ack_i) begin
            // 收到应答
            if (!wb_we_o) begin  // 读操作时锁存数据
              read_data <= wb_dat_i;
            end
            wb_stb_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            state    <= IDLE;
          end
          // 否则保持BUSY状态，继续等待
        end
      endcase
    end
  end

  // 等待标志：当处于BUSY状态时为高
  assign wait_flag = (state == BUSY);

endmodule


