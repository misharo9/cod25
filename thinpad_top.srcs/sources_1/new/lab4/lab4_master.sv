module lab4_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,

    // TODO: 添加需要的控制信号，例如按键开关？
    input wire [ADDR_WIDTH-1:0] dip_sw,

    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

  // TODO: 实现实验 5 的内存+串口 Master
  typedef enum logic [3:0] {
    IDLE,
    READ_WAIT_ACTION,
    READ_WAIT_CHECK,
    READ_DATA_ACTION,
    READ_DATA_DONE,
    WRITE_SRAM_ACTION,
    WRITE_SRAM_DONE,
    WRITE_WAIT_ACTION,
    WRITE_WAIT_CHECK,
    WRITE_DATA_ACTION,
    WRITE_DATA_DONE
  } state_t;

  state_t state;
  logic [ADDR_WIDTH-1:0] addr;
  logic [3:0] i;
  logic [DATA_WIDTH-1:0] data;
  logic [DATA_WIDTH-1:0] write_data;
  logic [1:0] offset;
  parameter [ADDR_WIDTH-1:0] serial_state_reg = 32'h1000_0005;
  parameter [ADDR_WIDTH-1:0] serial_data_reg = 32'h1000_0000;
  parameter [DATA_WIDTH/8-1:0] serial_state_sel = 4'b0010;
  parameter [DATA_WIDTH/8-1:0] serial_data_sel = 4'b0001;
  parameter [DATA_WIDTH/8-1:0] sram_write_sel = 4'b0001;
  parameter [DATA_WIDTH-1:0] serial_read_ready = 32'h0000_0100;
  parameter [DATA_WIDTH-1:0] serial_write_ready = 32'h0000_2000;

  assign offset = addr[1:0];

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state <= IDLE;
      wb_cyc_o <= 1'b0;
      wb_stb_o <= 1'b0;
      wb_adr_o <= 32'b0;
      wb_dat_o <= 32'b0;
      wb_sel_o <= 4'b0;
      wb_we_o <= 1'b1;
      addr <= dip_sw;
      i <= 4'b0;
    end else begin
      case (state) 
        IDLE: begin
          if (i < 10) begin
            wb_cyc_o <= 1'b1;
            wb_stb_o <= 1'b1;
            wb_adr_o <= serial_state_reg;
            wb_sel_o <= serial_state_sel;
            wb_we_o <= 1'b0;
            state <= READ_WAIT_ACTION;
          end
        end
        READ_WAIT_ACTION: begin
          if (wb_ack_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            data <= wb_dat_i;
            state <= READ_WAIT_CHECK;
          end
        end
        READ_WAIT_CHECK: begin
          if (data[8] == 1'b1) begin
            wb_cyc_o <= 1'b1;
            wb_stb_o <= 1'b1;
            wb_adr_o <= serial_data_reg;
            wb_sel_o <= serial_data_sel;
            wb_we_o <= 1'b0;
            state <= READ_DATA_ACTION;
          end else begin
            wb_cyc_o <= 1'b1; 
            wb_stb_o <= 1'b1;
            wb_adr_o <= serial_state_reg;
            wb_sel_o <= serial_state_sel;
            wb_we_o <= 1'b0;
            state <= READ_WAIT_ACTION;
          end
        end
        READ_DATA_ACTION: begin 
          if (wb_ack_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            write_data <= wb_dat_i;
            state <= READ_DATA_DONE;
          end
        end
        READ_DATA_DONE: begin
          wb_cyc_o <= 1'b1;
          wb_stb_o <= 1'b1;
          wb_adr_o <= addr + 4 * i;
          wb_sel_o <= sram_write_sel << offset;
          wb_dat_o <= write_data << (8 * offset);
          wb_we_o <= 1'b1;
          state <= WRITE_SRAM_ACTION;
        end
        WRITE_SRAM_ACTION: begin
          if (wb_ack_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_we_o <= 1'b0;
            state <= WRITE_SRAM_DONE;
          end
        end
        WRITE_SRAM_DONE: begin
          wb_cyc_o <= 1'b1;
          wb_stb_o <= 1'b1;
          wb_adr_o <= serial_state_reg;
          wb_sel_o <= serial_state_sel;
          wb_we_o <= 1'b0;
          state <= WRITE_WAIT_ACTION;
        end
        WRITE_WAIT_ACTION: begin
          if (wb_ack_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            data <= wb_dat_i;
            state <= WRITE_WAIT_CHECK;
          end
        end
        WRITE_WAIT_CHECK: begin
          if (data[13] == 1'b1) begin
            wb_cyc_o <= 1'b1;
            wb_stb_o <= 1'b1;
            wb_adr_o <= serial_data_reg;
            wb_sel_o <= serial_data_sel;
            wb_dat_o <= write_data;
            wb_we_o <= 1'b1;
            state <= WRITE_DATA_ACTION;
          end else begin
            wb_cyc_o <= 1'b1; 
            wb_stb_o <= 1'b1;
            wb_adr_o <= serial_state_reg;
            wb_sel_o <= serial_state_sel;
            wb_we_o <= 1'b0;
            state <= WRITE_WAIT_ACTION;
          end
        end
        WRITE_DATA_ACTION: begin
          if (wb_ack_i) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_we_o <= 1'b0;
            state <= WRITE_DATA_DONE;
          end
        end
        WRITE_DATA_DONE: begin
          state <= IDLE;
          i <= i + 1;
        end
      endcase
    end
  end
endmodule