//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: cm2268_drv
// Description: CM2268 ADC 完整驱动封装，集成 AXI Lite 寄存器接口
//              与 ADC 采样控制逻辑
//============================================================================
module cm2268_drv#(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
	parameter FREQ_DIV_MIN=50,
    parameter  MODEL_ID = 'h30001
    )(
	input  ad_clk,
	input  ad_rstn,
    input  wire                          s_axilite_clk,
    input  wire                          s_axilite_rst,
//    input  wire                          ACLK_EN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axilite_AWADDR,
    input  wire                          	s_axilite_AWVALID,
    output wire                          	s_axilite_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] 	s_axilite_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] 	s_axilite_WSTRB,
    input  wire                          	s_axilite_WVALID,
    output wire                          	s_axilite_WREADY,
    output wire [1:0]                    	s_axilite_BRESP,
    output wire                          	s_axilite_BVALID,
    input  wire                          	s_axilite_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axilite_ARADDR,
    input  wire                          	s_axilite_ARVALID,
    output wire                          	s_axilite_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] 	s_axilite_RDATA,
    output wire [1:0]                    	s_axilite_RRESP,
    output wire                          	s_axilite_RVALID,
    input  wire                          	s_axilite_RREADY,
	output 			ad_reset	,
	output 			ad_convst	,
	input  			ad_busy		,
	output 			ad_csn		,
	output       	ad_rdn		,
	output 			ad_wrn		,
	input           ad_frstdat	,
	input   [15:0] 	ad_datin	,
	output  [15:0]  ad_datout	,
	output  [1:0]   ad_datoe	,
	input 			collect_clk,
	output  [128:0] ad_data		,    
	output 			ad_daten		

	);
wire [15:0] 	freq_div;
wire			collect_en;
//wire            out_convclk_en;
wire            in_convclk_en;
//wire            ad_convst_t;
wire			modeflg; 	//0: regmode  1: admode
wire [6:0] 		ctrl_addr;
wire [31:0]		ctrl_wdata;
wire			ctrl_wrflg;	//0:write,1:read
wire [31:0]    	ctrl_rdata;
wire [1:0]     ctrl_size;
wire			ctrl_start;
wire  			ctrl_done;
wire			ad_reset_t;
assign ad_reset=ad_reset_t|(~ad_rstn);

//assign ad_convst= in_convclk_en ? ad_convst_in : ad_convst_t;
//assign ad_convst_out= out_convclk_en ? ad_convst_t : 1'b1 ;
adchip_ctrl#(
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
	.FREQ_DIV_MIN(FREQ_DIV_MIN),
    .MODEL_ID(MODEL_ID)
    ) adchip_ctrl_u0(
    .ACLK		(s_axilite_clk		),
    .ARESET		(s_axilite_rst		),
    .AWADDR		(s_axilite_AWADDR		),
    .AWVALID	(s_axilite_AWVALID	),
    .AWREADY	(s_axilite_AWREADY	),
    .WDATA		(s_axilite_WDATA		),
    .WSTRB		(s_axilite_WSTRB		),
    .WVALID		(s_axilite_WVALID		),
    .WREADY		(s_axilite_WREADY		),
    .BRESP		(s_axilite_BRESP		),
    .BVALID		(s_axilite_BVALID		),
    .BREADY		(s_axilite_BREADY		),
    .ARADDR		(s_axilite_ARADDR		),
    .ARVALID	(s_axilite_ARVALID	),
    .ARREADY	(s_axilite_ARREADY	),
    .RDATA		(s_axilite_RDATA		),
    .RRESP		(s_axilite_RRESP		),
    .RVALID		(s_axilite_RVALID		),
    .RREADY		(s_axilite_RREADY		),
	.freq_div	(freq_div		),
	.collect_en	(collect_en		),
    .ad_curdata (ad_data ),
    //.out_convclk_en(out_convclk_en),
    .in_convclk_en(in_convclk_en),
	.ad_reset	(ad_reset_t		),
	.modeflg	(modeflg		), 	//0: regmode  1: admode
	.ctrl_addr	(ctrl_addr		),
	.ctrl_size  (ctrl_size     ),
	.ctrl_wdata	(ctrl_wdata		),
	.ctrl_wrflg	(ctrl_wrflg		),	//0:write,1:read
	.ctrl_rdata	(ctrl_rdata		),
	.ctrl_start	(ctrl_start		),
	.ctrl_done	(ctrl_done		)
);
driver_cm2268#(
	.FREQ_DIV_MIN(FREQ_DIV_MIN)
)driver_cm2268_u0(
	.clk		(ad_clk), 		//100M
	.rstn		(ad_rstn),
	.freq_div	(freq_div		),
	.collect_en	(collect_en		),
    .in_convclk_en(in_convclk_en),
	.modeflg	(modeflg		), 	//0: regmode  1: admode
	.ctrl_addr	(ctrl_addr		),
	.ctrl_size  (ctrl_size     ),
	.ctrl_wdata	(ctrl_wdata		),
	.ctrl_wrflg	(ctrl_wrflg		),	//0:write,1:read
	.ctrl_rdata	(ctrl_rdata		),
	.ctrl_start	(ctrl_start		),
	.ctrl_done	(ctrl_done		),	
	.ad_convst	(ad_convst	),
	.ad_busy	(ad_busy		),
	.ad_csn		(ad_csn			),
	.ad_rdn		(ad_rdn			),
	.ad_wrn		(ad_wrn			),
	.ad_frstdat	(ad_frstdat		),
	.ad_datin	(ad_datin		),
	.ad_datout	(ad_datout		),
	.ad_datoe	(ad_datoe		),
	.collect_clk(collect_clk),
	.ad_data	(ad_data		),    
	.ad_dataen	(ad_daten		)
);


endmodule
