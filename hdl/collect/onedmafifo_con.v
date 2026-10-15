//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: onedmafifo_con
// Description: 单 DMA FIFO 控制，管理 DMA 数据通道的 FIFO 缓冲
//              与 AXI 总线读写仲裁
//============================================================================
module onedmafifo_con
#(
	// Parameter Declarations
	parameter FIFORDWN = 10,					//fifo可读数据个数宽度
	parameter FIFODATWIDTH = 128,				//fif0数据宽度
	parameter ADDRESSWIDTH=26					//BUF地址宽度
	//parameter BUFLENWIDTH=18					//BUF大小宽度	
)(
	// Input Ports
	input m_axi_clk,
	input m_axi_rst,
	input ad_clk,
	input ad_rst,
	input  wire                           s_axis_tvalid,
	input  wire  [FIFODATWIDTH-1:0]  	   s_axis_tdata,

	input 							DMA_channel_en,	//AD通道使能寄存��?
	input 							DMA_rst_req,
	output  						DMA_oksta,			//DMA状�?�寄存器
	output	reg						DMA_half_flg,
	//各�?�道缓存空间参数
	input [ADDRESSWIDTH-1:0] 		buf_base_ch,			//通道缓存基址
	input [ADDRESSWIDTH-1:0] 		buf_length_ch,		//通道缓存大小
	input  							ad_collect_endflg,			// AD采样结束标志

	// AXI4 master interface (write only)
	output wire                            m_axi_awvalid,
	input  wire                            m_axi_awready,
	output wire [ADDRESSWIDTH-1:0]         m_axi_awaddr,
	output wire [7:0]                      m_axi_awlen,

	output wire                            m_axi_wvalid,
	input  wire                            m_axi_wready,
	output wire [FIFODATWIDTH-1:0]         m_axi_wdata,
	output wire [FIFODATWIDTH/8-1:0]       m_axi_wstrb,
	output wire                            m_axi_wlast,

	input  wire                            m_axi_bvalid,
	output wire                            m_axi_bready

	
);
localparam DMALEN=256;
//模拟通道DMA使能伸请标志
wire 	w_buf_dmaen_ch;
wire  	w_dma_channel_en;
wire 	w_dma_en;
reg    [8:0] 		r_control_write_length;
//通道的当前DMA地址
reg [ADDRESSWIDTH-1:0] r_buf_curDatNum_ch;			//通道缓存数据个数

//reg  				r_dma_chdoflg;				//正在进行的DMA通道标志
reg [FIFORDWN-1 : 0] r_dma_numremain;	//单次传输余下的量
reg r_collect_end=0;
wire  				w_ad_collect_endup;
// reg [FIFORDWN-1:0] 	r_dma_rdwn; 		//DMA传输计数��?
reg  				r_dma_oksta;  		//DMA完成标志，采集完成标��?
//reg r_dma_last;							//��?后一次DMA标志��?
reg 	r_DMA_channel_entemp1=0;
reg 	r_DMA_channel_entemp2=0;
reg [1:0]	r_ad_collect_endflg=0;
reg	[1:0]	r_ad_collect_endflg_delay=0;
reg 		r_DMA_rst_req=0;
wire  	w_DMA_channel_enup;
reg   	r_DMA_chenok_clear;
 wire	 w_dma_fifo_rdempty;

wire [FIFORDWN-1:0] 			fifo_rdwn;		//可读数据个数标志

reg [ADDRESSWIDTH-5:0] 		control_write_base;
wire [13:0] 				control_write_length;
reg 						control_go;
wire 						control_done;

wire                          m_axis_tvalid;
wire                          m_axis_tready;
wire  [FIFODATWIDTH-1:0]  	  m_axis_tdata;


reg [2:0] r_dmastate;

parameter 	DMASTA_IDLE				=3'b000;
parameter 	DMASTA_DMAWAIT			=3'b001;
parameter 	DMASTA_DMAST			=3'b010;
parameter 	DMASTA_DMADO			=3'b100;

//  ChipWatcher_0 ChipWatcher_0_u0
//  (
//    .probe0	     (m_axi_awvalid	),
//    .probe1	     (m_axi_awready	),
//    .probe2	     (m_axi_awaddr	),
//    .probe3	     (m_axi_awlen	),
//    .probe4	     (m_axi_wvalid	),
//    .probe5	     (m_axi_wready	),
//    .probe6	     (m_axi_wdata[15:0]	),
//    .probe7	     (control_go  ),
//    .probe8	     (control_done	),
//    .probe9	     (r_dmastate	),
//    .probe10	 (fifo_rdwn	),
//    .probe11	 (w_buf_dmaen_ch	),
//    .probe12	 (r_buf_curDatNum_ch	),
    
//    .clk   	     (m_axi_clk	)	  
//  );

assign w_buf_dmaen_ch= (fifo_rdwn[FIFORDWN-1:FIFORDWN-2]>0)&&w_dma_channel_en;

assign control_write_length={r_control_write_length,4'b0000};
// assign dma_fifo_data		= fifo_qdat ; 
 assign w_dma_fifo_rdempty	=	fifo_rdwn==0&&ad_collect_endflg;	//dma_fifo_rdempty&ad_collect_endflg;

//DMA控制寄存器各位定义（DMA_con��?
//位[7��?0]：�?�道使能��?
assign w_dma_channel_en= r_DMA_channel_entemp2&(~r_dma_oksta); 
//��?8��?		DMA位能��?
assign w_dma_en=r_DMA_channel_entemp2;//DMA_doen;
assign DMA_oksta=r_dma_oksta;
// assign dma_datfifo_rdwn= r_dma_rdwn;
//assign w_ad_collect_endflg=r_ad_collect_endflg[1]&w_dma_channel_en;
always @(posedge ad_clk )
begin
	r_ad_collect_endflg_delay<={r_ad_collect_endflg_delay[0],ad_collect_endflg};
end
always @(posedge m_axi_clk )
begin
	r_DMA_channel_entemp1<=DMA_channel_en;
	r_DMA_channel_entemp2<=r_DMA_channel_entemp1;
	r_ad_collect_endflg<={r_ad_collect_endflg[0],r_ad_collect_endflg_delay};
	r_DMA_rst_req<=DMA_rst_req;
end
assign w_ad_collect_endup= (r_ad_collect_endflg[1]^r_ad_collect_endflg[0])&r_ad_collect_endflg[0];
assign w_DMA_channel_enup=(r_DMA_channel_entemp1^r_DMA_channel_entemp2)&r_DMA_channel_entemp1;
always @(posedge m_axi_clk or posedge m_axi_rst)
begin
	if(m_axi_rst)
	begin
		r_DMA_chenok_clear<=0;
		r_collect_end<=0;
	end
	else
	begin
	   if(w_ad_collect_endup)begin
	       r_collect_end<=1;
	   end
	   if(w_DMA_channel_enup)begin
	       r_collect_end<=0;
	   end
		if(r_dma_oksta&w_DMA_channel_enup)
		begin
			r_DMA_chenok_clear<=1;
		end
		else if(r_DMA_chenok_clear&(~r_dma_oksta))
		begin			
			r_DMA_chenok_clear<=0;
		end
	end
end
always @(posedge m_axi_clk or posedge m_axi_rst )
begin
	if(m_axi_rst)
	begin
		r_dmastate<=DMASTA_IDLE;
		r_buf_curDatNum_ch<=0;
		// r_dma_chdoflg<=0;
		control_write_base<=0;
		r_control_write_length<=0;
		r_dma_numremain<=0;
		r_dma_oksta<=1;
		//r_dma_last<=0;
		control_go<=0;
		DMA_half_flg<=0;
	end
	else
	begin
		control_go<=0;
		DMA_half_flg<=r_buf_curDatNum_ch>=buf_length_ch[ADDRESSWIDTH-1:5]&&buf_length_ch[ADDRESSWIDTH-1:5]>0;
		case(r_dmastate)
		DMASTA_IDLE:
		begin
			control_write_base<=0;
			r_control_write_length<=0;
			r_buf_curDatNum_ch<=0;
			r_dma_numremain<=0;
			
			if(w_DMA_channel_enup)
			begin
				r_dmastate<=DMASTA_DMAWAIT;
				r_dma_oksta<=0;
			end
			else
			begin
				r_dmastate<=DMASTA_IDLE;
			end
		end
		DMASTA_DMAWAIT:
		begin
			control_write_base<=buf_base_ch[ADDRESSWIDTH-1:4]+r_buf_curDatNum_ch;
			if(r_DMA_rst_req)begin
				r_dma_oksta<=1;
				r_dmastate<=DMASTA_IDLE;
			end else if(w_buf_dmaen_ch)
			begin
				r_buf_curDatNum_ch<=r_buf_curDatNum_ch+DMALEN;
				r_dma_numremain<=1;
				r_control_write_length<=DMALEN;
                
				r_dmastate<=DMASTA_DMAST;
				control_go<=1;			
			end
			else if(r_collect_end&(~r_dma_oksta))
			begin
				if(fifo_rdwn>0)
				begin
					r_buf_curDatNum_ch<=r_buf_curDatNum_ch+fifo_rdwn;
					r_dma_numremain<=0;
					r_control_write_length<=fifo_rdwn;
					r_dmastate<=DMASTA_DMAST;
					control_go<=1;//~dma_fifo_rdempty;
				end else begin
					r_dma_oksta<=1;
					r_dmastate<=DMASTA_IDLE;
				end
			end
		end
		DMASTA_DMAST:
		begin
			// control_go<=0;
			if(~control_done)
				r_dmastate<=DMASTA_DMADO;
			else
				r_dmastate<=DMASTA_DMAST;
		end
		DMASTA_DMADO:
		begin	
			if(control_done)
			begin
				if(r_dma_numremain)
				begin
					//本次传输还没有完��?
					//r_dma_numremain<=0;
					r_dmastate<=DMASTA_DMAWAIT;
					//if(r_buf_curDatNum_ch>=buf_length_ch[ADDRESSWIDTH-1:5])
					//	DMA_half_flg<=1;
					//else 
					//	DMA_half_flg<=0;
					if(buf_length_ch[ADDRESSWIDTH-1:4]==r_buf_curDatNum_ch) 
						r_buf_curDatNum_ch<=0;
				end
				else
				begin
					r_dmastate<=DMASTA_IDLE;
					r_dma_oksta<=1;
					r_buf_curDatNum_ch<=0;
					// end
				end
			end
		end
		default:
			r_dmastate<=r_dmastate;
		endcase
	end
end
reg fifo_clr=0;
reg dma_oksta_sync=0;
always @(posedge ad_clk)begin
	fifo_clr<=DMA_channel_en;
	dma_oksta_sync<=r_dma_oksta;
end
//get_singer_edge#(.SING_WIDTH(1)) get_singer_edge_u0(.clk(ad_clk),.i_sing(DMA_channel_en),.o_sing_up(),.o_sing_down(),.o_sing_sync(dma_ok_sync));
//axis_dmadat_fifo axis_dmadat_fifo_u0 (
//  .s_axis_aresetn	((~ad_rst)&fifo_clr),          // input wire s_axis_aresetn
//  .s_axis_aclk		(ad_clk),                // input wire s_axis_aclk
//  .s_axis_tvalid	(s_axis_tvalid&~dma_oksta_sync),            // input wire s_axis_tvalid
//  .s_axis_tready	(			),            // output wire s_axis_tready
//  .s_axis_tdata		(s_axis_tdata),              // input wire [127 : 0] s_axis_tdata
//  .m_axis_aclk		(m_axi_clk),                // input wire m_axis_aclk
//  .m_axis_tvalid	(m_axis_tvalid),            // output wire m_axis_tvalid
//  .m_axis_tready	(m_axis_tready),            // input wire m_axis_tready
//  .m_axis_tdata		(m_axis_tdata),              // output wire [127 : 0] m_axis_tdata
//  .axis_rd_data_count(fifo_rdwn)  // output wire [31 : 0] axis_rd_data_count
//);
axis_dmadat_fifo axis_dmadat_fifo_u0
(
  .us_aclk (ad_clk),
  .us_aresetn((~ad_rst)&fifo_clr),
  .us_tvalid(s_axis_tvalid&~dma_oksta_sync),
  .us_tready(),
  .us_tdata(s_axis_tdata),
  .ds_aclk(m_axi_clk),
  .ds_tvalid(m_axis_tvalid),
  .ds_tready(m_axis_tready),
  .ds_tdata(m_axis_tdata),
  .axis_rd_data_count(fifo_rdwn)
);
localparam integer LP_AXI_DW_BYTES             = ADDRESSWIDTH/8;
localparam integer LP_AXI_BURST_LEN            = 4096/LP_AXI_DW_BYTES < 256 ? 4096/LP_AXI_DW_BYTES : 256;
//localparam integer LP_AXI_LOG_BURST_LEN        = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_AXI_BRAM_DEPTH           = 512;
localparam integer LP_AXI_RD_MAX_OUTSTANDING   = LP_AXI_BRAM_DEPTH / LP_AXI_BURST_LEN;
localparam integer LP_OUT_RD_MAX_OUTSTANDING   = LP_AXI_RD_MAX_OUTSTANDING; 

axi_dma_example_axi_write_master #(
  .C_M_AXI_ADDR_WIDTH  ( ADDRESSWIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( FIFODATWIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( 14     ) ,
  .C_MAX_OUTSTANDING   ( LP_OUT_RD_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 0                     )
)
axi_dma_example_axi_write_master_u0 (
  .aclk                    ( m_axi_clk               ) ,
  .areset                  (m_axi_rst ) ,
  .ctrl_start              ( control_go             	) ,
  .ctrl_done               ( control_done              ) ,
  .ctrl_addr_offset        ( {control_write_base,4'b0000}) ,
  .ctrl_xfer_size_in_bytes ( control_write_length 	 ) ,
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
  .m_axi_bready            ( m_axi_bready            ) ,

  .s_axis_tvalid           ( m_axis_tvalid           ) ,
  .s_axis_tready           ( m_axis_tready           ) ,
  .s_axis_tdata            ( m_axis_tdata     )
);	
		
endmodule