//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: mstar_axifulltopaxi
// Description: AXI Full 到 AXI 协议转换桥，实现 AXI Full 128-bit 数据总线
//              与内部 AXI 接口的适配
//============================================================================
module mstar_axifulltopaxi#(
    parameter integer C_AXI_ADDR_WIDTH = 25,
    parameter integer C_AXI_DATA_WIDTH = 128
    )(
		input                         ref_clk,
		input                         sys_rst_n,
		input                         apb_pclk,
		input                         apb_prst_n,
		output                        apb_pready,
		input                         apb_psel,
		input                         apb_penable,
		input                         apb_pwrite,
		input   [15:0]                apb_paddr,
		input   [31:0]                apb_pwdata,
		output  [31:0]                apb_prdata,
		output                        dhi_clk,
		output                        cfg_clk,
		output                        cfg_rst_n,
		output                        ddrphy_rst_n,
		output                        ddrphy_rdy,
		
		input 									axi_aclk,
		input 								 axi_aresetn,
		input wire                             axi_awvalid,
		output  wire                           axi_awready,
		input wire [C_AXI_ADDR_WIDTH:0]      axi_awaddr ,
		input wire [8-1:0]                     axi_awlen  ,
		input wire                             axi_wvalid ,
		output  wire                           axi_wready ,
		input wire [C_AXI_DATA_WIDTH-1:0]      axi_wdata  ,
		input wire [C_AXI_DATA_WIDTH/8-1:0]    axi_wstrb  ,
		input wire                             axi_wlast  , 
		output [1:0]                           axi_bresp	,
		output  reg                            axi_bvalid ,
		input wire                             axi_bready ,
		input wire                             axi_arvalid,
		output  wire                           axi_arready,
		input wire [C_AXI_ADDR_WIDTH:0]        axi_araddr ,
		input wire [8-1:0]                     axi_arlen  ,
		output  wire                           axi_rvalid ,
		input wire                             axi_rready ,
		output [1:0]                           axi_rresp,
		output  wire [C_AXI_DATA_WIDTH-1:0]    axi_rdata  ,
		output  wire                           axi_rlast,

		input   [1:0]                 usr_ref_type,
		input                         usr_ref_req,
		output                        usr_ref_ack,
		output  [0:0]                 ddr_ck_p,
		output  [0:0]                 ddr_ck_n,
		output  [0:0]                 ddr_cke,
		output  [0:0]                 ddr_odt,
		output  [0:0]                 ddr_cs_n,
		output  [0:0]                 ddr_ras_n,
		output  [0:0]                 ddr_cas_n,
		output  [0:0]                 ddr_we_n,
		output  [1:0]                 ddr_ba,
		output  [12:0]                ddr_addr,
		inout   [1:0]                 ddr_dqs_p,
		inout   [1:0]                 ddr_dqs_n,
		inout   [15:0]                ddr_dq,
		inout   [1:0]                 ddr_dm
		
    );
  wire  [24:0]                paxi_awaddr	;
  wire                        paxi_awvalid	;
  wire                        paxi_awready	;
  wire  [127:0]               paxi_wdata	;
  wire  [15:0]                paxi_wstrb	;
  wire                        paxi_wvalid	;
  wire                        paxi_wlast	;
  wire                        paxi_wready	;
  wire  [24:0]                paxi_araddr	;
  reg                         paxi_arvalid	;
  wire                        paxi_arready	;
  wire  [127:0]               paxi_rdata	;
  wire                        paxi_rlast	;
  wire                        paxi_rvalid	;
  wire                        paxi_rready	;
	
assign axi_rresp=0;
reg [C_AXI_ADDR_WIDTH:0] axi_araddr_r;
reg [7:0]                  axi_arlen_r;
reg [8:0]				   axi_araddr_count;
reg [8:0]				   axi_rdata_count;
reg axi_arready_r;
reg axi_rready_r;
assign axi_arready	=axi_arready_r;
//assign axi_rvalid		=paxi_rready&paxi_rvalid;
assign paxi_araddr		={axi_araddr_r[C_AXI_ADDR_WIDTH:4]+axi_araddr_count,3'b000};
assign paxi_rready		=axi_rready&axi_rready_r;
assign axi_rvalid		=paxi_rvalid&paxi_rready;
assign axi_rdata		=paxi_rdata;
assign axi_rlast 		=axi_rdata_count==axi_arlen_r;
always @(posedge axi_aclk)begin
	if(~axi_aresetn)begin
		axi_araddr_count<=0;
		axi_rdata_count<=0;
		axi_arready_r<=1;
		//paxi_rready<=0;
		axi_rready_r<=0;
		paxi_arvalid<=0;
	end else begin
		if(axi_arvalid&axi_arready)begin
			axi_araddr_r<=axi_araddr;
			axi_arlen_r<=axi_arlen;
			axi_arready_r<=0;
			axi_araddr_count<=0;
			axi_rdata_count<=0;
			paxi_arvalid<=1;
		end
		if(paxi_arvalid&paxi_arready)begin
			axi_araddr_count<=axi_araddr_count+1;
			axi_rready_r<=1;
			if(axi_araddr_count==axi_arlen_r)begin
				axi_arready_r<=1;
				paxi_arvalid<=0;
			end
		end
		if(axi_rvalid&axi_rready)begin
			axi_rdata_count<=axi_rdata_count+1;
			if(axi_rdata_count==axi_arlen_r)begin
				axi_rready_r<=0;
			end
		end
	end
end
	
reg [C_AXI_ADDR_WIDTH:0] axi_awaddr_r;
reg [7:0]                  axi_awlen_r;
reg [8:0]				   axi_awaddr_count;
reg [8:0]				   axi_wdata_count;
reg axi_awready_r;
reg axi_wready_r;
assign axi_awready	= axi_awready_r;
assign axi_wready		=paxi_wready&axi_wready_r;
assign paxi_awaddr		={axi_awaddr_r[C_AXI_ADDR_WIDTH:4]+axi_awaddr_count,3'b000};
assign paxi_awvalid		=axi_wvalid&(axi_awaddr_count<=axi_awlen_r);
assign paxi_wvalid		=axi_wvalid&(axi_wdata_count<=axi_awlen_r);
assign paxi_wlast		=paxi_wvalid;
assign paxi_wdata		=axi_wdata;
assign paxi_wstrb		=axi_wstrb;
//assign paxi_wlast		=axi_wdata_count==axi_awlen_r;
//assign axi_wready		= paxi_wready&paxi_wvalid;
assign axi_bresp		=0;
always @(posedge axi_aclk)begin
	if(~axi_aresetn)begin
		axi_awready_r<=1;
		axi_awaddr_count<=0;
		axi_wdata_count<=0;
		axi_wready_r<=0;
		axi_bvalid<=0;
	end else begin
		if(axi_awvalid&axi_awready)begin
			axi_awaddr_r<=axi_awaddr;
			axi_awlen_r<=axi_awlen;
			axi_awready_r<=0;
			axi_awaddr_count<=0;
			axi_wdata_count<=0;
			axi_wready_r<=1;
		end
		if(paxi_awvalid&paxi_awready)begin
			axi_awaddr_count<=axi_awaddr_count+1'b1;
		end
		if(axi_wvalid&axi_wready)begin
			axi_wdata_count<=axi_wdata_count+1'b1;
			
			if(axi_wdata_count==axi_awlen_r)begin
				axi_bvalid<=1;
				axi_awready_r<=1;
				axi_wready_r<=0;
			end
		end
		if(axi_bvalid&axi_bready)begin
			axi_bvalid<=0;
		end
	end
end
// ChipWatcher_0 ChipWatcher_0_u0
 // (
   // .probe0	(axi_araddr[25:0]	),
   // .probe1	(axi_arlen	),
   // .probe2	(axi_arvalid	),
   // .probe3	(axi_arready	),
   // .probe4	(axi_rdata	),
   // .probe5	(axi_rvalid	),
   // .probe6	(axi_rlast	),
   // .probe7	(axi_rready	),
   // .probe8	(paxi_araddr[24:0]	),
   // .probe9	(paxi_arvalid	),
   // .probe10	(paxi_arready	),
   // .probe11	(paxi_rlast	),
   // .probe12	(paxi_rvalid	),
   // .probe13	(paxi_rready	),
   // .clk   	(axi_aclk	)	  
 // );
 ChipWatcher_0 ChipWatcher_0_u1
 (
   .probe0	(axi_awaddr[25:0]	),
   .probe1	(axi_awlen	),
   .probe2	(axi_awvalid	),
   .probe3	(axi_awready	),
   .probe4	(axi_wdata	),
   .probe5	(axi_wvalid	),
   .probe6	(axi_wlast	),
   .probe7	(axi_wready	),
   .probe8	(paxi_awaddr[24:0]	),
   .probe9	(paxi_awvalid	),
   .probe10	(paxi_awready	),
   .probe11	(paxi_wlast	),
   .probe12	(paxi_wvalid	),
   .probe13	(paxi_wready	),
   .clk   	(axi_aclk	)	  
 );
  // ChipWatcher_0 ChipWatcher_0_u1
 // (
   // .probe0	(s_axi_ddr_awaddr[25:0]	),
   // .probe1	(s_axi_ddr_awlen	),
   // .probe2	(s_axi_ddr_awvalid	),
   // .probe3	(s_axi_ddr_awready	),
   // .probe4	(s_axi_ddr_wdata	),
   // .probe5	(s_axi_ddr_wvalid	),
   // .probe6	(s_axi_ddr_wlast	),
   // .probe7	(s_axi_ddr_wready	),
   // .clk   	(axi_aclk	)	  
 // );
MIS_DDR MIS_DDR_u
(
  .ref_clk		(ref_clk		),
  .sys_rst_n	(sys_rst_n		),
  .apb_pclk		(apb_pclk		),
  .apb_prst_n	(apb_prst_n		),
  .apb_pready	(apb_pready		),
  .apb_psel		(apb_psel		),
  .apb_penable	(apb_penable	),
  .apb_pwrite	(apb_pwrite		),
  .apb_paddr	(apb_paddr		),
  .apb_pwdata	(apb_pwdata		),
  .apb_prdata	(apb_prdata		),
  .dhi_clk		(dhi_clk		),
  .cfg_clk		(cfg_clk		),
  .cfg_rst_n	(cfg_rst_n		),
  .ddrphy_rst_n	(ddrphy_rst_n	),
  .ddrphy_rdy	(ddrphy_rdy		),
  
  .paxi_awaddr	(paxi_awaddr	),
  .paxi_awvalid	(paxi_awvalid	),
  .paxi_awready	(paxi_awready	),
  .paxi_wdata	(paxi_wdata		),
  .paxi_wstrb	(paxi_wstrb		),
  .paxi_wvalid	(paxi_wvalid	),
  .paxi_wlast	(paxi_wlast		),
  .paxi_wready	(paxi_wready	),
  .paxi_araddr	(paxi_araddr	),
  .paxi_arvalid	(paxi_arvalid	),
  .paxi_arready	(paxi_arready	),
  .paxi_rdata	(paxi_rdata		),
  .paxi_rlast	(paxi_rlast		),
  .paxi_rvalid	(paxi_rvalid	),
  .paxi_rready	(paxi_rready	),
  
  .usr_ref_type	(usr_ref_type),
  .usr_ref_req	(usr_ref_req ),
  .usr_ref_ack	(usr_ref_ack ),
  .ddr_ck_p     (ddr_ck_p ),
  .ddr_ck_n     (ddr_ck_n ),
  .ddr_cke      (ddr_cke  ),
  .ddr_odt      (ddr_odt  ),
  .ddr_cs_n     (ddr_cs_n ),
  .ddr_ras_n    (ddr_ras_n),
  .ddr_cas_n    (ddr_cas_n),
  .ddr_we_n     (ddr_we_n ),
  .ddr_ba       (ddr_ba   ),
  .ddr_addr     (ddr_addr ),
  .ddr_dqs_p    (ddr_dqs_p),
  .ddr_dqs_n    (ddr_dqs_n),
  .ddr_dq       (ddr_dq   ),
  .ddr_dm       (ddr_dm   )
);

endmodule
