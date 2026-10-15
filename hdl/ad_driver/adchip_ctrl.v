//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: adchip_ctrl
// Description: AD 芯片控制顶层，通过 AXI Lite 寄存器接口配置采集参数
//              并桥接底层 ADC 驱动
//============================================================================
module adchip_ctrl#(
    parameter integer C_S_AXI_ADDR_WIDTH = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
	parameter FREQ_DIV_MIN=100,
    parameter  MODEL_ID = 'h30001
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
    input   [128:0]     ad_curdata,
    //output reg          out_convclk_en=0,
    output reg          in_convclk_en=0,
    output reg [15:0] 	freq_div,
	output reg			collect_en,
	output reg          ad_reset,
	input 				modeflg, 	//0: regmode  1: admode
	output reg [6:0] 	ctrl_addr,
	output reg [1:0]    ctrl_size, //num dat byte
	output reg [31:0]	ctrl_wdata,
	output reg			ctrl_wrflg,	//0:write,1:read
	input   	[31:0]  ctrl_rdata,
	output reg			ctrl_start,
	input       		ctrl_done
	
    );
    localparam ADDR_MODEL_ID			= 0;    
    localparam ADDR_CON					=	ADDR_MODEL_ID+4;
	localparam ADDR_WDATA				=	ADDR_CON+4;
	localparam ADDR_RDATA				=	ADDR_WDATA+4;
	localparam ADDR_FREQDIV				=	ADDR_RDATA+4;
    localparam ADDR_ADDATA0				=	ADDR_FREQDIV+4;
	localparam ADDR_ADDATA1				=	ADDR_ADDATA0+4;
    localparam ADDR_ADDATA2				=	ADDR_ADDATA1+4;
    localparam ADDR_ADDATA3				=	ADDR_ADDATA2+4;
    
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
wire ctrl_done_up;
wire ctrl_done_sync;
get_singer_edge#(.SING_WIDTH(1)) get_singer_edge_u0(.clk(ACLK),.i_sing(ctrl_done),.o_sing_up(ctrl_done_up),.o_sing_down(),.o_sing_sync(ctrl_done_sync));
always @(posedge ACLK) begin
    if (ar_hs) begin
        rdata <= 'b0;
        case (raddr)
        ADDR_MODEL_ID:	begin rdata<=MODEL_ID;	end
        ADDR_CON:	begin 
			rdata[3:0]<={ad_reset,ctrl_wrflg,ctrl_start,collect_en};
			rdata[5:4]<=ctrl_size;
            rdata[7]  <= {in_convclk_en};  	
			rdata[14:8]<=ctrl_addr;
			rdata[17:16]<={ctrl_done_sync,modeflg};
		end
		ADDR_WDATA:	     begin rdata<=ctrl_wdata;	end
		ADDR_RDATA:	     begin rdata<=ctrl_rdata;	end
		ADDR_FREQDIV:	 begin rdata[15:0]<=freq_div;	end
        ADDR_ADDATA0:   begin rdata<=ad_curdata[31:0];	end
        ADDR_ADDATA1:   begin rdata<=ad_curdata[63:32];	end
        ADDR_ADDATA2:   begin rdata<=ad_curdata[95:64];	end
        ADDR_ADDATA3:   begin rdata<=ad_curdata[127:96];end
        endcase
    end
end
always @(posedge ACLK) begin
    if (ARESET) begin
        collect_en <= 0;
		ad_reset<=0;
		ctrl_start<=0;
		ctrl_wrflg<=0;
		ctrl_addr<=0;
        in_convclk_en<=0;
    end else  begin 
		if(ctrl_done_up)begin
			ctrl_start<=0;		
		end else if (w_hs && waddr == ADDR_CON)begin
			if(WDATA[3])begin
				ad_reset<=1;
				collect_en <= 0;
				ctrl_start<=0;
			end else begin
				collect_en<=WDATA[0];
				ad_reset<=0;
                in_convclk_en<=WDATA[7];
				if(~WDATA[0])begin
					{ctrl_wrflg,ctrl_start}<=WDATA[2:1];
					ctrl_size<=WDATA[5:4];
					ctrl_addr<=WDATA[14:8];
				end
			end
		end
		
    end
end

always @(posedge ACLK) begin
    if (ARESET)
        ctrl_wdata <= 0;
    else  begin
        if (w_hs && waddr == ADDR_WDATA) begin
			ctrl_wdata <= WDATA;
		end
    end
end  

always @(posedge ACLK) begin
    if (ARESET)
        freq_div <= FREQ_DIV_MIN;
    else  begin
        if (w_hs && waddr == ADDR_FREQDIV) begin
			if(WDATA[15:0]<FREQ_DIV_MIN)
				freq_div <= FREQ_DIV_MIN;
			else
				freq_div <= WDATA[15:0];
		end
    end
end  

endmodule
