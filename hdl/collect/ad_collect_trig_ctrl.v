`timescale 1ns / 1ps
//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: ad_collect_trig_ctrl
// Description: AD 采集触发控制，处理外部触发信号、触发模式配置
//              及触发状态管理
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


module ad_collect_trig_ctrl#(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
	parameter BUFLENWIDTH=32,
	parameter [15:0] AD_DATWIDTH=32,
    parameter  MODEL_ID = 'h40001
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
    output reg 							collect_en,
	output reg [1:0]					collect_trigen,	//使能触发 bit0：内部触发使能，bit1:外部触发使能;
	output reg 							collect_endreq,
	output reg [AD_DATWIDTH-1:0]	trigdat,
	output reg [2:0]					trigtype,		//触发方式��?0：不触发��?1：电平触发，2：上升沿触发��?3：下降沿触发
	output reg [1:0]					trigen,
	input								collect_end,
	input      							trigflg,
	input   [BUFLENWIDTH-1:0]			end_relative_position,
	input   [BUFLENWIDTH-1:0]			trig_relative_position
    );
    localparam ADDR_MODEL_ID				= 0;    
    localparam ADDR_CONSTA					=	ADDR_MODEL_ID+4;									//0
	localparam ADDR_TRIGTYPE				=	ADDR_CONSTA+4;
	localparam ADDR_TRIDDAT					=	ADDR_TRIGTYPE+4;
	localparam ADDR_ENDCOLLECTPOS			=  ADDR_TRIDDAT+4;				//2
	localparam ADDR_TRIGCOLLECTPOS			=  ADDR_ENDCOLLECTPOS+4;

    
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
//  ChipWatcher_0 ChipWatcher_0_u0
//  (
//    .probe0	     (AWADDR	),
//    .probe1	     (AWVALID	),
//    .probe2	     (AWREADY	),
//    .probe3	     (WDATA	    ),
//    .probe4	     (WVALID	),
//    .probe5	     (WREADY	),
//    .probe6	     (ARADDR	  ),
//    .probe7	     (ARVALID	  ),
//    .probe8	     (ARREADY		),
//    .probe9	     (RDATA	    	),
//    .probe10	 (RVALID	  ),
//    .probe11	 (RREADY	  ),
//    .probe12	 (collect_en	  ),
//    .probe13	 (collect_endreq	  ),
//    .probe14	 (trigtype	  ),
//    .probe15	 (trigdat	  ),
//    .clk   	     (ACLK	)	  
//  );
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
always @(posedge ACLK) begin
    if (ar_hs) begin
        rdata <= 'b0;
        case (raddr)
        ADDR_MODEL_ID:	begin rdata<=MODEL_ID;	end
        ADDR_CONSTA:	begin rdata[31:16]<=AD_DATWIDTH;rdata[7]<=collect_end_sync;rdata[1:0]<={collect_endreq,collect_en}; 	end
		ADDR_TRIGTYPE:	begin rdata[4:0]<= {trigtype,trigen};end
		ADDR_TRIDDAT: 	begin rdata[AD_DATWIDTH-1:0]<= trigdat;end
		ADDR_ENDCOLLECTPOS: begin rdata<=end_relative_position;end
		ADDR_TRIGCOLLECTPOS: begin rdata<=trig_relative_position;end
        endcase
    end
end

always @(posedge ACLK) begin
    if (ARESET) begin
        collect_en <= 0;
        collect_endreq<=0;
		collect_trigen<=0;
		//trigtype<=0;
    end else  begin 
        if(collect_end_up)begin
            collect_en<=0;
            collect_endreq<=0;
        end else if (w_hs && waddr == ADDR_CONSTA)
			if(collect_en& WDATA[1])
				collect_endreq<= WDATA[1];
			else if(WDATA[0])
				collect_en<=WDATA[0];
    end
end
always @(posedge ACLK) begin
    if (ARESET)begin
        trigen <= 0;
		trigtype<=0;
    end else  begin
        if (w_hs && waddr == ADDR_TRIGTYPE)begin
            trigen<= WDATA[1:0];
			trigtype<= WDATA[4:2];
		end
    end
end
always @(posedge ACLK) begin
    if (ARESET)
        trigdat <= 0;
    else  begin
        if (w_hs && waddr == ADDR_TRIDDAT)
            trigdat<= WDATA[AD_DATWIDTH-1:0];
    end
end
endmodule
