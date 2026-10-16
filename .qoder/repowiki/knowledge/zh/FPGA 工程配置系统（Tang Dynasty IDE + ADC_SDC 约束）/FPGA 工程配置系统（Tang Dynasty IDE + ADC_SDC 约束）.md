---
kind: configuration_system
name: FPGA 工程配置系统（Tang Dynasty IDE + ADC/SDC 约束）
category: configuration_system
scope:
    - '**'
source_files:
    - tand_udp.al
    - tand_udp_devicesetting.cfg
    - hdl/constraint/mstar_udp_adc.adc
    - hdl/constraint/mstar_udp_sdc.sdc
---

## 概述

本仓库是安路 PH1 FPGA 的多通道 ADC 采集与 UDP 传输工程，不存在传统软件意义上的“运行时配置系统”（无 env、yaml、toml、properties 等）。工程的“配置”全部由 Tang Dynasty (TD) IDE 的工程文件、ADC 引脚约束和 SDC 时序约束构成，属于**编译期/综合期配置**。

## 关键配置文件

- `tand_udp.al` — Tang Dynasty IDE 项目定义文件（XML），描述目标器件、源文件列表、IP 核、顶层模块、综合/布局布线 Run 及 Bitgen 选项。
- `tand_udp_devicesetting.cfg` — 设备启动配置摘要，包含 `boot_mode`、`startup_clk_sel`、`global_crc_en`、`security`、`jtag` 等 Anlogic 器件级参数。
- `hdl/constraint/mstar_udp_adc.adc` — 引脚分配（pin assignment）约束，使用 `set_pin_assignment` 为每个端口指定 `LOCATION`、`IOSTANDARD`、`PULLTYPE`、`DRIVESTRENGTH`、`INDEL`。
- `hdl/constraint/mstar_udp_sdc.sdc` — 静态时序约束，声明 `clk_25mhz`、`clk_125mhz` 两个时钟，`derive_clocks` 推导 PLL 输出，并设置跨时钟域 `set_max_delay`。

## 架构与约定

### 1. 工程元数据集中在 `tand_udp.al`

该 XML 文件是 TD IDE 的单一入口：
- `<HardWare>` 段声明 Family=`PH1`、Device=`PH1P35MDG324`、Speed=`-3`。
- `<Source_Files>` 按 Verilog / SystemVerilog / ADC_FILE / SDC_FILE / IP_FILE 分类列出所有源码与 IP，每个条目带 `CompileOrder` 控制综合顺序。
- `<TOP_MODULE>` 将顶层模块锁定为 `mstar_udp_top`。
- `<Runs>` 定义两个 Run：`syn_1`（Synthesis）和 `phy_1`（PhysicalDesign），后者关联 `Default_PhysicalDesign_Strategy` 并开启 `bin=on`、`opt_timing=high`。
- `<Configurations><FeatureRow><boot_mode>mspix4</boot_mode></FeatureRow></Configurations>` 覆盖默认 boot 模式。

### 2. 器件启动参数独立于工程文件

`tand_udp_devicesetting.cfg` 以键值对形式保存器件级配置（如 `boot_mode=mspix4`、`startup_clk_sel=clk_2MHz`、`global_crc_en=1`、`security=0`、`jtag=dedicate`），与 `.al` 中的 `<Configurations>` 相互补充。

### 3. 硬件约束集中放在 `hdl/constraint/`

- 引脚分配统一在 `mstar_udp_adc.adc` 中，采用 `set_pin_assignment {signal} { LOCATION = ...; IOSTANDARD = LVCMOS33; PULLTYPE = PULLUP; }` 格式。
- 时序约束在 `mstar_udp_sdc.sdc` 中，通过 `create_clock`、`derive_clocks`、`rename_clock`、`set_max_delay` 组织多时钟域（w_clk125M / w_clk100M / w_clk50M / MIS_DDR_u/usr_clk）。
- 被注释掉的 `set_pin_assignment` 行（第 18–44 行）作为备选引脚方案保留，体现“多板卡适配”的约定。

### 4. IP 核配置位于各 IP 目录的 `*.xml` / `DesignConfiguration.xml`

`al_ip/MIS_DDR/`、`al_ip/sysPLL/`、`al_ip/AXI_Clock_Converter_ddr/`、`al_ip/AXIfull_Matrix/`、`al_ip/AXI_lite_Matrix/`、`al_ip/axis_dmadat_fifo/`、`al_ip/axis_mac_rxfifo/` 等子目录各自维护 IP 生成参数（`.params_*.txt`、`.ports_*.txt`、`.m_params_*.txt`）以及 `Design.xml` / `DesignConfiguration.xml`。这些文件由 IP 工具生成，不应手工编辑。

### 5. 构建产物与中间结果

`log/` 目录存放大量 TD 综合/布局布线日志（`td_YYYY-MM-DD_HH-MM-SS.log`、`bw_...log`、`ipgen.log`、`mp.log`），`tand_udp_Runs/` 下 `syn_1/`、`phy_1/`、`best_result/` 分别对应不同阶段的综合/布局布线输出（`.bit`、`.rbf`、`.bin`、`.prj`、`.ts`、`.db`）。

## 约定与约束

- **顶层模块固定**：`tand_udp.al` 中 `<TOP_MODULE><MODULE>mstar_udp_top</MODULE>` 强制顶层为 `mstar_udp_top`，修改需同步更新此处。
- **器件型号固定**：`<Device>PH1P35MDG324</Device>` 与 `<Family>PH1</Family>` 绑定，更换芯片需同时改 `.al`、`.adc`、`.sdc`。
- **引脚与 IO 标准一致**：所有 `set_pin_assignment` 均使用 `IOSTANDARD = LVCMOS33`，表明板级电平标准为 3.3V CMOS；输入信号普遍加 `PULLTYPE = PULLUP`，输出信号设为 `PULLTYPE = NONE` 且 `DRIVESTRENGTH = 8`。
- **时钟命名约定**：SDC 中将 PLL 输出重命名为 `w_clk125M`、`w_clk100M`、`w_clk50M`，跨时钟域 delay 成对出现（双向 `set_max_delay`）。
- **IP 配置不可直接编辑**：各 IP 目录下的 `.params_*`、`.ports_*`、`.m_params_*` 由 IP 工具维护，应通过 IP 工具重新生成而非手动修改。
- **Boot 模式双处配置**：`.al` 的 `<Configurations>` 与 `tand_udp_devicesetting.cfg` 的 `boot_mode` 字段需保持一致（当前分别为 `mspix4` 与 `mspix1`，存在差异，需确认实际生效来源）。

## 结论

本仓库没有运行时配置加载器或环境变量机制；“配置系统”即 Tang Dynasty IDE 工程体系：**`.al` 管工程结构，`.cfg` 管器件启动，`.adc` 管引脚，`.sdc` 管时序，IP 目录管 IP 参数**。所有配置均在综合/布局布线阶段静态生效。