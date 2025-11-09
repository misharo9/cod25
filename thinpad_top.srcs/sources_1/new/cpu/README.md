# RV32I 五级流水线CPU设计文档

## 概述

本项目实现了一个完整的RV32I五级流水线CPU，支持RISC-V基础整数指令集。CPU通过Wishbone总线连接到外部存储器和外设。

## 设计架构

### SOC总线架构

```
CPU核心
  ├── IF Master (指令取指)
  └── MEM Master (数据访存)
       ↓
  Wishbone Arbiter (2个Master仲裁)
       ↓
  Wishbone Mux (3个Slave地址译码)
       ↓
  ├── BaseRAM SRAM Controller (0x8000_0000 - 0x803F_FFFF)
  ├── ExtRAM SRAM Controller  (0x8040_0000 - 0x807F_FFFF)
  └── UART Controller         (0x1000_0000 - 0x1FFF_FFFF)
```

### 流水线阶段

#### 1. IF (Instruction Fetch - 取指阶段)
- **功能**: 从指令内存获取指令
- **组件**:
  - PC寄存器
  - IF Master (Wishbone接口)
- **输出**: PC+4, 指令

#### 2. ID (Instruction Decode - 译码阶段)
- **功能**: 指令解码、寄存器读取、立即数生成
- **组件**:
  - Control Unit (控制单元)
  - Register File (寄存器堆)
  - Immediate Generator (立即数生成器)
- **输出**: 控制信号、操作数、立即数

#### 3. EX (Execute - 执行阶段)
- **功能**: ALU运算、分支判断
- **组件**:
  - ALU (算术逻辑单元)
  - Branch Unit (分支判断单元)
  - Forwarding Unit (前递单元)
- **输出**: ALU结果、分支目标地址

#### 4. MEM (Memory Access - 访存阶段)
- **功能**: 数据内存访问
- **组件**:
  - MEM Master (Wishbone接口)
- **输出**: 读取的数据

#### 5. WB (Write Back - 写回阶段)
- **功能**: 将结果写回寄存器
- **组件**:
  - 写回数据选择器
- **输出**: 写回寄存器的数据

## 核心模块说明

### 1. alu.sv
- **功能**: 算术逻辑单元
- **支持的操作**:
  - ADD, SUB (加减)
  - SLL, SRL, SRA (移位)
  - SLT, SLTU (比较)
  - AND, OR, XOR (逻辑运算)

### 2. regfile.sv
- **功能**: 32个32位通用寄存器
- **特性**:
  - x0固定为0
  - 2个异步读端口
  - 1个同步写端口

### 3. imm_gen.sv
- **功能**: 立即数生成和符号扩展
- **支持类型**: I, S, B, U, J

### 4. control.sv
- **功能**: 指令译码和控制信号生成
- **控制信号**:
  - reg_write: 寄存器写使能
  - mem_read/mem_write: 内存读写使能
  - alu_src: ALU操作数来源
  - result_src: 写回数据来源
  - branch/jump: 分支跳转控制

### 5. forwarding_unit.sv
- **功能**: 数据前递（旁路）
- **前递路径**:
  - EX/MEM -> EX (EX hazard)
  - MEM/WB -> EX (MEM hazard)

### 6. hazard_detection.sv
- **功能**: 冒险检测和流水线控制
- **检测类型**:
  - Load-Use hazard (停顿)
  - Control hazard (冲刷)
  - Structural hazard (总线冲突)

### 7. if_master.sv / mem_master.sv
- **功能**: Wishbone Master接口
- **特性**:
  - 标准Wishbone协议
  - 握手机制
  - 等待信号生成

### 8. branch_unit.sv
- **功能**: 分支条件判断
- **支持指令**: BEQ, BNE, BLT, BGE, BLTU, BGEU

### 9. cpu_core.sv
- **功能**: CPU核心顶层模块
- **集成**: 所有流水线阶段和控制逻辑

## 冒险处理

### 1. 数据冒险 (Data Hazards)
**问题**: 后续指令需要前面指令的结果

**解决方案**:
- **前递 (Forwarding)**: 
  - EX/MEM -> EX: 直接将ALU结果前递
  - MEM/WB -> EX: 将写回数据前递
- **停顿 (Stall)**: 
  - Load-Use hazard: 停顿1个周期

### 2. 控制冒险 (Control Hazards)
**问题**: 分支/跳转导致流水线取错指令

**解决方案**:
- **冲刷 (Flush)**: 
  - 分支成功/跳转时冲刷IF/ID和ID/EX
  - 更新PC到目标地址

### 3. 结构冒险 (Structural Hazards)
**问题**: IF和MEM同时访问总线

**解决方案**:
- **仲裁器 (Arbiter)**:
  - MEM优先级高于IF
  - IF等待时停顿前端流水线
  - MEM等待时停顿整个流水线

## 支持的指令

### 算术运算
- ADD, ADDI, SUB
- SLL, SLLI, SRL, SRLI, SRA, SRAI
- SLT, SLTI, SLTU, SLTIU

### 逻辑运算
- AND, ANDI, OR, ORI, XOR, XORI

### 立即数加载
- LUI (Load Upper Immediate)
- AUIPC (Add Upper Immediate to PC)

### 访存指令
- LW, LH, LB, LHU, LBU (Load)
- SW, SH, SB (Store)

### 分支跳转
- BEQ, BNE, BLT, BGE, BLTU, BGEU (Branch)
- JAL, JALR (Jump)

## 时序特性

### 时钟频率
- 系统时钟: 10MHz (来自PLL)

### 指令延迟
- 无冒险: 1个周期/指令 (理想CPI=1)
- Load-Use hazard: +1个周期停顿
- 分支/跳转: +2个周期惩罚
- 总线冲突: 动态停顿

### SRAM访问时序
- 读操作: 3个周期
- 写操作: 4个周期

### UART访问
- 波特率: 115200
- 立即响应

## 内存映射

| 地址范围 | 设备 | 大小 |
|---------|------|------|
| 0x8000_0000 - 0x803F_FFFF | BaseRAM | 4MB |
| 0x8040_0000 - 0x807F_FFFF | ExtRAM | 4MB |
| 0x1000_0000 - 0x1000_0005 | UART | 6B |

### UART寄存器
- 0x1000_0000: DATA (数据寄存器)
- 0x1000_0005: STATUS (状态寄存器)
  - bit 0: RxD_data_ready (接收数据准备好)
  - bit 5: TxD_idle (发送器空闲)

## 复位行为

- 复位信号: 高电平有效
- 复位后PC: 0x8000_0000
- 所有流水线寄存器清零
- 所有通用寄存器清零

## 使用说明

### 1. 程序加载
将程序加载到BaseRAM的0x8000_0000地址开始处

### 2. 启动
- 按下复位按钮
- CPU从0x8000_0000开始执行

### 3. 调试
- 通过UART输出调试信息
- 波特率: 115200

## 文件结构

```
cpu/
├── alu.sv                  # ALU
├── regfile.sv              # 寄存器堆
├── imm_gen.sv              # 立即数生成器
├── control.sv              # 控制单元
├── forwarding_unit.sv      # 前递单元
├── hazard_detection.sv     # 冒险检测
├── branch_unit.sv          # 分支判断
├── if_master.sv            # 指令取指Master
├── mem_master.sv           # 数据访存Master
├── cpu_core.sv             # CPU核心
└── README.md               # 本文档

thinpad_top.sv              # 顶层模块（SOC集成）

arbiter/
├── arbiter.v               # 通用仲裁器
├── priority_encoder.v      # 优先级编码器
└── wb_arbiter_2.v          # 2端口Wishbone仲裁器

lab3/
└── sram_controller.sv      # SRAM控制器

lab4/
├── uart_controller.sv      # UART控制器
└── wb_mux_3.v              # 3端口Wishbone多路复用器
```

## 设计特点

1. **标准流水线**: 经典五级RISC流水线设计
2. **完整冒险处理**: 支持前递、停顿、冲刷
3. **Wishbone总线**: 标准的开源总线协议
4. **模块化设计**: 高内聚低耦合，易于扩展
5. **可综合**: 纯RTL设计，可综合到FPGA

## 扩展建议

1. **性能优化**:
   - 添加分支预测
   - 实现更复杂的前递网络
   - 添加Cache

2. **功能扩展**:
   - 支持RV32M (乘除法)
   - 支持RV32A (原子操作)
   - 支持特权指令和异常处理

3. **调试功能**:
   - 添加性能计数器
   - 实现JTAG调试接口
   - 添加断点和单步执行

## 参考资料

- RISC-V Unprivileged ISA Specification
- Wishbone B4 Specification
- 《计算机组成与设计: 硬件/软件接口》(Patterson & Hennessy)

