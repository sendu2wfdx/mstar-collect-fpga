---
kind: build_system
name: 基于 Tang Dynasty IDE 的安路 PH1 FPGA 工程构建
category: build_system
scope:
    - '**'
source_files:
    - tand_udp.al
    - tand_udp_devicesetting.cfg
    - tand_udp_Runs/syn_1/run.bat
    - tand_udp_Runs/phy_1/run.bat
    - hdl/constraint/mstar_udp_adc.adc
    - hdl/constraint/mstar_udp_sdc.sdc
    - al_ip/MIS_DDR/MIS_DDR.xml
    - al_ip/sysPLL/sysPLL.xml
    - al_ip/AXIfull_Matrix/AXIfull_Matrix.xml
    - al_ip/AXI_lite_Matrix/AXI_lite_Matrix.xml
    - al_ip/AXI_Clock_Converter_ddr/AXI_Clock_Converter_ddr.xml
    - al_ip/axis_dmadat_fifo/axis_dmadat_fifo.xml
    - tand_udp_Runs/best_result/tand_udp.bit
    - tand_udp_Runs/best_result/tand_udp.bin
---

## 构建系统概览

本项目是一个面向 **Anlogic PH1** 系列 FPGA 的 Verilog/SystemVerilog 设计，构建完全依赖 **Tang Dynasty (TD) IDE**（版本 ≥ 6.2），没有 Makefile、Dockerfile、CI 流水线或跨编译脚本。构建入口是 Tang Dynasty 工程文件 `tand_udp.al`。

## 关键文件与角色

- `tand_udp.al` — Tang Dynasty 项目定义，声明目标器件、源文件集合、IP 核、约束和 Runs。
- `tand_udp_devicesetting.cfg` — 器件启动配置（boot_mode=mspix1, startup_clk_sel=clk_2MHz, jtag=dedicate 等）。
- `tand_udp_Runs/syn_1/run.bat` — 综合阶段批处理，调用 `td_commands_prompt.exe` 执行 `DefaultFlow.tcl`。
- `tand_udp_Runs/phy_1/run.bat` — 布局布线 + Bitgen 阶段批处理，同样走 `DefaultFlow.tcl`。
- `hdl/constraint/mstar_udp_adc.adc` — 引脚约束。
- `hdl/constraint/mstar_udp_sdc.sdc` — 时序约束。
- `al_ip/*/Design.xml` / `*.xml` — 各 IP 核的工程描述文件（MIS_DDR、AXIfull_Matrix、AXI_lite_Matrix、AXI_Clock_Converter_ddr、axis_dmadat_fifo、sysPLL 等）。
- `tand_udp_Runs/best_result/tand_udp.bit` / `.bin` / `.rbf` — 最终生成的比特流及二进制镜像。

## 构建流程与架构

构建由两个串联的 Tang Dynasty Run 组成：

1. **syn_1**（Synthesis）— 使用策略 `Default_Synthesis_Strategy`，输入约束集 `constraint_1`。
2. **phy_1**（PhysicalDesign）— 依赖 syn_1，使用策略 `Default_PhysicalDesign_Strategy`，其中 Place 优化级别设为 `opt_timing=high`，Bitgen 输出开启 `bin=on`。

每个 Run 目录下都有 `run.bat`，其内容固定为：
```
td_commands_prompt.exe <TD安装路径>/scripts/DefaultFlow.tcl
```
即通过 TD 命令行工具驱动默认 Tcl 流程完成综合或物理实现。

## 源文件组织约定

`tand_udp.al` 中按类型分节声明源文件，并显式设置 `CompileOrder` 以控制编译顺序：

- `<Verilog>` 段：顶层 `hdl/mstar_udp_top.v` 排在第 3 位，ADC 驱动、采集逻辑、同步模块、UDP 桥接依次递增。
- `<System_Verilog>` 段：`axi_dma_example_*` 三个示例 SV 文件，其中一个标记 `AutoExcluded=true`。
- `<ADC_FILE>` / `<SDC_FILE>` 段：约束文件归入 `constraint_1` FileSet，CompileOrder 为 1、2。
- `<IP_FILE>` 段：所有 `al_ip/*/*.xml` IP 描述文件，CompileOrder 从 1 到 18，覆盖 MIS_DDR、AXI Matrix、Clock Converter、FIFO、sysPLL 等。

顶层模块在 `<TOP_MODULE>` 中声明为 `mstar_udp_top`。

## 设备与工具链约束

- 目标器件：`PH1P35MDG324-3`（Family=PH1, Speed=-3）。
- IDE 版本：`TD_Version=6.2.190657`（README 要求 ≥ 6.2）。
- 启动模式：`boot_mode=mspix4`（`.al` 中）与 `mspix1`（`devicesetting.cfg` 中），两者不一致，需留意。
- 调试：`chip_debugger/user.cpc` 提供 ChipDebugger 配置；综合/布局布线产物中包含多个 `ChipWatcher_*` 目录，表明启用了 Anlogic 的在线调试观察点功能。

## 约定与规则

- **无自动化 CI / Makefile**：仓库中没有 Makefile、Dockerfile、GitHub Actions/GitLab CI 等持续集成配置；构建说明仅要求“打开 `tand_udp.al` → 综合 → 布局布线 → 生成比特流”。
- **构建入口唯一**：所有可执行构建步骤都通过 `run.bat` 调用 `DefaultFlow.tcl`，不直接调用底层综合/布局布线命令。
- **IP 核以 XML 描述引入**：所有第三方 IP 通过 `al_ip/<ip_name>/<ip_name>.xml` 注册到工程中，而不是直接以 RTL 路径引用。
- **约束与源码分离**：引脚与时序约束集中在 `hdl/constraint/`，与 RTL 源码目录分开。
- **日志归档**：`log/` 目录下按日期命名大量 `bw_*.log`、`td_*.log`、`mp.log`、`ipgen.log` 等运行日志，作为历史构建记录保留在仓库中（非构建产物本身）。
- **加密 IP**：`hdl/udpip/mstar_ethernet_bridge.ipr.v` 是加密网表，README 明确说明该 IP 以加密形式开源，不提供源码。
- **版本管理**：版本号采用 README 中的 `v1.0 (2026-10-15)` 格式，当前为首次开源发布。

## 结论

本项目的“构建系统”本质上是 **Tang Dynasty IDE 原生工程**，没有抽象出跨工具的构建层。任何新增源文件都需要手动编辑 `tand_udp.al` 或在 IDE 中添加，Run 的配置也保存在 `.al` 中。这种方式的优点是简单直观，缺点是难以在无 GUI 环境下自动化构建。