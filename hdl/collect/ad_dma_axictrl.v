`timescale 1ns / 1ps
//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: ad_dma_axictrl
// Description: AD 数据 DMA 的 AXI 总线控制逻辑，管理 DMA 读写时序
//              与地址生成
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


module ad_dma_axictrl#(
    //parameter CH_NUMBER=0,
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter         M_DMA_ADDR_WIDTH   = 27,
    parameter  MODEL_ID = 'h20001
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
    output reg DMA_channel_en,
	output reg DMA_rst_req,
	input      dma_OK,
    input      DMA_half_flg,
    output  reg [M_DMA_ADDR_WIDTH-1:0]   buf_baseaddr,
    output  reg [M_DMA_ADDR_WIDTH-1:0]   buf_length,
    output  reg [M_DMA_ADDR_WIDTH-1:0]   buf_pretriglen
    );
    localparam ADDR_ADMA_ID					    = 0;    
    localparam ADDR_DMACON						=	ADDR_ADMA_ID+4;									//0
	localparam ADDR_BUFBASE					=	ADDR_DMACON+4;				//1
	localparam ADDR_BUFLEN					=  ADDR_BUFBASE+4;				//2
	localparam ADDR_PREBUF                 = ADDR_BUFLEN+4;

    wire dma_ok_up;
    wire dma_ok_sync;
    reg DMA_half_flg_t;
    // reg [2:0] rst_delay_cnt; 
    // wire [31:0] frame_addr_cnt;
    // wire s_axis_tready;
    // wire s_axis_tvalid;
    // wire [31:0] s_axis_tdata;
    
    // assign s_axis_tvalid=w_hs && waddr == ADDR_FRAME_BUFFERADDR;
    // assign s_axis_tdata=WDATA;
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
//    .probe12	 (DMA_channel_en	  ),
//    .probe13	 (DMA_rst_req	  ),
//    .probe14	 (dma_ok_sync	  ),
//    //.probe15	 (trigdat	  ),
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


get_singer_edge#(.SING_WIDTH(1)) get_singer_edge_u0(.clk(ACLK),.i_sing(dma_OK),.o_sing_up(dma_ok_up),.o_sing_down(),.o_sing_sync(dma_ok_sync));

always @(posedge ACLK) begin
    DMA_half_flg_t<=DMA_half_flg;
    if (ar_hs) begin
        rdata <= 'b0;
        case (raddr)
        ADDR_ADMA_ID:	   begin rdata<=MODEL_ID;	end
        ADDR_DMACON:	   begin rdata[17:16]<={DMA_half_flg_t,dma_ok_sync};rdata[1:0]<={DMA_rst_req,DMA_channel_en}; 	end
        ADDR_BUFBASE:      begin rdata[M_DMA_ADDR_WIDTH-1:0]<= buf_baseaddr;end
        ADDR_BUFLEN:	   begin rdata[M_DMA_ADDR_WIDTH-1:0]<=buf_length;end
        ADDR_PREBUF:	   begin rdata[M_DMA_ADDR_WIDTH-1:0]<=buf_pretriglen;end
        endcase
    end
end
always @(posedge ACLK) begin
    if (ARESET) begin
        DMA_channel_en <= 0;
        DMA_rst_req<=0;
    end else  begin 
        if(dma_ok_up)begin
            DMA_channel_en<=0;
            DMA_rst_req<=0;
        end else if (w_hs && waddr == ADDR_DMACON)
			if(DMA_channel_en& WDATA[1])
				DMA_rst_req<= WDATA[1];
			else if(WDATA[0])
				DMA_channel_en<=WDATA[0];
    end
end
always @(posedge ACLK) begin
    if (ARESET)
        buf_baseaddr <= 0;
    else  begin
        if (w_hs && waddr == ADDR_BUFBASE)
            buf_baseaddr<= WDATA[M_DMA_ADDR_WIDTH-1:0];
    end
end
always @(posedge ACLK) begin
    if (ARESET)
        buf_length <= 0;
    else  begin
        if (w_hs && waddr == ADDR_BUFLEN)
            buf_length<= WDATA[M_DMA_ADDR_WIDTH-1:0];
    end
end 
always @(posedge ACLK) begin
    if (ARESET)
        buf_pretriglen <= 0;
    else  begin
        if (w_hs && waddr == ADDR_PREBUF)
            buf_pretriglen<= WDATA[M_DMA_ADDR_WIDTH-1:0];
    end
end    
endmodule
