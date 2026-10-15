`timescale 1ns / 1ps
//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: mstar_axilite_io
// Description: AXI Lite 寄存器 IO 模块，提供上位机与 FPGA 内部寄存器
//              的读写接口
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


module mstar_axilite_io#(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter          MODEL_ID = 'h10000
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
    
	output [3:0]                     out_led,
	input  [1:0]                         in_io


    );
    localparam ADDR_ID					    = 0;
    localparam ADDR_SYSCON					= ADDR_ID+4;
    localparam ADDR_OUT_REG                 = ADDR_SYSCON+4;
	localparam ADDR_IN_REG                  = ADDR_OUT_REG+4;



    reg [3:0] out_io;
    assign out_led=~out_io;
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
//get_singer_edge#(.SING_WIDTH(IRQ_BIT_WIDTH)) get_singer_edge_u0(.clk(ACLK),.i_sing(i_irq),.o_sing_up(i_irq_up),.o_sing_down());
always @(posedge ACLK) begin
    if (ar_hs) begin
        rdata <= 'b0;
        case (raddr)
        ADDR_ID:	         begin rdata<=MODEL_ID;	end
        ADDR_SYSCON:	     begin rdata[1:0]<={trigout_en,trigin_en};	end
        ADDR_OUT_REG:	     begin rdata[3:0]<=out_io;	end
		ADDR_IN_REG:	     begin rdata[1:0]<=in_io;	end
        endcase
    end
end
always @(posedge ACLK) begin
    if (ARESET) begin
		{trigout_en,trigin_en}<=0;
    end else  begin
        if (w_hs && waddr == ADDR_SYSCON)
            {trigout_en,trigin_en}<= WDATA[1:0];
    end
end
always @(posedge ACLK) begin
    if (ARESET) begin
		out_io<=0;
    end else  begin
        if (w_hs && waddr == ADDR_OUT_REG)
            out_io<= WDATA[3:0];
    end
end

   
endmodule