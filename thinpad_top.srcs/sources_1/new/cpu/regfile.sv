// 寄存器堆 - 32个32位寄存器
// x0固定为0，两个异步读端口，一个同步写端口
module regfile (
    input  wire        clk,
    input  wire        rst,
    
    // 读端口1
    input  wire [ 4:0] rs1_addr,
    output wire [31:0] rs1_data,
    
    // 读端口2
    input  wire [ 4:0] rs2_addr,
    output wire [31:0] rs2_data,
    
    // 写端口
    input  wire [ 4:0] rd_addr,
    input  wire [31:0] rd_data,
    input  wire        reg_write
);

  // 32个32位寄存器
  reg [31:0] registers[0:31];

  // 异步读
  assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : registers[rs1_addr];
  assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : registers[rs2_addr];

  // 同步写
  always_ff @(posedge clk) begin
    if (rst) begin
      // 初始化所有寄存器为0
      for (int i = 0; i < 32; i++) begin
        registers[i] <= 32'b0;
      end
    end else begin
      // x0始终为0，不可写入
      if (reg_write && rd_addr != 5'b0) begin
        registers[rd_addr] <= rd_data;
      end
    end
  end

endmodule

