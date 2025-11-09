module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时为 1
    output wire [15:0] leds,       // 16 位 LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信号
    output wire uart_rdn,        // 读串口信号，低有效
    output wire uart_wrn,        // 写串口信号，低有效
    input  wire uart_dataready,  // 串口数据准备好
    input  wire uart_tbre,       // 发送数据标志
    input  wire uart_tsre,       // 数据发送完毕标志

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire base_ram_ce_n,  // BaseRAM 片选，低有效
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有效
    output wire base_ram_we_n,  // BaseRAM 写使能，低有效

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire ext_ram_ce_n,  // ExtRAM 片选，低有效
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有效
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash 存储器信号，参考 JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效，16bit 模式无意义
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,  // Flash 片选信号，低有效
    output wire flash_oe_n,  // Flash 读使能信号，低有效
    output wire flash_we_n,  // Flash 写使能信号，低有效
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash 的 16 位模式时请设为 1

    // USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素，3 位
    output wire [2:0] video_green,  // 绿色像素，3 位
    output wire [1:0] video_blue,   // 蓝色像素，2 位
    output wire       video_hsync,  // 行同步（水平同步）信号
    output wire       video_vsync,  // 场同步（垂直同步）信号
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐区
);

  // PLL 分频示例
  logic locked, clk_10M, clk_20M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设置
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设置
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出，"1"表示时钟稳定，
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic sys_clk;
  logic sys_rst;
  logic reset_of_clk10M;
  
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  assign sys_clk = clk_10M;
  assign sys_rst = reset_of_clk10M;

  // 本实验不使用 CPLD 串口，禁用防止总线冲突
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  // 数码管连接关系示意图，dpy1 同理
  // p=dpy0[0] // ---a---
  // c=dpy0[1] // |     |
  // d=dpy0[2] // f     b
  // e=dpy0[3] // |     |
  // b=dpy0[4] // ---g---
  // a=dpy0[5] // |     |
  // f=dpy0[6] // e     c
  // g=dpy0[7] // |     |
  //           // ---d---  p

  // // 7 段数码管译码器演示，将 number 用 16 进制显示在数码管上面
  // logic [7:0] number;
  // SEG7_LUT segL (
  //     .oSEG1(dpy0),
  //     .iDIG (number[3:0])
  // );  // dpy0 是低位数码管
  // SEG7_LUT segH (
  //     .oSEG1(dpy1),
  //     .iDIG (number[7:4])
  // );  // dpy1 是高位数码管

  // logic [15:0] led_bits;
  // assign leds = led_bits;

  // always_ff @(posedge clk_50M) begin
  //   if (reset_btn) begin  // 复位按下，设置 LED 为初始值
  //     led_bits <= 16'h1;
  //   end else if (push_btn) begin  // 每次按下按钮开关，LED 循环左移
  //     led_bits <= {led_bits[14:0], led_bits[15]};
  //   end
  // end

  // =========== CPU和总线架构 ===========
  
  // Wishbone信号定义 - IF Master
  logic [31:0] if_wb_adr;
  logic [31:0] if_wb_dat_m2s;
  logic [31:0] if_wb_dat_s2m;
  logic        if_wb_we;
  logic [3:0]  if_wb_sel;
  logic        if_wb_stb;
  logic        if_wb_ack;
  logic        if_wb_cyc;
  
  // Wishbone信号定义 - MEM Master
  logic [31:0] mem_wb_adr;
  logic [31:0] mem_wb_dat_m2s;
  logic [31:0] mem_wb_dat_s2m;
  logic        mem_wb_we;
  logic [3:0]  mem_wb_sel;
  logic        mem_wb_stb;
  logic        mem_wb_ack;
  logic        mem_wb_cyc;
  
  // Wishbone信号定义 - Arbiter输出
  logic [31:0] arb_wb_adr;
  logic [31:0] arb_wb_dat_m2s;
  logic [31:0] arb_wb_dat_s2m;
  logic        arb_wb_we;
  logic [3:0]  arb_wb_sel;
  logic        arb_wb_stb;
  logic        arb_wb_ack;
  logic        arb_wb_cyc;
  
  // Wishbone信号定义 - BaseRAM (Slave 0)
  logic [31:0] base_wb_adr;
  logic [31:0] base_wb_dat_m2s;
  logic [31:0] base_wb_dat_s2m;
  logic        base_wb_we;
  logic [3:0]  base_wb_sel;
  logic        base_wb_stb;
  logic        base_wb_ack;
  logic        base_wb_cyc;
  
  // Wishbone信号定义 - ExtRAM (Slave 1)
  logic [31:0] ext_wb_adr;
  logic [31:0] ext_wb_dat_m2s;
  logic [31:0] ext_wb_dat_s2m;
  logic        ext_wb_we;
  logic [3:0]  ext_wb_sel;
  logic        ext_wb_stb;
  logic        ext_wb_ack;
  logic        ext_wb_cyc;
  
  // Wishbone信号定义 - UART (Slave 2)
  logic [31:0] uart_wb_adr;
  logic [31:0] uart_wb_dat_m2s;
  logic [31:0] uart_wb_dat_s2m;
  logic        uart_wb_we;
  logic [3:0]  uart_wb_sel;
  logic        uart_wb_stb;
  logic        uart_wb_ack;
  logic        uart_wb_cyc;
  
  // =========== CPU核心实例 ===========
  cpu_core u_cpu_core (
    .clk(sys_clk),
    .rst(sys_rst),
    
    // IF Master接口
    .if_wb_adr_o(if_wb_adr),
    .if_wb_dat_i(if_wb_dat_s2m),
    .if_wb_dat_o(if_wb_dat_m2s),
    .if_wb_we_o(if_wb_we),
    .if_wb_sel_o(if_wb_sel),
    .if_wb_stb_o(if_wb_stb),
    .if_wb_ack_i(if_wb_ack),
    .if_wb_cyc_o(if_wb_cyc),
    
    // MEM Master接口
    .mem_wb_adr_o(mem_wb_adr),
    .mem_wb_dat_i(mem_wb_dat_s2m),
    .mem_wb_dat_o(mem_wb_dat_m2s),
    .mem_wb_we_o(mem_wb_we),
    .mem_wb_sel_o(mem_wb_sel),
    .mem_wb_stb_o(mem_wb_stb),
    .mem_wb_ack_i(mem_wb_ack),
    .mem_wb_cyc_o(mem_wb_cyc)
  );
  
  // =========== Wishbone Arbiter (2个Master) ===========
  wb_arbiter_2 #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32),
    .SELECT_WIDTH(4),
    .ARB_TYPE_ROUND_ROBIN(0),
    .ARB_LSB_HIGH_PRIORITY(1)
  ) u_wb_arbiter (
    .clk(sys_clk),
    .rst(sys_rst),
    
    // Master 0: IF Master
    .wbm0_adr_i(if_wb_adr),
    .wbm0_dat_i(if_wb_dat_m2s),
    .wbm0_dat_o(if_wb_dat_s2m),
    .wbm0_we_i(if_wb_we),
    .wbm0_sel_i(if_wb_sel),
    .wbm0_stb_i(if_wb_stb),
    .wbm0_ack_o(if_wb_ack),
    .wbm0_err_o(),
    .wbm0_rty_o(),
    .wbm0_cyc_i(if_wb_cyc),
    
    // Master 1: MEM Master
    .wbm1_adr_i(mem_wb_adr),
    .wbm1_dat_i(mem_wb_dat_m2s),
    .wbm1_dat_o(mem_wb_dat_s2m),
    .wbm1_we_i(mem_wb_we),
    .wbm1_sel_i(mem_wb_sel),
    .wbm1_stb_i(mem_wb_stb),
    .wbm1_ack_o(mem_wb_ack),
    .wbm1_err_o(),
    .wbm1_rty_o(),
    .wbm1_cyc_i(mem_wb_cyc),
    
    // Slave输出
    .wbs_adr_o(arb_wb_adr),
    .wbs_dat_i(arb_wb_dat_s2m),
    .wbs_dat_o(arb_wb_dat_m2s),
    .wbs_we_o(arb_wb_we),
    .wbs_sel_o(arb_wb_sel),
    .wbs_stb_o(arb_wb_stb),
    .wbs_ack_i(arb_wb_ack),
    .wbs_err_i(1'b0),
    .wbs_rty_i(1'b0),
    .wbs_cyc_o(arb_wb_cyc)
  );
  
  // =========== Wishbone Mux (3个Slave) ===========
  wb_mux_3 #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32),
    .SELECT_WIDTH(4)
  ) u_wb_mux (
    .clk(sys_clk),
    .rst(sys_rst),
    
    // Master输入
    .wbm_adr_i(arb_wb_adr),
    .wbm_dat_i(arb_wb_dat_m2s),
    .wbm_dat_o(arb_wb_dat_s2m),
    .wbm_we_i(arb_wb_we),
    .wbm_sel_i(arb_wb_sel),
    .wbm_stb_i(arb_wb_stb),
    .wbm_ack_o(arb_wb_ack),
    .wbm_err_o(),
    .wbm_rty_o(),
    .wbm_cyc_i(arb_wb_cyc),
    
    // Slave 0: BaseRAM (0x8000_0000 - 0x803F_FFFF)
    .wbs0_adr_o(base_wb_adr),
    .wbs0_dat_i(base_wb_dat_s2m),
    .wbs0_dat_o(base_wb_dat_m2s),
    .wbs0_we_o(base_wb_we),
    .wbs0_sel_o(base_wb_sel),
    .wbs0_stb_o(base_wb_stb),
    .wbs0_ack_i(base_wb_ack),
    .wbs0_err_i(1'b0),
    .wbs0_rty_i(1'b0),
    .wbs0_cyc_o(base_wb_cyc),
    .wbs0_addr(32'h8000_0000),
    .wbs0_addr_msk(32'hFFC0_0000),
    
    // Slave 1: ExtRAM (0x8040_0000 - 0x807F_FFFF)
    .wbs1_adr_o(ext_wb_adr),
    .wbs1_dat_i(ext_wb_dat_s2m),
    .wbs1_dat_o(ext_wb_dat_m2s),
    .wbs1_we_o(ext_wb_we),
    .wbs1_sel_o(ext_wb_sel),
    .wbs1_stb_o(ext_wb_stb),
    .wbs1_ack_i(ext_wb_ack),
    .wbs1_err_i(1'b0),
    .wbs1_rty_i(1'b0),
    .wbs1_cyc_o(ext_wb_cyc),
    .wbs1_addr(32'h8040_0000),
    .wbs1_addr_msk(32'hFFC0_0000),
    
    // Slave 2: UART (0x1000_0000 - 0x1FFF_FFFF)
    .wbs2_adr_o(uart_wb_adr),
    .wbs2_dat_i(uart_wb_dat_s2m),
    .wbs2_dat_o(uart_wb_dat_m2s),
    .wbs2_we_o(uart_wb_we),
    .wbs2_sel_o(uart_wb_sel),
    .wbs2_stb_o(uart_wb_stb),
    .wbs2_ack_i(uart_wb_ack),
    .wbs2_err_i(1'b0),
    .wbs2_rty_i(1'b0),
    .wbs2_cyc_o(uart_wb_cyc),
    .wbs2_addr(32'h1000_0000),
    .wbs2_addr_msk(32'hFFFF_0000)
  );
  
  // =========== BaseRAM SRAM Controller ===========
  sram_controller #(
    .SRAM_ADDR_WIDTH(20),
    .SRAM_DATA_WIDTH(32),
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32)
  ) u_base_sram_controller (
    .clk_i(sys_clk),
    .rst_i(sys_rst),
    
    // Wishbone Slave接口
    .wb_cyc_i(base_wb_cyc),
    .wb_stb_i(base_wb_stb),
    .wb_ack_o(base_wb_ack),
    .wb_adr_i(base_wb_adr),
    .wb_dat_i(base_wb_dat_m2s),
    .wb_dat_o(base_wb_dat_s2m),
    .wb_sel_i(base_wb_sel),
    .wb_we_i(base_wb_we),
    
    // SRAM接口
    .sram_addr(base_ram_addr),
    .sram_data(base_ram_data),
    .sram_ce_n(base_ram_ce_n),
    .sram_oe_n(base_ram_oe_n),
    .sram_we_n(base_ram_we_n),
    .sram_be_n(base_ram_be_n)
  );
  
  // =========== ExtRAM SRAM Controller ===========
  sram_controller #(
    .SRAM_ADDR_WIDTH(20),
    .SRAM_DATA_WIDTH(32),
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32)
  ) u_ext_sram_controller (
    .clk_i(sys_clk),
    .rst_i(sys_rst),
    
    // Wishbone Slave接口
    .wb_cyc_i(ext_wb_cyc),
    .wb_stb_i(ext_wb_stb),
    .wb_ack_o(ext_wb_ack),
    .wb_adr_i(ext_wb_adr),
    .wb_dat_i(ext_wb_dat_m2s),
    .wb_dat_o(ext_wb_dat_s2m),
    .wb_sel_i(ext_wb_sel),
    .wb_we_i(ext_wb_we),
    
    // SRAM接口
    .sram_addr(ext_ram_addr),
    .sram_data(ext_ram_data),
    .sram_ce_n(ext_ram_ce_n),
    .sram_oe_n(ext_ram_oe_n),
    .sram_we_n(ext_ram_we_n),
    .sram_be_n(ext_ram_be_n)
  );
  
  // =========== UART Controller ===========
  uart_controller #(
    .CLK_FREQ(10_000_000),
    .BAUD(115200)
  ) u_uart_controller (
    .clk_i(sys_clk),
    .rst_i(sys_rst),
    
    // Wishbone Slave接口
    .wb_cyc_i(uart_wb_cyc),
    .wb_stb_i(uart_wb_stb),
    .wb_ack_o(uart_wb_ack),
    .wb_adr_i(uart_wb_adr),
    .wb_dat_i(uart_wb_dat_m2s),
    .wb_dat_o(uart_wb_dat_s2m),
    .wb_sel_i(uart_wb_sel),
    .wb_we_i(uart_wb_we),
    
    // UART接口
    .uart_txd_o(txd),
    .uart_rxd_i(rxd)
  );
  
  // // =========== 未使用的外设 ===========
  // // Flash
  // assign flash_a      = 23'b0;
  // assign flash_d      = 16'bz;
  // assign flash_rp_n   = 1'b1;
  // assign flash_vpen   = 1'b1;
  // assign flash_ce_n   = 1'b1;
  // assign flash_oe_n   = 1'b1;
  // assign flash_we_n   = 1'b1;
  // assign flash_byte_n = 1'b1;
  
  // // USB
  // assign sl811_a0     = 1'b0;
  // assign sl811_wr_n   = 1'b1;
  // assign sl811_rd_n   = 1'b1;
  // assign sl811_cs_n   = 1'b1;
  // assign sl811_rst_n  = 1'b0;
  // assign sl811_dack_n = 1'b1;
  
  // // Ethernet
  // assign dm9k_cmd     = 1'b0;
  // assign dm9k_sd      = 16'bz;
  // assign dm9k_iow_n   = 1'b1;
  // assign dm9k_ior_n   = 1'b1;
  // assign dm9k_cs_n    = 1'b1;
  // assign dm9k_pwrst_n = 1'b0;
  
  // // VGA
  // assign video_red    = 3'b0;
  // assign video_green  = 3'b0;
  // assign video_blue   = 2'b0;
  // assign video_hsync  = 1'b0;
  // assign video_vsync  = 1'b0;
  // assign video_clk    = 1'b0;
  // assign video_de     = 1'b0;
  
  // // LED和数码管
  // assign leds = 16'b0;
  // assign dpy0 = 8'b0;
  // assign dpy1 = 8'b0;

endmodule
