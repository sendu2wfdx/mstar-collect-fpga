`timescale 1ns / 1ps
//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: Mstar_collect_ctl
// Description: 采集控制逻辑，管理 DMA 缓冲区的读写指针、缓冲区切换
//              及采集状态机
//============================================================================
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Mstar_collect_ctrl#(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
	parameter MODEL_ADDRESS_SPACE=8,
	parameter BUFLENWIDTH=28,
    //parameter POSITIONWIDTH=BUFLENWIDTH-3,
	parameter integer CHANNEL_NUM=8,
	parameter  	AD_DATWIDTH=16,
	parameter  	POART_WIDTH=6,
    parameter  MODEL_ID = 'h00010001
    )(
     input  wire                          ACLK,
    input  wire                          ARESET,
//    input  wire                          ACLK_EN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  wire                          AWVALID,
    output wire                          AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  wire                          WVALID,
    output wire                          WREADY,
    output wire [1:0]                    BRESP,
    output wire                          BVALID,
    input  wire                          BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  wire                          ARVALID,
    output wire                          ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] RDATA,
    output wire [1:0]                    RRESP,
    output wire                          RVALID,
    input  wire                          RREADY,
	output reg                           trigout_en=0,
    output reg                           trigin_en=0,
	output reg                           convin_en=0,
	output reg                           convout_en=0,
    output  [CHANNEL_NUM-1:0]		 collect_en,
	//output reg [1:0]					collect_trigen,	//使能触发 bit0：内部触发使能，bit1:外部触发使能;
	output reg 							collect_endreq,
	output reg [AD_DATWIDTH*CHANNEL_NUM-1:0]	trigdat,
	output reg [3*CHANNEL_NUM-1:0]					trigtype,		//触发方式＿0：不触发＿1：电平触发，2：上升沿触发＿3：下降沿触发
	input								collect_end,
	input [CHANNEL_NUM-1:0]		 trigflg,
	input   [BUFLENWIDTH*CHANNEL_NUM-1:0]			end_relative_position,
	input   [BUFLENWIDTH*CHANNEL_NUM-1:0]			trig_relative_position,
	output [POART_WIDTH-1:0]                     out_port,
	input  [POART_WIDTH-1:0]                     in_port
    );
    localparam ADDR_MODEL_ID					= 0; 
	localparam ADDR_OUTPORT                     = ADDR_MODEL_ID+4;
	localparam ADDR_INPORT                      = ADDR_OUTPORT+4;
	localparam ADDR_ENABLEFLG					=	'h20;
    localparam ADDR_CONSTA						=	ADDR_ENABLEFLG+4;									//0
	localparam ADDR_CH0_TRIGTYPE				=	ADDR_CONSTA+4;
	localparam ADDR_CH0_TRIDDAT					=	ADDR_CH0_TRIGTYPE+4;
	localparam ADDR_CH0_ENDCOLLECTPOS			=  	ADDR_CH0_TRIDDAT+4;				//2
	localparam ADDR_CH0_TRIGCOLLECTPOS			=  	ADDR_CH0_ENDCOLLECTPOS+4;

    
	reg [CHANNEL_NUM-1:0]		 collect_chen;
	reg                          collect_allen;
    
// ChipWatcher_0 ChipWatcher_0_u0
//  (
//    .probe0	     (AWADDR	),
//    .probe1	     (AWVALID	),
//    .probe2	     (AWREADY	),
//    .probe3	     (WDATA	),
//    .probe4	     (WVALID	),
//    .probe5	     (WREADY	),
//    .probe6	     (collect_chen	),
//    .probe7	     (collect_allen  ),
//    .clk   	     (ACLK	)	  
//  );
	
	 reg [POART_WIDTH-1:0] out_io;
	 assign out_port=~out_io;
	localparam     WRIDLE               = 2'd0,
                    WRDATA               = 2'd1,
                    WRRESP               = 2'd2,
                    WRRESET              = 2'd3,
                    RDIDLE               = 2'd0,
                    RDDATA               = 2'd1,
                    RDRESET              = 2'd2,
                    ADDR_BITS         = C_S_AXI_ADDR_WIDTH;
//------------------------Local signal-------------------
    reg  [1:0]                    wstate = WRRESET;
    reg  [1:0]                    wnext;
    reg  [ADDR_BITS-1:0]          waddr;
    wire [31:0]                   wmask;
    wire                          aw_hs;
    wire                          w_hs;
    reg  [1:0]                    rstate = RDRESET;
    reg  [1:0]                    rnext;
    reg  [31:0]                   rdata;
    wire                          ar_hs;
    wire [ADDR_BITS-1:0]          raddr;
    
//------------------------AXI write fsm------------------
assign AWREADY = (wstate == WRIDLE);
assign WREADY  = (wstate == WRDATA);
assign BRESP   = 2'b00;  // OKAY
assign BVALID  = (wstate == WRRESP);
assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
assign aw_hs   = AWVALID & AWREADY;
assign w_hs    = WVALID & WREADY;

// wstate
always @(posedge ACLK) begin
    if (ARESET)
        wstate <= WRRESET;
    else 
        wstate <= wnext;
end

// wnext
always @(*) begin
    case (wstate)
        WRIDLE:
            if (AWVALID)
                wnext = WRDATA;
            else
                wnext = WRIDLE;
        WRDATA:
            if (WVALID)
                wnext = WRRESP;
            else
                wnext = WRDATA;
        WRRESP:
            if (BREADY)
                wnext = WRIDLE;
            else
                wnext = WRRESP;
        default:
            wnext = WRIDLE;
    endcase
end

// waddr
always @(posedge ACLK) begin
//    if (ACLK_EN) begin
        if (aw_hs)
            waddr <= AWADDR[ADDR_BITS-1:0];
//    end
end

//------------------------AXI read fsm-------------------
assign ARREADY = (rstate == RDIDLE);
assign RDATA   = rdata;
assign RRESP   = 2'b00;  // OKAY
assign RVALID  = (rstate == RDDATA);
assign ar_hs   = ARVALID & ARREADY;
assign raddr   = ARADDR[ADDR_BITS-1:0];
always @(posedge ACLK) begin
    if (ARESET)
        rstate <= RDRESET;
    else 
        rstate <= rnext;
end

// rnext
always @(*) begin
    case (rstate)
        RDIDLE:
            if (ARVALID)
                rnext = RDDATA;
            else
                rnext = RDIDLE;
        RDDATA:
            if (RREADY & RVALID)
                rnext = RDIDLE;
            else
                rnext = RDDATA;
        default:
            rnext = RDIDLE;
    endcase
end
wire collect_end_up;
wire collect_end_sync;
get_singer_edge#(.SING_WIDTH(1)) get_singer_edge_u0(.clk(ACLK),.i_sing(collect_end),.o_sing_up(collect_end_up),.o_sing_down(),.o_sing_sync(collect_end_sync));
integer ci;
always @(posedge ACLK) begin
    if (ar_hs) begin
        rdata <= 'b0;
        if(raddr==ADDR_MODEL_ID)	begin rdata<=MODEL_ID;	end
		if(raddr==ADDR_OUTPORT)		begin rdata[POART_WIDTH-1:0]<=out_io;	end
		if(raddr==ADDR_INPORT)		begin rdata[POART_WIDTH-1:0]<=in_port;	end
		//if(raddr==ADDR_AD_MODEL_ID)		begin rdata[POART_WIDTH-1:0]<=out_io;	end
		//if(raddr==ADDR_DMA_MODEL_ID)		begin rdata[POART_WIDTH-1:0]<=in_port;	end
		if(raddr==ADDR_ENABLEFLG)	begin rdata[31:24]<=MODEL_ADDRESS_SPACE;rdata[23:16]<=BUFLENWIDTH;rdata[3:0]<={trigout_en,trigin_en,convout_en,convin_en}; 	end
        if(raddr==ADDR_CONSTA)	begin rdata[31:24]<=CHANNEL_NUM;rdata[23:16]<=AD_DATWIDTH;rdata[8]<=collect_end_sync;rdata[1:0]<={collect_endreq,collect_allen}; 	end
		//if(raddr==ADDR_CONSTA)	begin rdata[31:16]<=AD_DATWIDTH;rdata[8]<=collect_end_sync;rdata[1:0]<={collect_endreq,collect_allen}; 	end
		for(ci=0;ci<CHANNEL_NUM;ci=ci+1)begin
			if(raddr==(ADDR_CH0_TRIGTYPE+ci*16))        begin rdata[16]<=trigflg[ci];rdata[3:0]<= {trigtype[ci*3 +:3],collect_chen[ci]};end
			if(raddr==(ADDR_CH0_TRIDDAT+ci*16)) 		begin rdata[AD_DATWIDTH-1:0]<= trigdat[ci*AD_DATWIDTH +:AD_DATWIDTH];end
			if(raddr==(ADDR_CH0_ENDCOLLECTPOS+ci*16))   begin rdata[BUFLENWIDTH-1:0]<= end_relative_position[ci*BUFLENWIDTH +:BUFLENWIDTH];end
			if(raddr==(ADDR_CH0_TRIGCOLLECTPOS+ci*16))  begin rdata[BUFLENWIDTH-1:0]<=trig_relative_position[ci*BUFLENWIDTH +:BUFLENWIDTH];end
		end
    end
end
always @(posedge ACLK) begin
	if (ARESET)begin
		out_io <= 0;
	end else  begin
		if (w_hs && waddr == ADDR_OUTPORT)begin
			out_io<= WDATA[POART_WIDTH-1:0];
		end
	end
end
always @(posedge ACLK) begin
	if (ARESET)begin
		{trigout_en,trigin_en,convout_en,convin_en} <= 0;
	end else  begin
		if (w_hs && waddr == ADDR_ENABLEFLG)begin
			{trigout_en,trigin_en,convout_en,convin_en}<= WDATA[3:0];
		end
	end
end
always @(posedge ACLK) begin
    if (ARESET) begin
        collect_allen <= 0;
        collect_endreq<=0;
		//collect_trigen<=0;
		//trigtype<=0;
    end else  begin 
        if(collect_end_up)begin
            collect_allen<=0;
            collect_endreq<=0;
        end else if (w_hs && waddr == ADDR_CONSTA)
			if(collect_en& WDATA[1])
				collect_endreq<= WDATA[1];
			else if(WDATA[0])
				collect_allen<=WDATA[0];
    end
end


genvar gi;
generate begin : wregvar
	for(gi=0;gi<CHANNEL_NUM; gi=gi+1) begin
		assign collect_en[gi]= collect_chen[gi]&collect_allen;
		always @(posedge ACLK) begin
			if (ARESET)begin
				collect_chen[gi] <= 0;
				trigtype[gi*3 +: 3]<=0;
			end else  begin
				if (w_hs && waddr == (ADDR_CH0_TRIGTYPE+gi*16))begin
					collect_chen[gi]<= WDATA[0];
					trigtype[gi*3 +: 3]<= WDATA[3:1];
				end
			end
		end
		always @(posedge ACLK) begin
			if (ARESET)
				trigdat[gi*AD_DATWIDTH +: AD_DATWIDTH] <= 0;
			else  begin
				if (w_hs && waddr == (ADDR_CH0_TRIDDAT + gi*16))
					trigdat[gi*AD_DATWIDTH +: AD_DATWIDTH]<= WDATA[AD_DATWIDTH-1:0];
			end
		end
	end
end
endgenerate
endmodule