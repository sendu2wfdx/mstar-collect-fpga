//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: mstar_collect
// Description: 多通道数据采集顶层，集成 AXI Lite 配置接口、AD 驱动实例化
//              及采集数据缓存管理
//============================================================================
module mstar_collect
#(
	// Parameter Declarations
	parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter MODEL_ADDRESS_SPACE=C_S_AXI_ADDR_WIDTH,
	parameter integer BUFLENWIDTH = 28,
    //parameter POSITIONWIDTH=BUFLENWIDTH,
	parameter integer CHANNEL_NUM=8,
	parameter  	POART_WIDTH=6,
    parameter  MODEL_ID = 'h10001,
	parameter AD_DATWIDTH=16

)(
	// Input Ports
	
	input 									ad_clk			,
	input 									ad_rst			,
	input [AD_DATWIDTH*CHANNEL_NUM-1:0] 	ADdat			,
	input  									ADen			,
	
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
	
	output wire [AD_DATWIDTH*CHANNEL_NUM-1:0] 	tADdat,
	output wire  					tADen,
	input   [BUFLENWIDTH-1:0]   	cachsize,
    input   [BUFLENWIDTH-1:0]   	pre_cachsize,
	output                            convin_en,
	output                            convout_en,
    output          collect_doing,
	output         collect_end,
	output			out_trigflg,						//触发信号输出
	input 			in_trigflg,							//外部触发输入
	output [POART_WIDTH-1:0]                     out_port,
	input  [POART_WIDTH-1:0]                     in_port
	);
	wire                           trigout_en;
    wire                           trigin_en;
	
	
	wire [CHANNEL_NUM-1 : 0]			collect_en;
	//wire 								collect_trigen;	//使能触发
	wire 								collect_endreq;
	wire [AD_DATWIDTH*CHANNEL_NUM-1:0]	trigdat;
	wire [3*CHANNEL_NUM-1:0]				trigtype;		//触发方式＿0：不触发＿1：电平触发，2：上升沿触发＿3：下降沿触发
	wire [CHANNEL_NUM-1 : 0]			trigflg;
//    wire  [BUFLENWIDTH-1:0]   	cachsize;
//    wire  [BUFLENWIDTH-1:0]   	pre_cachsize;
	wire  [BUFLENWIDTH*CHANNEL_NUM-1:0]   	end_relative_position;
    wire  [BUFLENWIDTH*CHANNEL_NUM-1:0]   	trig_relative_position;
	wire  [CHANNEL_NUM-1:0] t_ADen;
	wire  [CHANNEL_NUM-1:0] collect_chend;
	 
	wire trig_en_in; 
	wire _in_trigflg;
    wire _in_trigflg_up;
    wire collect_end_up;
    reg in_trigflg_r;
	//reg [27:0] ledfly_cnt;
	assign tADen=|t_ADen;
	assign collect_end=collect_en>0 ? |(collect_chend&collect_en) : |(collect_chend);
	//assign collect_endreq_o=collect_endreq;
	assign out_trigflg= trigout_en&(|trigflg);
	assign _in_trigflg= trigin_en& in_trigflg;
	assign trig_en_in=|{trigflg,in_trigflg_r};
    assign collect_doing=(|collect_en);
    get_singer_edge#(.SING_WIDTH(1)) get_triger_edge_u0(.clk(ad_clk),.i_sing(_in_trigflg),.o_sing_up(_in_trigflg_up),.o_sing_down(),.o_sing_sync());
    get_singer_edge#(.SING_WIDTH(1)) get_collectend_edge_u0(.clk(ad_clk),.i_sing(collect_end),.o_sing_up(collect_end_up),.o_sing_down(),.o_sing_sync());
    always @(posedge ad_clk)begin
        if(ad_rst)begin
            in_trigflg_r<=0;
        end else begin
            if(_in_trigflg_up&& collect_en>0)begin
                in_trigflg_r<=1;
            end
            if(collect_end_up)begin
                in_trigflg_r<=0;
            end
        end
    end
Mstar_collect_ctrl#(
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .MODEL_ADDRESS_SPACE(MODEL_ADDRESS_SPACE),
    .BUFLENWIDTH(BUFLENWIDTH),
    //.POSITIONWIDTH(POSITIONWIDTH),
	.CHANNEL_NUM(CHANNEL_NUM),
	.AD_DATWIDTH(AD_DATWIDTH),
    .MODEL_ID(MODEL_ID)
    )ad_collect_trig_ctrl_u0(
     .ACLK		(s_axilite_clk			),
    .ARESET		(s_axilite_rst			),
    .AWADDR		(s_axilite_AWADDR		),
    .AWVALID	(s_axilite_AWVALID		),
    .AWREADY	(s_axilite_AWREADY		),
    .WDATA		(s_axilite_WDATA		),
    .WSTRB		(s_axilite_WSTRB		),
    .WVALID		(s_axilite_WVALID		),
    .WREADY		(s_axilite_WREADY		),
    .BRESP		(s_axilite_BRESP		),
    .BVALID		(s_axilite_BVALID		),
    .BREADY		(s_axilite_BREADY		),
    .ARADDR		(s_axilite_ARADDR		),
    .ARVALID	(s_axilite_ARVALID		),
    .ARREADY	(s_axilite_ARREADY		),
    .RDATA		(s_axilite_RDATA		),
    .RRESP		(s_axilite_RRESP		),
    .RVALID		(s_axilite_RVALID		),
    .RREADY		(s_axilite_RREADY		),
	
	.trigout_en	(trigout_en		),
    .trigin_en	(trigin_en		),
	.convin_en	(convin_en		),
	.convout_en	(convout_en		),
    .collect_en	 (collect_en			),
	//.collect_trigen	(collect_trigen		),	//使能触发
	.collect_endreq	(collect_endreq		),
	.trigdat		(trigdat			),
	.trigtype		(trigtype			),		//触发方式＿0：不触发＿1：电平触发，2：上升沿触发＿3：下降沿触发
	//.trigen			(trigen),
	.collect_end	(collect_end		),
	.trigflg		(trigflg			),
    //.cachsize		(cachsize			),
    //.pre_cachsize	(pre_cachsize		),
	.end_relative_position	(end_relative_position	),		//采样结束相对位置
	.trig_relative_position	(trig_relative_position	),		//触发的相对位罿
	.out_port(out_port),
	.in_port(in_port)
    );
	
genvar gi;
generate begin : trigger
	for(gi=0;gi<CHANNEL_NUM; gi=gi+1) begin
	triggel
		#(
			.BUFLENWIDTH		(BUFLENWIDTH),	//BUF大小宽度
			.AD_DATWIDTH		(AD_DATWIDTH)
		)triggel_u0
		(
			// Input Ports
			.clk_50M				(ad_clk	),
			.rst					(ad_rst	),
			.colection_en			(collect_en[gi]	),					//采样使能信号
			.colection_endreq		(collect_endreq),				//采样结束伸请信号
			.trigdat				(trigdat[gi*AD_DATWIDTH +: AD_DATWIDTH]	),						//触发阿忿
			.trig_type				(trigtype[gi*3 +: 3]	),						//触发方式＿0：不触发＿1：电平触发，2：上升沿触发＿3：下降沿触发
			//.trig_en				(trigen),
			.ADdat					(ADdat[gi*AD_DATWIDTH +: AD_DATWIDTH]	),
			.ADen					(ADen	),
			.cachsize				(cachsize	),						//缓存大小
			.pre_cachsize			(pre_cachsize	),					//触发前缓存大小
			.end_relative_position	(end_relative_position[BUFLENWIDTH*gi +:BUFLENWIDTH]	),		//采样结束相对位置
			.trig_relative_position	(trig_relative_position[BUFLENWIDTH*gi +:BUFLENWIDTH]	),		//触发的相对位罿
			.colection_end			(collect_chend[gi]	),						//触发结束信号
			.tADdat					(tADdat[gi*AD_DATWIDTH +: AD_DATWIDTH]	),
			.tADen					(t_ADen[gi]	),
			.trigflg				(trigflg[gi]	),
			.in_trigflg				(trig_en_in	)							//外部触发输入
		);
	end
end
endgenerate
//ChipWatcher_2 ChipWatcher_2_t
//(
//  .probe0	(convin_en),
//  .probe1	(convout_en),
//  .probe2	(trigout_en),
//  .probe3	(collect_endreq),
//  .probe4	(trigflg),
//  .probe5	(_in_trigflg),
//  .probe6	(trig_en_in),
//  .probe7	(collect_chend),
//  .probe8	(collect_end),
//  .probe9	(tADdat[15:0]),
//  .probe10	(t_ADen),
//  .probe11	(collect_en),
//  .probe12	(end_relative_position[0 +:BUFLENWIDTH]),
//  .probe13	(trig_relative_position[0 +:BUFLENWIDTH]),
//  .probe14	(cachsize),
//  .probe15	(pre_cachsize),
//  .clk   	(ad_clk)
//);
endmodule
