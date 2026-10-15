//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: mstar_collectdma
// Description: 采集数据 DMA 引擎，通过 AXI Full 接口将缓冲区数据
//              搬运至 DDR
//============================================================================
module mstar_collectdma
#(
	// Parameter Declarations
	parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter  MODEL_ID = 'h20001,
	parameter integer C_M_AXI_ADDR_WIDTH = 28,
    //parameter integer C_M_AXIS_DATA_WIDTH = 64;
	parameter integer C_M_AXI_DATA_WIDTH = 128
)(
	// Input Ports
	
	input 									ad_clk			,
	input 									ad_rst			,
	input  wire                            	s_axis_tvalid	,
	input  wire  [C_M_AXI_DATA_WIDTH-1:0]  	s_axis_tdata	,
	
	input  wire                          	s_axilite_clk		,
    input  wire                          	s_axilite_rst		,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axilite_AWADDR	,
    input  wire                          	s_axilite_AWVALID	,
    output wire                          	s_axilite_AWREADY	,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] 	s_axilite_WDATA		,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] 	s_axilite_WSTRB		,
    input  wire                          	s_axilite_WVALID	,
    output wire                          	s_axilite_WREADY	,
    output wire [1:0]                    	s_axilite_BRESP		,
    output wire                          	s_axilite_BVALID	,
    input  wire                          	s_axilite_BREADY	,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axilite_ARADDR	,
    input  wire                          	s_axilite_ARVALID	,
    output wire                          	s_axilite_ARREADY	,
    output wire [C_S_AXI_DATA_WIDTH-1:0] 	s_axilite_RDATA		,
    output wire [1:0]                    	s_axilite_RRESP		,
    output wire                          	s_axilite_RVALID	,
    input  wire                          	s_axilite_RREADY	,

	// AXI4 master interface (write only)
	input 									m_axi_clk		,
	input 									m_axi_rst		,
	output wire                            	m_axi_awvalid	,
	input  wire                            	m_axi_awready	,
	output wire [C_M_AXI_ADDR_WIDTH-1:0]   	m_axi_awaddr	,
	output wire [7:0]                      	m_axi_awlen		,

	output wire                            	m_axi_wvalid	,
	input  wire                            	m_axi_wready	,
	output wire [C_M_AXI_DATA_WIDTH-1:0]   	m_axi_wdata		,
	output wire [C_M_AXI_DATA_WIDTH/8-1:0] 	m_axi_wstrb		,
	output wire                            	m_axi_wlast		,

	input  wire                            	m_axi_bvalid	,
	output wire                            	m_axi_bready	,
    output                              DMA_oksta,
	output  [C_M_AXI_ADDR_WIDTH-1:0]   	buflen,
    output  [C_M_AXI_ADDR_WIDTH-1:0]   	pre_buflen,
	input         collect_end
);

	wire						DMA_channel_en;	//AD通道使能寄存��?
	wire						DMA_rst_req;
    wire                        DMA_half_flg;
	//wire 						DMA_oksta;			//DMA状濁寄存��?
	//各鿚道缓存空间参��?
	wire [C_M_AXI_ADDR_WIDTH-1:0] 		buf_base_ch;			//通道缓存基址
	wire [C_M_AXI_ADDR_WIDTH-1:0] 		buf_length_ch;		//通道缓存大小
	//wire  							ad_collect_endflg;			// AD采样结束标志
	assign buflen=buf_length_ch;
ad_dma_axictrl#(
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .M_DMA_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
    .MODEL_ID(MODEL_ID)
    ) ad_dma_axictrl_u0(
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
	
    .DMA_channel_en	(DMA_channel_en	),
	.DMA_rst_req	(DMA_rst_req	),
	.dma_OK			(DMA_oksta	),
    .DMA_half_flg   (DMA_half_flg),
    .buf_baseaddr	(buf_base_ch	),
    .buf_length		(buf_length_ch	),
    .buf_pretriglen   (pre_buflen  )
    );	
onedmafifo_con
#(
	.FIFODATWIDTH		(C_M_AXI_DATA_WIDTH),				//fif0数据宽度
	.ADDRESSWIDTH		(C_M_AXI_ADDR_WIDTH)					//BUF地址宽度
	//.BUFLENWIDTH		(18)					//BUF大小宽度	
) onedmafifo_con_u0(
	// Input Ports
	.m_axi_clk			(m_axi_clk	),
	.m_axi_rst			(m_axi_rst	),
	.ad_clk		(ad_clk	),
	.ad_rst		(ad_rst	),
	.s_axis_tvalid	(s_axis_tvalid	),
	.s_axis_tdata	(s_axis_tdata),
                  
	.DMA_channel_en	(DMA_channel_en	),	//AD通道使能寄存��?
	.DMA_rst_req	(DMA_rst_req	),
	.DMA_oksta		(DMA_oksta	),			//DMA状濁寄存��?
    .DMA_half_flg   (DMA_half_flg),
	//各鿚道缓存空间参��?
	.buf_base_ch		(buf_base_ch	),			//通道缓存基址
	.buf_length_ch		(buf_length_ch	),		//通道缓存大小
	.ad_collect_endflg	(collect_end	),			// AD采样结束标志
	
	.m_axi_awvalid           ( m_axi_awvalid           ) ,
	.m_axi_awready           ( m_axi_awready           ) ,
	.m_axi_awaddr            ( m_axi_awaddr            ) ,
	.m_axi_awlen             ( m_axi_awlen             ) ,
	.m_axi_wvalid            ( m_axi_wvalid            ) ,
	.m_axi_wready            ( m_axi_wready            ) ,
	.m_axi_wdata             ( m_axi_wdata             ) ,
	.m_axi_wstrb             ( m_axi_wstrb             ) ,
	.m_axi_wlast             ( m_axi_wlast             ) ,
	.m_axi_bvalid            ( m_axi_bvalid            ) ,
	.m_axi_bready            ( m_axi_bready            ) 

	
	
);
endmodule
