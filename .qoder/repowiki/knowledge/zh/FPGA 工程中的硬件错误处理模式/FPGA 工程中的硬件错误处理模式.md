---
kind: error_handling
name: FPGA 工程中的硬件错误处理模式
category: error_handling
scope:
    - '**'
source_files:
    - hdl/mstar_udp_top.v
    - hdl/collect/ad_dma_axictrl.v
    - hdl/udpip/mstar_ethernet_bridge.ipr.v
    - al_ip/MIS_DDR/MIS_DDR.v
    - al_ip/MIS_DDR/ph1p_ddrmc_wrapper_MIS_DDR.v
    - al_ip/MIS_DDR/src/rtl/phy/ph1p_ddrphy_mdl_cal.v
    - al_ip/MIS_DDR/src/rtl/phy/ph1p_ddrphy_top.v
    - al_ip/sysPLL/sysPLL.v
    - hdl/axi_dma/axi_dma_example_axi_read_master.sv
    - hdl/axi_dma/axi_dma_example_axi_write_master.sv
---

## 概述

本仓库为基于安路 PH1 FPGA 的多通道 ADC 采集与 UDP 传输工程，代码主体为 Verilog/SystemVerilog RTL。因此不存在软件意义上的异常/panic/middleware 错误处理体系；错误处理以**硬件信号、AXI 总线响应位、IP 核状态引脚**的形式存在。

## 观察到的错误相关机制

### 1. AXI 总线响应（bresp/rresp）
- `ad_dma_axictrl.v` 中显式将 `BRESP` 和 `RRESP` 固定赋值为 `2'b00`（OKAY），未实现非 OKAY 响应的错误分支：
  ```verilog
  assign BRESP   = 2'b00;  // OKAY
  assign RRESP   = 2'b00;  // OKAY
  ```
- 顶层 `mstar_udp_top.v` 在连接 IP 时直接透传 `s_axi_*_bresp` / `s_axi_*_rresp`，未做解析或告警。

### 2. 以太网链路错误
- `mstar_ethernet_bridge` 通过端口 `link_error` 输出链路故障状态，顶层将其反相后从 `mstar_udp_top.link_error` 暴露给外部：
  ```verilog
  wire _link_error;
  assign link_error = ~_link_error;
  ```
- LED 指示逻辑根据 `cryptopp_wdten`（加密协看门狗使能）和 `collect_doing` 闪烁，间接反映运行状态，但并非结构化错误码。

### 3. DDR/ECC 错误信号（由 IP 核产生，未被上层使用）
- `al_ip/MIS_DDR/MIS_DDR.v` 与 `ph1p_ddrmc_wrapper_MIS_DDR.v` 暴露 `ecc_err_sig[7:0]`（单比特 ECC 错误）和 `ecc_err_mul[7:0]`（多比特 ECC 错误）。
- `al_ip/MIS_DDR/src/rtl/phy/ph1p_ddrphy_mdl_cal.v` 内部有 `mdl_err` 标志位，用于模型校准失败检测。
- `al_ip/MIS_DDR/src/rtl/phy/ph1p_ddrphy_top.v` 导出 `dhi_cmd_err`（由 `~ddr_alert_n` 生成）。
- `sysPLL` 的 `drp_err` 端口在顶层实例化时被悬空（未连接）。
- **这些错误信号在 `mstar_udp_top.v` 中均未被采样、计数或上报**，属于被忽略的 IP 级诊断端口。

### 4. AXI DMA 注入错误端口（测试用，已禁用）
- `hdl/axi_dma/axi_dma_example_axi_read_master.sv` 与 `axi_dma_example_axi_write_master.sv` 中保留 `injectsbiterr` / `injectdbiterr` / `sbiterr` / `dbiterr` 端口，但全部绑定为常量 `1'b0` 或未连接，表明未启用单/双比特错误注入。

### 5. 复位与同步错误防护
- 所有跨时钟域复位均通过 `reset_sync` / `resetn_sync` 同步器处理，避免异步复位导致的亚稳态——这是硬件设计中常见的“时序错误”防护手段。

## 架构与约定

| 层面 | 做法 |
|---|---|
| 应用层（FPGA 用户逻辑） | 无结构化错误类型、无错误码枚举、无 panic/recover；业务模块通过 AXI Lite 寄存器读写配置，不返回错误值 |
| 总线层 | AXI bresp/rresp 固定为 OKAY，未检查非 OKAY 情况 |
| IP 层 | MIS_DDR / sysPLL 等 IP 提供 ECC/DRP 错误引脚，但顶层未连接 |
| 物理层 | 以太网 `link_error` 是唯一被透传到顶层的外部错误信号 |

## 约束与规则

- 本项目是纯硬件设计，不存在软件异常处理语义（无 try/catch、panic、error type、middleware）。
- 当前实现中，除以太网链路错误外，其他潜在错误（ECC、AXI 非 OKAY、PHY 命令错误、PLL DRP 错误）均被忽略，不构成可观测的错误通道。
- 该结论仅覆盖本仓库实际存在的代码；若第三方 IP 源码不在仓库内，其内部错误行为不可据此断言。

## 关键文件

- `hdl/mstar_udp_top.v` — 顶层，唯一对外暴露 `link_error`，并透传各子模块 AXI 响应位
- `hdl/collect/ad_dma_axictrl.v` — AXI Lite 控制器，固定 BRESP/RRESP=OKAY
- `hdl/udpip/mstar_ethernet_bridge.ipr.v` — 以太网桥接 IP 网表，输出 `link_error`
- `al_ip/MIS_DDR/MIS_DDR.v` / `al_ip/MIS_DDR/ph1p_ddrmc_wrapper_MIS_DDR.v` — ECC 错误信号定义（未被使用）
- `al_ip/MIS_DDR/src/rtl/phy/ph1p_ddrphy_mdl_cal.v` — 内部 `mdl_err` 标志
- `al_ip/sysPLL/sysPLL.v` — `drp_err` 端口（悬空）
- `hdl/axi_dma/axi_dma_example_axi_read_master.sv` / `axi_dma_example_axi_write_master.sv` — 禁用错误注入端口