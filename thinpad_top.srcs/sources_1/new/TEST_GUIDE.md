# CPU测试指南

## 项目概述

本项目实现了一个支持RV32I基础指令集的五级流水线CPU，集成在Thinpad平台上。

## 文件组织

### 新创建的CPU模块 (位于 `cpu/` 目录)

1. **核心组件**:
   - `alu.sv` - 算术逻辑单元
   - `regfile.sv` - 32个通用寄存器
   - `imm_gen.sv` - 立即数生成器
   - `control.sv` - 控制单元

2. **冒险处理**:
   - `forwarding_unit.sv` - 数据前递单元
   - `hazard_detection.sv` - 冒险检测单元
   - `branch_unit.sv` - 分支判断单元

3. **总线接口**:
   - `if_master.sv` - 指令取指Wishbone Master
   - `mem_master.sv` - 数据访存Wishbone Master

4. **CPU核心**:
   - `cpu_core.sv` - 五级流水线CPU核心

### 总线架构 (已存在的模块)

- `arbiter/wb_arbiter_2.v` - Wishbone 2端口仲裁器
- `lab4/wb_mux_3.v` - Wishbone 3端口多路复用器
- `lab3/sram_controller.sv` - SRAM控制器
- `lab4/uart_controller.sv` - UART控制器

### 顶层集成

- `thinpad_top.sv` - 顶层模块，完成CPU和总线的集成

## SOC架构

```
                    CPU Core
                    /      \
              IF Master    MEM Master
                    \      /
                   Arbiter (优先级: MEM > IF)
                      |
                     Mux (地址译码)
                   /  |  \
            BaseRAM ExtRAM UART
         0x8000_0000 0x8040_0000 0x1000_0000
```

### 地址映射

| 设备 | 起始地址 | 结束地址 | 大小 | 用途 |
|------|---------|---------|------|------|
| BaseRAM | 0x8000_0000 | 0x803F_FFFF | 4MB | 程序代码和数据 |
| ExtRAM | 0x8040_0000 | 0x807F_FFFF | 4MB | 扩展数据空间 |
| UART | 0x1000_0000 | 0x1000_0005 | 6B | 串口通信 |

## 编译和综合

### 前提条件

1. Vivado 2019.1 或更新版本
2. Thinpad开发板
3. RISC-V工具链 (riscv32-unknown-elf-gcc)

### 步骤

1. **打开项目**:
   ```
   打开 thinpad_top.xpr
   ```

2. **添加源文件**:
   - 确保 `cpu/` 目录下的所有文件都已添加到项目中
   - 文件类型应设置为 SystemVerilog

3. **综合**:
   ```
   Run Synthesis
   ```

4. **实现**:
   ```
   Run Implementation
   ```

5. **生成比特流**:
   ```
   Generate Bitstream
   ```

## 测试程序编写

### 示例1: Hello World (UART输出)

```assembly
.text
.globl _start

_start:
    # 设置栈指针
    lui sp, 0x80400
    
    # 准备字符串地址
    la a0, hello_str
    call print_string
    
    # 循环
loop:
    j loop

print_string:
    # a0 = 字符串地址
    li t0, 0x10000000  # UART基地址
    
print_loop:
    lb t1, 0(a0)       # 加载字符
    beqz t1, print_done # 如果是'\0'则结束
    
wait_uart:
    lbu t2, 5(t0)      # 读状态寄存器
    andi t2, t2, 0x20  # 检查bit 5 (TxD_idle)
    beqz t2, wait_uart # 如果忙则等待
    
    sb t1, 0(t0)       # 发送字符
    addi a0, a0, 1     # 下一个字符
    j print_loop
    
print_done:
    ret

.data
hello_str:
    .asciz "Hello from RV32I CPU!\n"
```

### 示例2: 测试算术运算

```assembly
.text
.globl _start

_start:
    # 测试加法
    li a0, 10
    li a1, 20
    add a2, a0, a1     # a2 = 30
    
    # 测试减法
    sub a3, a1, a0     # a3 = 10
    
    # 测试移位
    slli a4, a0, 2     # a4 = 40
    srli a5, a4, 1     # a5 = 20
    
    # 测试逻辑运算
    and a6, a0, a1     # a6 = 0
    or a7, a0, a1      # a7 = 30
    xor t0, a0, a1     # t0 = 30
    
    # 循环
loop:
    j loop
```

### 编译和链接

1. **编译**:
   ```bash
   riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib \
       -T linker.ld -o program.elf program.s
   ```

2. **生成二进制**:
   ```bash
   riscv32-unknown-elf-objcopy -O binary program.elf program.bin
   ```

3. **生成十六进制文件**:
   ```bash
   hexdump -v -e '1/4 "%08x\n"' program.bin > program.hex
   ```

### Linker Script 示例 (linker.ld)

```ld
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 4M
}

SECTIONS
{
    .text : {
        *(.text)
        *(.text.*)
    } > RAM
    
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > RAM
    
    .data : {
        *(.data)
        *(.data.*)
    } > RAM
    
    .bss : {
        *(.bss)
        *(.bss.*)
    } > RAM
}
```

## 调试方法

### 1. 仿真调试

创建测试bench (tb.sv):

```systemverilog
module tb;
    reg clk_50M;
    reg reset_btn;
    
    // 实例化顶层模块
    thinpad_top dut (
        .clk_50M(clk_50M),
        .reset_btn(reset_btn),
        // ... 其他端口
    );
    
    // 生成时钟
    initial begin
        clk_50M = 0;
        forever #10 clk_50M = ~clk_50M; // 50MHz
    end
    
    // 测试序列
    initial begin
        reset_btn = 1;
        #100;
        reset_btn = 0;
        #10000;
        $finish;
    end
    
    // 监控
    initial begin
        $monitor("Time=%0t PC=%h Inst=%h", 
                 $time, 
                 dut.u_cpu_core.pc_reg,
                 dut.u_cpu_core.if_instruction);
    end
endmodule
```

### 2. 硬件调试

1. **使用UART输出**:
   - 连接串口线到PC
   - 使用串口终端 (115200, 8N1)
   - 在程序中输出调试信息

2. **使用LED和数码管**:
   - 修改 `thinpad_top.sv` 连接CPU内部信号到LED
   - 观察程序执行状态

3. **ILA (Integrated Logic Analyzer)**:
   - 在Vivado中添加ILA IP
   - 连接关键信号
   - 实时观察波形

## 常见问题

### Q1: CPU不启动怎么办？

**检查项**:
1. 确认程序已正确加载到BaseRAM的0x8000_0000地址
2. 检查复位信号是否正常
3. 检查时钟是否稳定 (PLL locked)

### Q2: 程序执行错误？

**调试步骤**:
1. 在仿真中单步执行，观察流水线状态
2. 检查分支和跳转是否正确
3. 验证Load/Store地址是否正确
4. 检查数据前递是否工作

### Q3: UART无输出？

**检查项**:
1. 确认波特率设置正确 (115200)
2. 检查UART地址是否正确 (0x1000_0000)
3. 确认发送前检查状态寄存器
4. 验证串口线连接正确

### Q4: 性能不符合预期？

**分析方法**:
1. 统计总线冲突频率
2. 分析分支预测失败率
3. 检查Load-Use hazard发生频率
4. 考虑优化代码减少依赖

## 性能测试

### 测试1: Dhrystone

使用Dhrystone基准测试程序测试CPU性能：

```bash
# 编译Dhrystone
riscv32-unknown-elf-gcc -O2 -march=rv32i -mabi=ilp32 \
    dhrystone.c -o dhrystone.elf
```

### 测试2: CoreMark

使用CoreMark测试：

```bash
# 编译CoreMark
make PORT_DIR=riscv32 compile
```

### 预期性能

- **时钟频率**: 10MHz
- **理想CPI**: 1.0
- **实际CPI**: 1.2-1.5 (考虑冒险和总线冲突)
- **DMIPS**: ~3-5 DMIPS

## 进阶功能

### 1. 添加性能计数器

在 `cpu_core.sv` 中添加：

```systemverilog
// 性能计数器
reg [31:0] cycle_count;
reg [31:0] inst_count;
reg [31:0] stall_count;

always_ff @(posedge clk) begin
    if (rst) begin
        cycle_count <= 0;
        inst_count <= 0;
        stall_count <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        if (wb_reg_write) inst_count <= inst_count + 1;
        if (pc_stall) stall_count <= stall_count + 1;
    end
end
```

### 2. 支持异常处理

添加CSR寄存器和异常处理逻辑。

### 3. 添加Cache

实现简单的直接映射Cache提升性能。

## 参考资源

- [RISC-V规范](https://riscv.org/technical/specifications/)
- [Wishbone规范](https://opencores.org/howto/wishbone)
- `cpu/README.md` - 详细设计文档

## 技术支持

如有问题，请检查：
1. 详细设计文档 (`cpu/README.md`)
2. 源代码注释
3. 仿真波形

