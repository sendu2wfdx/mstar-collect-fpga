//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: mstar_udp_top
// Description: 多数据采集设备端 FPGA 顶层，集成 AD 驱动、数据采集、
//              DDR 缓存、以太网桥接 IP 及 AXI 总线互联
//============================================================================
module mstar_udp_top#
(
    parameter BK_NUM     = 2 ,
    parameter AC_NUM     = 4 ,
    parameter DX_NUM     = 2 ,

    parameter CS_WIDTH   = 1 ,
    parameter CKE_WIDTH  = 1 ,
    parameter ODT_WIDTH  = 1 ,
    parameter BA_WIDTH   = 2 ,
    parameter COL_WIDTH  = 10,
    parameter ROW_WIDTH  = 13,
    parameter CWL        = 6 ,
    parameter CL         = 7 ,
	parameter                       AXIFUL_ID_WIDTH       = 4,
	parameter                       AXIFUL_ADDR_WIDTH     = 32,
	parameter                       AXIFUL_DATA_WIDTH     = 128,
	parameter                       AXILITE_ADDR_WIDTH     = 32,
	parameter                       AXILITE_DATA_WIDTH     = 32,
    parameter                       C_S_AXI_ADDR_WIDTH = 8,
    //parameter                       C_S_AXI_DATA_WIDTH = AXILITE_DATA_WIDTH,
	parameter 						MODEL_ADDRESS_SPACE=8,
    parameter                       BUFLENWIDTH = 26,
	parameter  						POART_WIDTH=6,
    parameter                       AD_DATWIDTH=16,
    parameter                       COLLECT_CHANNEL_NUM = 8
)(
  
  input           sys_rst_n     ,  
  input           clk_50m       ,  
	output     [3:0] rgmii_txd,
    output           rgmii_tx_ctl,
    output           rgmii_txc,
    input      [3:0] rgmii_rxd,
    input            rgmii_rx_ctl,
    input            rgmii_rxc,
	output			 phy_reset_n,
	
    output con_scl,
	inout con_sda,
    output user_scl,
	inout user_sda,
    input i_default,
    //output [3:0] led,
    //input  [1:0] key,
    output speed_status_1g,
    output speed_status_100M,
    output link_error,
	inout		mdio,
	output		mdc,
  // DDR Interface
    output    [ ROW_WIDTH-1:0]      ddr_addr      , 
    output    [  BA_WIDTH-1:0]      ddr_ba        ,
    output    [ CKE_WIDTH-1:0]      ddr_cke       ,
    output    [ ODT_WIDTH-1:0]      ddr_odt       ,
    output    [  CS_WIDTH-1:0]      ddr_cs_n      ,
    output                          ddr_ras_n     ,
    output                          ddr_cas_n     ,
    output                          ddr_we_n      ,
    output                          ddr_ck_p      ,
    output                          ddr_ck_n      ,
    inout     [    DX_NUM-1:0]      ddr_dm        ,
    inout     [  DX_NUM*8-1:0]      ddr_dq        ,
    inout     [    DX_NUM-1:0]      ddr_dqs_n     ,
    inout     [    DX_NUM-1:0]      ddr_dqs_p     ,
    
    input           ad_convst_in,
    output          ad_convst_out,
    input           trig_in,
    output          trig_out,
    output          led,
    output [POART_WIDTH-1:0]     out_port,
	input  [POART_WIDTH-1:0]     in_port,
    output 			ad_reset	,
	output 		    ad_convst	,
	input  			ad_busy		,
	output 			ad_csn		,
	output       	ad_rdn		,
	output 			ad_wrn		,
	input           ad_frstdat	,
    inout    [15:0]       ad_data
	

);
  wire  ad_clk;
  wire  w_clk_125M;
  wire  w_axifull_clk;
  wire  w_axifull_rstn;
  wire  w_axilite_clk;
  wire ddr_cfg_clk;
	wire ddr_cfg_rstn;
  wire  w_axilite_rst;
  wire  [31:0]                us0_araddr;
  //wire  [1:0]                 us0_arburst;
  //wire  [3:0]                 us0_arcache;
  //wire  [2:0]                 us0_arid;
  wire  [7:0]                 us0_arlen;
  //wire  [0:0]                 us0_arlock;
  //wire  [2:0]                 us0_arprot;
  //wire  [3:0]                 us0_arqos;
  wire                        us0_arready;
  //wire  [2:0]                 us0_arsize;
  wire                        us0_arvalid;
  wire  [31:0]                us0_awaddr;
  //wire  [1:0]                 us0_awburst;
  //wire  [3:0]                 us0_awcache;
  //wire  [2:0]                 us0_awid;
  wire  [7:0]                 us0_awlen;
  //wire  [0:0]                 us0_awlock;
  //wire  [2:0]                 us0_awprot;
  //wire  [3:0]                 us0_awqos;
  wire                        us0_awready;
  wire  [2:0]                 us0_awsize;
  wire                        us0_awvalid;
  //wire  [2:0]                 us0_bid;
  wire                        us0_bready;
  wire  [1:0]                 us0_bresp;
  wire                        us0_bvalid;
  wire  [127:0]               us0_rdata;
  //wire  [2:0]                 us0_rid;
  wire                        us0_rlast;
  wire                        us0_rready;
  wire  [1:0]                 us0_rresp;
  wire                        us0_rvalid;
  wire  [127:0]               us0_wdata;
  wire                        us0_wlast;
  wire                        us0_wready;
  wire  [15:0]                us0_wstrb;
  wire                        us0_wvalid;
  
  wire [AXILITE_ADDR_WIDTH-1:0]   	m0_axilite_awaddr	;
  wire                             	m0_axilite_awvalid	;
  wire                            	m0_axilite_awready	;
  wire [AXILITE_DATA_WIDTH-1:0]    	m0_axilite_wdata	;
  wire [AXILITE_DATA_WIDTH/8-1:0]  	m0_axilite_wstrb	;
  wire                            	m0_axilite_wvalid	;
  wire                              m0_axilite_wready	;
  wire [1:0]                        m0_axilite_bresp	;
  wire                              m0_axilite_bvalid	;
  wire                              m0_axilite_bready	;
  wire [AXILITE_ADDR_WIDTH-1:0]  	m0_axilite_araddr	;
  wire                             	m0_axilite_arvalid	;
  wire                              m0_axilite_arready	;
  wire [AXILITE_DATA_WIDTH-1:0]     m0_axilite_rdata	;
  wire [1:0]                        m0_axilite_rresp	;
  wire                              m0_axilite_rvalid	;
  wire                             	m0_axilite_rready	;
  

  
  wire [11:0]   	                s_axilite_awaddr	[2:0];
  wire                             	s_axilite_awvalid	[2:0];
  wire                            	s_axilite_awready	[2:0];
  wire [AXILITE_DATA_WIDTH-1:0]    	s_axilite_wdata		[2:0];
  wire [AXILITE_DATA_WIDTH/8-1:0]  	s_axilite_wstrb		[2:0];
  wire                            	s_axilite_wvalid	[2:0];
  wire                              s_axilite_wready	[2:0];
  wire [1:0]                        s_axilite_bresp		[2:0];
  wire                              s_axilite_bvalid	[2:0];
  wire                              s_axilite_bready	[2:0];
  wire [11:0]  	                    s_axilite_araddr	[2:0];
  wire                             	s_axilite_arvalid	[2:0];
  wire                              s_axilite_arready	[2:0];
  wire [AXILITE_DATA_WIDTH-1:0]     s_axilite_rdata		[2:0];
  wire [1:0]                        s_axilite_rresp		[2:0];
  wire                              s_axilite_rvalid	[2:0];
  wire                             	s_axilite_rready	[2:0];
  
  
  	// ddr axifull
  // Slave Interface Write Address Ports for ddr
  wire [AXIFUL_ID_WIDTH-1:0]        s_axi_ddr_awid;
  wire [BUFLENWIDTH:0]            s_axi_ddr_awaddr;
  wire [7:0]                        s_axi_ddr_awlen;
  wire [2:0]                        s_axi_ddr_awsize;
  wire [1:0]                        s_axi_ddr_awburst;
  wire [0:0]                        s_axi_ddr_awlock;
  wire [3:0]                        s_axi_ddr_awcache;
  wire [2:0]                        s_axi_ddr_awprot;
  wire [3:0]                        s_axi_ddr_awregion;
  wire           [3:0]           	  s_axi_ddr_awqos;
  wire                              s_axi_ddr_awvalid;
  wire                              s_axi_ddr_awready;
   // Slave Interface Write Data Ports
  wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_ddr_wdata;
  wire [(AXIFUL_DATA_WIDTH/8)-1:0]  s_axi_ddr_wstrb;
  wire                              s_axi_ddr_wlast;
  wire                              s_axi_ddr_wvalid;
  wire                              s_axi_ddr_wready;
   // Slave Interface Write Response Ports
  wire                              s_axi_ddr_bready;
  wire [AXIFUL_ID_WIDTH-1:0]        s_axi_ddr_bid;
  wire [1:0]                        s_axi_ddr_bresp;
  wire                              s_axi_ddr_bvalid;
   // Slave Interface Read Address Ports  
  wire [AXIFUL_ID_WIDTH-1:0]        s_axi_ddr_arid;
  wire [BUFLENWIDTH:0]            s_axi_ddr_araddr;
  wire [7:0]                        s_axi_ddr_arlen;
  wire [2:0]                        s_axi_ddr_arsize;
  wire [1:0]                        s_axi_ddr_arburst;
  wire [0:0]                        s_axi_ddr_arlock;
  wire [3:0]                        s_axi_ddr_arcache;
  wire [2:0]                        s_axi_ddr_arprot;
  wire [3:0]           				s_axi_ddr_arqos;
  wire [3:0]                        s_axi_ddr_arregion;
  wire                              s_axi_ddr_arvalid;
  wire                              s_axi_ddr_arready;
   // Slave Interface Read Data Ports
  wire                              s_axi_ddr_rready;
  wire [AXIFUL_ID_WIDTH-1:0]        s_axi_ddr_rid;
  wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_ddr_rdata;
  wire [1:0]                        s_axi_ddr_rresp;
  wire                              s_axi_ddr_rlast;
  wire                              s_axi_ddr_rvalid;
 
 
  // Slave Interface Write Address Ports for ddr
  wire [AXIFUL_ID_WIDTH-1:0]        m_axi_ddr_awid;
  wire [BUFLENWIDTH:0]      m_axi_ddr_awaddr;
  wire [7:0]                        m_axi_ddr_awlen;
  wire [2:0]                        m_axi_ddr_awsize;
  wire [1:0]                        m_axi_ddr_awburst;
  wire [0:0]                        m_axi_ddr_awlock;
  wire [3:0]                        m_axi_ddr_awcache;
  wire [2:0]                        m_axi_ddr_awprot;
  wire           [3:0]           	m_axi_ddr_awqos;
  wire                              m_axi_ddr_awvalid;
  wire                              m_axi_ddr_awready;
   // Slave Interface Write Data Ports
  wire [AXIFUL_DATA_WIDTH-1:0]      m_axi_ddr_wdata;
  wire [(AXIFUL_DATA_WIDTH/8)-1:0]  m_axi_ddr_wstrb;
  wire                              m_axi_ddr_wlast;
  wire                              m_axi_ddr_wvalid;
  wire                              m_axi_ddr_wready;
   // Slave Interface Write Response Ports
  wire                              m_axi_ddr_bready;
  wire [AXIFUL_ID_WIDTH-1:0]        m_axi_ddr_bid;
  wire [1:0]                        m_axi_ddr_bresp;
  wire                              m_axi_ddr_bvalid;
   // Slave Interface Read Address Ports  
  wire [AXIFUL_ID_WIDTH-1:0]        m_axi_ddr_arid;
  wire [BUFLENWIDTH:0]            m_axi_ddr_araddr;
  wire [7:0]                        m_axi_ddr_arlen;
  wire [2:0]                        m_axi_ddr_arsize;
  wire [1:0]                        m_axi_ddr_arburst;
  wire [0:0]                        m_axi_ddr_arlock;
  wire [3:0]                        m_axi_ddr_arcache;
  wire [2:0]                        m_axi_ddr_arprot;
  wire [3:0]           				m_axi_ddr_arqos;
  wire                              m_axi_ddr_arvalid;
  wire                              m_axi_ddr_arready;
   // Slave Interface Read Data Ports
  wire                              m_axi_ddr_rready;
  wire [AXIFUL_ID_WIDTH-1:0]        m_axi_ddr_rid;
  wire [AXIFUL_DATA_WIDTH-1:0]      m_axi_ddr_rdata;
  wire [1:0]                        m_axi_ddr_rresp;
  wire                              m_axi_ddr_rlast;
  wire                              m_axi_ddr_rvalid;
 
  // udp axifull
  // Slave Interface Write Address Ports for udp
  //wire [AXIFUL_ID_WIDTH-1:0]        s_axi_udp_awid;
  wire [AXIFUL_ADDR_WIDTH-1:0]      s_axi_udp_awaddr;
  wire [7:0]                        s_axi_udp_awlen;
  wire                              s_axi_udp_awvalid;
  wire                              s_axi_udp_awready;
   // Slave Interface Write Data Ports    
  wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_udp_wdata;
  wire [(AXIFUL_DATA_WIDTH/8)-1:0]  s_axi_udp_wstrb;
  wire                              s_axi_udp_wlast;
  wire                              s_axi_udp_wvalid;
  wire                              s_axi_udp_wready;
   // Slave Interface Write Response Ports
  wire                              s_axi_udp_bready;
  //wire [AXIFUL_ID_WIDTH-1:0]        s_axi_udp_bid;
  wire [1:0]                        s_axi_udp_bresp;
  wire                              s_axi_udp_bvalid;
   // Slave Interface Read Address Ports  
  wire [AXIFUL_ADDR_WIDTH-1:0]      s_axi_udp_araddr;
  wire [7:0]                        s_axi_udp_arlen;
  wire [0:0]                        s_axi_udp_arlock;
  wire                              s_axi_udp_arvalid;
  wire                              s_axi_udp_arready;
   // Slave Interface Read Data Ports     
  wire                              s_axi_udp_rready;
 // wire [AXIFUL_ID_WIDTH-1:0]        s_axi_udp_rid;
  wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_udp_rdata;
  wire [1:0]                        s_axi_udp_rresp;
  wire                              s_axi_udp_rlast;
  wire                              s_axi_udp_rvalid;
  
  // dma axifull
  // Slave Interface Write Address Ports for udp
  //wire [AXIFUL_ID_WIDTH-1:0]        s_axi_dma_awid;
  wire [BUFLENWIDTH:0]              s_axi_dma_awaddr;
  wire [7:0]                        s_axi_dma_awlen;
  wire                              s_axi_dma_awvalid;
  wire                              s_axi_dma_awready;
   // Slave Interface Write Data Ports    
  wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_dma_wdata;
  wire [(AXIFUL_DATA_WIDTH/8)-1:0]  s_axi_dma_wstrb;
  wire                              s_axi_dma_wlast;
  wire                              s_axi_dma_wvalid;
  wire                              s_axi_dma_wready;
   // Slave Interface Write Response Ports
  wire                              s_axi_dma_bready;
  //wire [AXIFUL_ID_WIDTH-1:0]        s_axi_udp_bid;
  wire [1:0]                        s_axi_dma_bresp;
  wire                              s_axi_dma_bvalid;
   // Slave Interface Read Address Ports  
  //wire [AXIFUL_ADDR_WIDTH-1:0]      s_axi_dma_araddr;
  //wire [7:0]                        s_axi_dma_arlen;
  //wire [0:0]                        s_axi_dma_arlock;
  //wire                              s_axi_dma_arvalid;
  //wire                              s_axi_dma_arready;
   // Slave Interface Read Data Ports     
  //wire                              s_axi_dma_rready;
  //wire [AXIFUL_ID_WIDTH-1:0]        s_axi_dma_rid;
  //wire [AXIFUL_DATA_WIDTH-1:0]      s_axi_dma_rdata;
  //wire [1:0]                        s_axi_dma_rresp;
  //wire                              s_axi_dma_rlast;
  //wire                              s_axi_dma_rvalid;
  
	wire   [7:0]               rx_axis_mac_tdata	;
	wire                       rx_axis_mac_tvalid	;
	wire                       rx_axis_mac_tlast	;
	wire                       rx_axis_mac_tuser	;
	wire                       rx_axis_mac_tready	; 
	wire    [7:0]              tx_axis_mac_tdata  	;
	wire                       tx_axis_mac_tvalid 	;
	wire                       tx_axis_mac_tlast  	;
	wire                       tx_axis_mac_tready 	;
	
	wire   clk_125M_rst;
    wire   w_clk_100m;
    wire   w_clk_50m;
    wire   clk_50m_rst;
	wire	ddr_dhi_clk;
	wire     ddr_dhi_rstn;
    wire syspll_lock;
    
    //wire [1:0]                          speed_status;
    wire                                _link_error;
    //wire                                _phy_ack_error;
    wire cryptopp_wdten;
    wire collect_doing;
    reg [27:0] ledfly_halfsecondfly_cnt;
   assign link_error=~_link_error;
   //assign speed_status_1g   = speed_status==2'b11;
   //assign speed_status_100M = speed_status==2'b10;
   assign phy_reset_n = ~clk_50m_rst;
   always @(posedge w_clk_50m)begin
        if(cryptopp_wdten)begin
            if(ledfly_halfsecondfly_cnt<'d50000000)
                ledfly_halfsecondfly_cnt<=ledfly_halfsecondfly_cnt+1'b1;
            else 
                ledfly_halfsecondfly_cnt<=0;
        end else begin
            ledfly_halfsecondfly_cnt<=0;
        end
   end
   assign led= cryptopp_wdten ? (ledfly_halfsecondfly_cnt<'d25000000): ~collect_doing;
sysPLL sysPLL_u0
(
  .refclk		(clk_50m),		//50M
  .clk0_out		(w_clk_125M),		//125M
  .clk1_out		(w_clk_100m),	//100M
  .clk2_out		(w_clk_50m),	//100M
  .lock			(syspll_lock),
  .reset		(~sys_rst_n)
);
assign w_axilite_clk=w_clk_50m;//ddr_cfg_clk;
assign w_axilite_rst=clk_50m_rst;
//assign led=ddr_cfg_rstn;
 reset_sync tx_reset_gen 
   (
  .clk              (w_clk_125M),
  .reset_in         (~syspll_lock),
  .reset_out        (clk_125M_rst)
);
reset_sync reset_sync_clk50m_u0 
   (
  .clk              (w_clk_50m),
  .reset_in         (~syspll_lock),
  .reset_out        (clk_50m_rst)
);
  resetn_sync resetn_sync_axiddr_u0
(
   .resetn_in	(sys_rst_n	),
   .clk			(ddr_dhi_clk	),
   .resetn_out	(ddr_dhi_rstn	)
);
  resetn_sync resetn_sync_axifull_u0
(
   .resetn_in	(syspll_lock	),
   .clk			(w_axifull_clk	),
   .resetn_out	(w_axifull_rstn	)
);
//   resetn_sync resetn_sync_axilitle_u0
// (
//    .resetn_in	(syspll_lock	),
//    .clk			(w_axilite_clk	),
//    .resetn_out	(w_axilite_rstn	)
// );

 assign w_axifull_clk=w_clk_100m;
MIS_DDR MIS_DDR_u
(
  .ref_clk      (clk_50m),
  .sys_rst_n    (sys_rst_n),
  .apb_pclk		(ddr_cfg_clk		),
  .apb_prst_n	(0		),
  .apb_pready	(		),
  .apb_psel		(0		),
  .apb_penable	(0		),
  .apb_pwrite	(0		),
  .apb_paddr	(0		),
  .apb_pwdata	(0		),
  .apb_prdata	(		),
  .dhi_clk		(ddr_dhi_clk		),		//133M
  .cfg_clk		(ddr_cfg_clk		),		//50M
  .cfg_rst_n	(ddr_cfg_rstn		),
  .ddrphy_rst_n	(		),
  .ddrphy_rdy	(		),
  .axi_aclk			(ddr_dhi_clk		),
  .axi_aresetn		(ddr_dhi_rstn		),
  .axi_awid			(m_axi_ddr_awid		),
  .axi_awaddr		(m_axi_ddr_awaddr[25:0]		),
  .axi_awlen		(m_axi_ddr_awlen		),
  .axi_awsize		(m_axi_ddr_awsize		),
  .axi_awburst		(m_axi_ddr_awburst		),
  .axi_awvalid		(m_axi_ddr_awvalid		),
  .axi_awready		(m_axi_ddr_awready		),
  .axi_wdata		(m_axi_ddr_wdata		),
  .axi_wstrb		(m_axi_ddr_wstrb		),
  .axi_wlast		(m_axi_ddr_wlast		),
  .axi_wvalid		(m_axi_ddr_wvalid		),
  .axi_wready		(m_axi_ddr_wready		),
  .axi_bid			(m_axi_ddr_bid		),
  .axi_bresp		(m_axi_ddr_bresp		),
  .axi_bvalid		(m_axi_ddr_bvalid		),
  .axi_bready		(m_axi_ddr_bready		),
  .axi_arid			(m_axi_ddr_arid		),
  .axi_araddr		(m_axi_ddr_araddr[25:0]		),
  .axi_arlen		(m_axi_ddr_arlen		),
  .axi_arsize		(m_axi_ddr_arsize		),
  .axi_arburst		(m_axi_ddr_arburst		),
  .axi_arvalid		(m_axi_ddr_arvalid		),
  .axi_arready		(m_axi_ddr_arready		),
  .axi_rid			(m_axi_ddr_rid	),
  .axi_rdata		(m_axi_ddr_rdata		),
  .axi_rresp		(m_axi_ddr_rresp		),
  .axi_rlast		(m_axi_ddr_rlast		),
  .axi_rvalid		(m_axi_ddr_rvalid		),
  .axi_rready		(m_axi_ddr_rready		),
  
  .usr_ref_type		('b0		),
  .usr_ref_req		('b0		),
  .usr_ref_ack		(		),
  
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
AXI_Clock_Converter_ddr AXI_Clock_Converter_ddr_u0
(
  .us_aclk			(w_axifull_clk	),
  .us_aresetn		(w_axifull_rstn	),
  .us_awid			(s_axi_ddr_awid			),
  .us_awaddr		(s_axi_ddr_awaddr		),
  .us_awlen			(s_axi_ddr_awlen		),
  .us_awsize		(s_axi_ddr_awsize		),
  .us_awburst		(s_axi_ddr_awburst		),
  .us_awlock		(s_axi_ddr_awlock		),
  .us_awcache		(s_axi_ddr_awcache		),
  .us_awprot		(s_axi_ddr_awprot		),
  .us_awregion		(s_axi_ddr_awregion	    ),
  .us_awqos			(s_axi_ddr_awqos		),
  .us_awvalid		(s_axi_ddr_awvalid		),
  .us_awready		(s_axi_ddr_awready		),
  .us_wdata			(s_axi_ddr_wdata		),
  .us_wstrb			(s_axi_ddr_wstrb		),
  .us_wlast			(s_axi_ddr_wlast		),
  .us_wvalid		(s_axi_ddr_wvalid		),
  .us_wready		(s_axi_ddr_wready		),
  .us_bid			(s_axi_ddr_bid			),
  .us_bresp			(s_axi_ddr_bresp		),
  .us_bvalid		(s_axi_ddr_bvalid		),
  .us_bready		(s_axi_ddr_bready		),
  .us_arid			(s_axi_ddr_arid			),
  .us_araddr		(s_axi_ddr_araddr		),
  .us_arlen			(s_axi_ddr_arlen		),
  .us_arsize		(s_axi_ddr_arsize		),
  .us_arburst		(s_axi_ddr_arburst		),
  .us_arlock		(s_axi_ddr_arlock		),
  .us_arcache		(s_axi_ddr_arcache		),
  .us_arprot		(s_axi_ddr_arprot		),
  .us_arregion		(s_axi_ddr_arregion	    ),
  .us_arqos			(s_axi_ddr_arqos		),
  .us_arvalid		(s_axi_ddr_arvalid		),
  .us_arready		(s_axi_ddr_arready		),
  .us_rid			(s_axi_ddr_rid			),
  .us_rdata			(s_axi_ddr_rdata		),
  .us_rresp			(s_axi_ddr_rresp		),
  .us_rlast			(s_axi_ddr_rlast		),
  .us_rvalid		(s_axi_ddr_rvalid		),
  .us_rready		(s_axi_ddr_rready		),
  
  .ds_aclk			(ddr_dhi_clk	),
  .ds_aresetn		(ddr_dhi_rstn	),
  .ds_awid			(m_axi_ddr_awid		),
  .ds_awaddr		(m_axi_ddr_awaddr	),
  .ds_awlen			(m_axi_ddr_awlen	),
  .ds_awsize		(m_axi_ddr_awsize	),
  .ds_awburst		(m_axi_ddr_awburst	),
  .ds_awlock		(m_axi_ddr_awlock	),
  .ds_awcache		(m_axi_ddr_awcache	),
  .ds_awprot		(m_axi_ddr_awprot	),
  .ds_awregion		(					),
  .ds_awqos			(m_axi_ddr_awqos	),
  .ds_awvalid		(m_axi_ddr_awvalid	),
  .ds_awready		(m_axi_ddr_awready	),
  .ds_wdata			(m_axi_ddr_wdata	),
  .ds_wstrb			(m_axi_ddr_wstrb	),
  .ds_wlast			(m_axi_ddr_wlast	),
  .ds_wvalid		(m_axi_ddr_wvalid	),
  .ds_wready		(m_axi_ddr_wready	),
  .ds_bid			(m_axi_ddr_bid		),
  .ds_bresp			(m_axi_ddr_bresp	),
  .ds_bvalid		(m_axi_ddr_bvalid	),
  .ds_bready		(m_axi_ddr_bready	),
  .ds_arid			(m_axi_ddr_arid		),
  .ds_araddr		(m_axi_ddr_araddr	),
  .ds_arlen			(m_axi_ddr_arlen	),
  .ds_arsize		(m_axi_ddr_arsize	),
  .ds_arburst		(m_axi_ddr_arburst	),
  .ds_arlock		(m_axi_ddr_arlock	),
  .ds_arcache		(m_axi_ddr_arcache	),
  .ds_arprot		(m_axi_ddr_arprot	),
  .ds_arregion		(					),
  .ds_arqos			(m_axi_ddr_arqos	),
  .ds_arvalid		(m_axi_ddr_arvalid	),
  .ds_arready		(m_axi_ddr_arready	),
  .ds_rid			(m_axi_ddr_rid		),
  .ds_rdata			(m_axi_ddr_rdata	),
  .ds_rresp			(m_axi_ddr_rresp	),
  .ds_rlast			(m_axi_ddr_rlast	),
  .ds_rvalid		(m_axi_ddr_rvalid	),
  .ds_rready		(m_axi_ddr_rready	)
);
	wire con_sda_in;
	wire con_sda_out;
	wire con_sda_oe;
    wire user_sda_in;
	wire user_sda_out;
	wire user_sda_oe;
	PH1P_LOGIC_IOTRIBUF u1_PH1P_LOGIC_IOTRIBUF_u0 (
		.i(con_sda_out),
		.t(con_sda_oe),
		.o(con_sda_in),
		.io(con_sda)
	);
    PH1P_LOGIC_IOTRIBUF u1_PH1P_LOGIC_IOTRIBUF_u1 (
		.i(user_sda_out),
		.t(user_sda_oe),
		.o(user_sda_in),
		.io(user_sda)
	);
wire mdio_out;
wire mdio_in;
wire mdio_oe;
mstar_ethernet_bridge mstar_ethernet_bridge_u0(
    .sys_clk_125M	(w_clk_125M	),										//
    .sys_clk_rstn	(~clk_125M_rst	),
    .m_axilite_clk		(w_axilite_clk		),
    .m_axilite_rst		(w_axilite_rst		),
    .m_axilite_awvalid	(m0_axilite_awvalid		),
    .m_axilite_awready	(m0_axilite_awready		),
    .m_axilite_awaddr 	(m0_axilite_awaddr 		),
    .m_axilite_wvalid 	(m0_axilite_wvalid 		),
    .m_axilite_wready 	(m0_axilite_wready 		),
    .m_axilite_wdata  	(m0_axilite_wdata  		),
    .m_axilite_wstrb  	(m0_axilite_wstrb  		),
    .m_axilite_arvalid	(m0_axilite_arvalid		),
    .m_axilite_arready	(m0_axilite_arready		),
    .m_axilite_araddr 	(m0_axilite_araddr 		),
    .m_axilite_rvalid 	(m0_axilite_rvalid 		),
    .m_axilite_rready 	(m0_axilite_rready 		),
    .m_axilite_rdata  	(m0_axilite_rdata  		),
    .m_axilite_rresp  	(m0_axilite_rresp  		),
    .m_axilite_bvalid 	(m0_axilite_bvalid 		),
    .m_axilite_bready 	(m0_axilite_bready 		),
    .m_axilite_bresp  	(m0_axilite_bresp  		),
    
     .m_axi_clk			(w_axifull_clk		),
     .m_axi_rst			(~w_axifull_rstn	),
     
     .m_axi_awvalid		(s_axi_udp_awvalid	),
     .m_axi_awready		(s_axi_udp_awready	),
     .m_axi_awaddr 		(s_axi_udp_awaddr	),
     .m_axi_awlen  		(s_axi_udp_awlen	),
     .m_axi_wvalid 		(s_axi_udp_wvalid	),
     .m_axi_wready 		(s_axi_udp_wready	),
     .m_axi_wdata  		(s_axi_udp_wdata	),
     .m_axi_wstrb  		(s_axi_udp_wstrb	),
     .m_axi_wlast  		(s_axi_udp_wlast	), 
     .m_axi_bvalid 		(s_axi_udp_bvalid	),
     .m_axi_bready 		(s_axi_udp_bready	),
     .m_axi_arvalid		(s_axi_udp_arvalid	),
     .m_axi_arready		(s_axi_udp_arready	),
     .m_axi_araddr 		(s_axi_udp_araddr	),
     .m_axi_arlen  		(s_axi_udp_arlen	),
     .m_axi_rvalid 		(s_axi_udp_rvalid	),
     .m_axi_rready 		(s_axi_udp_rready	),
     .m_axi_rdata  		(s_axi_udp_rdata	),
     .m_axi_rlast  		(s_axi_udp_rlast	),
 
//    .gmii_rx_tdata	(rx_axis_mac_tdata	),
//    .gmii_rx_tvalid	(rx_axis_mac_tvalid	),
//    .gmii_rx_last	(rx_axis_mac_tlast	),
//    .gmii_rx_ready	(rx_axis_mac_tready	),
//    .gmii_tx_tready (tx_axis_mac_tready   ),
//    .gmii_tx_tdata  (tx_axis_mac_tdata	),
//    .gmii_tx_tvalid (tx_axis_mac_tvalid	),
//    .gmii_tx_tlast  (tx_axis_mac_tlast	),
//    .phy_reset_n    (phy_reset_n    ),
    .rgmii_txd		(rgmii_txd			),
	.rgmii_tx_ctl	(rgmii_tx_ctl		),
	.rgmii_txc		(rgmii_txc			),
	.rgmii_rxd		(rgmii_rxd			),
	.rgmii_rx_ctl	(rgmii_rx_ctl		),
	.rgmii_rxc		(rgmii_rxc			),
    
    .speed_status_1g    (speed_status_1g),
    .speed_status_100M  (speed_status_100M),
    .link_error         (_link_error),
    
    .i_default  (i_default),
    .cryptopp_wdten(cryptopp_wdten),
    .mdc                (mdc),
	.mdio_in            (mdio_in),
	.mdio_out           (mdio_out),
	.mdio_oe            (mdio_oe),
//    .speed_status   ({2'b00,speed_status}   ),
//    .link_error     (link_error   ),
    //.phy_ack_error  (phy_ack_error   ),
    .con_scl        (con_scl        ),  //I2C��SCLʱ���ź�
    .con_sda_in     (con_sda_in        ),  //I2C��SDA�ź�
	.con_sda_out	(con_sda_out	),
	.con_sda_oe		(con_sda_oe		),
    .user_scl        (user_scl        ),  //I2C��SCLʱ���ź�
    .user_sda_in     (user_sda_in        ),  //I2C��SDA�ź�
	.user_sda_out	(user_sda_out	),
	.user_sda_oe	(user_sda_oe		)
    
    );
AXI_lite_Matrix AXI_lite_Matrix_u0
(
  .aclk			(w_axilite_clk	),
  .aresetn		(~w_axilite_rst	),
  .us0_araddr	(m0_axilite_araddr[11:0]),
  .us0_arprot	('d0				),
  .us0_arready	(m0_axilite_arready	),
  .us0_arvalid	(m0_axilite_arvalid	),
  .us0_awaddr	(m0_axilite_awaddr[11:0]	),
  .us0_awprot	('d0				),
  .us0_awready	(m0_axilite_awready	),
  .us0_awvalid	(m0_axilite_awvalid	),
  .us0_bready	(m0_axilite_bready	),
  .us0_bresp	(m0_axilite_bresp	),
  .us0_bvalid	(m0_axilite_bvalid	),
  .us0_rdata	(m0_axilite_rdata	),
  .us0_rready	(m0_axilite_rready	),
  .us0_rresp	(m0_axilite_rresp	),
  .us0_rvalid	(m0_axilite_rvalid	),
  .us0_wdata	(m0_axilite_wdata	),
  .us0_wready	(m0_axilite_wready	),
  .us0_wstrb	(m0_axilite_wstrb	),
  .us0_wvalid	(m0_axilite_wvalid	),
  
  .ds0_araddr	(s_axilite_araddr   [0]	),
  .ds0_arprot	(                       ),
  .ds0_arready	(s_axilite_arready  [0]	),
  .ds0_arvalid	(s_axilite_arvalid  [0]	),
  .ds0_awaddr	(s_axilite_awaddr   [0]	),
  .ds0_awprot	(                       ),
  .ds0_awready	(s_axilite_awready  [0]	),
  .ds0_awvalid	(s_axilite_awvalid  [0]	),
  .ds0_bready	(s_axilite_bready   [0]	),
  .ds0_bresp	(s_axilite_bresp    [0]	),
  .ds0_bvalid	(s_axilite_bvalid   [0]	),
  .ds0_rdata	(s_axilite_rdata    [0]	),
  .ds0_rready	(s_axilite_rready   [0]	),
  .ds0_rresp	(s_axilite_rresp    [0]	),
  .ds0_rvalid	(s_axilite_rvalid   [0]	),
  .ds0_wdata	(s_axilite_wdata    [0]	),
  .ds0_wready	(s_axilite_wready   [0]	),
  .ds0_wstrb	(s_axilite_wstrb    [0]	),
  .ds0_wvalid	(s_axilite_wvalid   [0]	),
  
  .ds1_araddr	(s_axilite_araddr   [1]	),
  .ds1_arprot	(                          ),
  .ds1_arready	(s_axilite_arready  [1]	),
  .ds1_arvalid	(s_axilite_arvalid  [1]	),
  .ds1_awaddr	(s_axilite_awaddr   [1]	),
  .ds1_awprot	(                          ),
  .ds1_awready	(s_axilite_awready  [1]	),
  .ds1_awvalid	(s_axilite_awvalid  [1]	),
  .ds1_bready	(s_axilite_bready   [1]	),
  .ds1_bresp	(s_axilite_bresp    [1]	),
  .ds1_bvalid	(s_axilite_bvalid   [1]	),
  .ds1_rdata	(s_axilite_rdata    [1]	),
  .ds1_rready	(s_axilite_rready   [1]	),
  .ds1_rresp	(s_axilite_rresp    [1]	),
  .ds1_rvalid	(s_axilite_rvalid   [1]	),
  .ds1_wdata	(s_axilite_wdata    [1]	),
  .ds1_wready	(s_axilite_wready   [1]	),
  .ds1_wstrb	(s_axilite_wstrb    [1]	),
  .ds1_wvalid	(s_axilite_wvalid   [1]	),
  
  .ds2_araddr	(s_axilite_araddr   [2]	),
  .ds2_arprot	(                         ),
  .ds2_arready	(s_axilite_arready  [2]	),
  .ds2_arvalid	(s_axilite_arvalid  [2]	),
  .ds2_awaddr	(s_axilite_awaddr   [2]	),
  .ds2_awprot	(                         ),
  .ds2_awready	(s_axilite_awready  [2]	),
  .ds2_awvalid	(s_axilite_awvalid  [2]	),
  .ds2_bready	(s_axilite_bready   [2]	),
  .ds2_bresp	(s_axilite_bresp    [2]	),
  .ds2_bvalid	(s_axilite_bvalid   [2]	),
  .ds2_rdata	(s_axilite_rdata    [2]	),
  .ds2_rready	(s_axilite_rready   [2]	),
  .ds2_rresp	(s_axilite_rresp    [2]	),
  .ds2_rvalid	(s_axilite_rvalid   [2]	),
  .ds2_wdata	(s_axilite_wdata    [2]	),
  .ds2_wready	(s_axilite_wready   [2]	),
  .ds2_wstrb	(s_axilite_wstrb    [2]	),
  .ds2_wvalid	(s_axilite_wvalid   [2]	)
  


);
AXIfull_Matrix AXIfull_Matrix_u0(
  .aclk				(w_axifull_clk		),
  .aresetn			(w_axifull_rstn		),
  .us0_araddr		(s_axi_udp_araddr[BUFLENWIDTH:0]		),
  .us0_arburst		(2'b01		),		//
  .us0_arcache		('d0		),
  .us0_arid			('d0		),
  .us0_arlen		(s_axi_udp_arlen		),
  .us0_arlock		('d0		),
  .us0_arprot		('d0		),
  .us0_arqos		('d0		),
  .us0_arready		(s_axi_udp_arready		),
  .us0_arsize		('b100		),
  .us0_arvalid		(s_axi_udp_arvalid		),
  .us0_awaddr		(s_axi_udp_awaddr[BUFLENWIDTH:0]),
  .us0_awburst		(2'b01		),
  .us0_awcache		('d0		),
  .us0_awid			('d0		),
  .us0_awlen		(s_axi_udp_awlen		),
  .us0_awlock		('d0		),
  .us0_awprot		('d0		),
  .us0_awqos		('d0		),
  .us0_awready		(s_axi_udp_awready		),
  .us0_awsize		('b100		),
  .us0_awvalid		(s_axi_udp_awvalid		),
  .us0_bid			(		),
  .us0_bready		(s_axi_udp_bready		),
  .us0_bresp		(s_axi_udp_bresp		),
  .us0_bvalid		(s_axi_udp_bvalid		),
  .us0_rdata		(s_axi_udp_rdata		),
  .us0_rid			(		),
  .us0_rlast		(s_axi_udp_rlast		),
  .us0_rready		(s_axi_udp_rready		),
  .us0_rresp		(s_axi_udp_rresp		),
  .us0_rvalid		(s_axi_udp_rvalid		),
  .us0_wdata		(s_axi_udp_wdata		),
  .us0_wlast		(s_axi_udp_wlast		),
  .us0_wready		(s_axi_udp_wready		),
  .us0_wstrb		(s_axi_udp_wstrb		),
  .us0_wvalid		(s_axi_udp_wvalid		),
  
   .us1_araddr		('d0		),
   .us1_arburst		(2'b01		),
   .us1_arcache		('d0			),
   .us1_arid		('d0			),
   .us1_arlen		('d0				),
   .us1_arlock		('d0			),
   .us1_arprot		('d0			),
   .us1_arqos		('d0			),
   .us1_arready		(				),
   .us1_arsize		('b100		),
   .us1_arvalid		(1'b0				),
   .us1_awaddr		(s_axi_dma_awaddr				),
   .us1_awburst		(2'b01		),
   .us1_awcache		('d0			),
   .us1_awid		('d0			),
   .us1_awlen		(s_axi_dma_awlen				),
   .us1_awlock		('d0			),
   .us1_awprot		('d0			),
   .us1_awqos		('d0			),
   .us1_awready		(s_axi_dma_awready				),
   .us1_awsize		('b100		),
   .us1_awvalid		(s_axi_dma_awvalid		),
   .us1_bid			(		),
   .us1_bready		(s_axi_dma_bready		),
   .us1_bresp		(s_axi_dma_bresp		),
   .us1_bvalid		(s_axi_dma_bvalid		),
   .us1_rdata		(		),
   .us1_rid			(		),
   .us1_rlast		(		),
   .us1_rready		(1'b0		),
   .us1_rresp		(		),
   .us1_rvalid		(		),
   .us1_wdata		(s_axi_dma_wdata		),
   .us1_wlast		(s_axi_dma_wlast		),
   .us1_wready		(s_axi_dma_wready		),
   .us1_wstrb		(s_axi_dma_wstrb		),
   .us1_wvalid		(s_axi_dma_wvalid		),
  
  .ds0_araddr		(s_axi_ddr_araddr		),
  .ds0_arburst		(s_axi_ddr_arburst		),
  .ds0_arcache		(s_axi_ddr_arcache		),
  .ds0_arid			(s_axi_ddr_arid		),
  .ds0_arlen		(s_axi_ddr_arlen		),
  .ds0_arlock		(s_axi_ddr_arlock		),
  .ds0_arprot		(s_axi_ddr_arprot		),
  .ds0_arqos		(s_axi_ddr_arqos		),
  .ds0_arregion		(s_axi_ddr_arregion		),
  .ds0_arready		(s_axi_ddr_arready		),
  .ds0_arsize		(s_axi_ddr_arsize		),
  .ds0_arvalid		(s_axi_ddr_arvalid		),
  .ds0_awaddr		(s_axi_ddr_awaddr		),
  .ds0_awburst		(s_axi_ddr_awburst		),
  .ds0_awcache		(s_axi_ddr_awcache		),
  .ds0_awid			(s_axi_ddr_awid		),
  .ds0_awlen		(s_axi_ddr_awlen		),
  .ds0_awlock		(s_axi_ddr_awlock		),
  .ds0_awprot		(s_axi_ddr_awprot		),
  .ds0_awqos		(s_axi_ddr_awqos		),
  .ds0_awregion		(s_axi_ddr_awregion		),
  .ds0_awready		(s_axi_ddr_awready		),
  .ds0_awsize		(s_axi_ddr_awsize		),
  .ds0_awvalid		(s_axi_ddr_awvalid		),
  .ds0_bid			(s_axi_ddr_bid		),
  .ds0_bready		(s_axi_ddr_bready		),
  .ds0_bresp		(s_axi_ddr_bresp		),
  .ds0_bvalid		(s_axi_ddr_bvalid		),
  .ds0_rdata		(s_axi_ddr_rdata		),
  .ds0_rid			(s_axi_ddr_rid		),
  .ds0_rlast		(s_axi_ddr_rlast		),
  .ds0_rready		(s_axi_ddr_rready		),
  .ds0_rresp		(s_axi_ddr_rresp		),
  .ds0_rvalid		(s_axi_ddr_rvalid		),
  .ds0_wdata		(s_axi_ddr_wdata		),
  .ds0_wlast		(s_axi_ddr_wlast		),
  .ds0_wready		(s_axi_ddr_wready		),
  .ds0_wstrb		(s_axi_ddr_wstrb		),
  .ds0_wvalid		(s_axi_ddr_wvalid		)
//  .ds1_araddr		(		),
//  .ds1_arburst		(		),
//  .ds1_arcache		(		),
//  .ds1_arid			(		),
//  .ds1_arlen		(		),
//  .ds1_arlock		(		),
//  .ds1_arprot		(		),
//  .ds1_arqos		(		),
//  .ds1_arregion		(		),
//  .ds1_arready		(1'b0		),
//  .ds1_arsize		(		),
//  .ds1_arvalid		(		),
//  .ds1_awaddr		(		),
//  .ds1_awburst		(		),
//  .ds1_awcache		(		),
//  .ds1_awid			(		),
//  .ds1_awlen		(		),
//  .ds1_awlock		(		),
//  .ds1_awprot		(		),
//  .ds1_awqos		(		),
//  .ds1_awregion		(		),
//  .ds1_awready		(1'b0		),
//  .ds1_awsize		(		),
//  .ds1_awvalid		(		),
//  .ds1_bid			(		),
//  .ds1_bready		(		),
//  .ds1_bresp		(		),
//  .ds1_bvalid		(1'b0		),
//  .ds1_rdata		(		),
//  .ds1_rid			(		),
//  .ds1_rlast		(		),
//  .ds1_rready		(		),
//  .ds1_rresp		(		),
//  .ds1_rvalid		(1'b0		),
//  .ds1_wdata		(		),
//  .ds1_wlast		(		),
//  .ds1_wready		(1'b0		),
//  .ds1_wstrb		(		),
//  .ds1_wvalid		(		)
);
wire ad_rst;
wire collect_clk;
wire collect_rst;
wire 	collect_end;
wire [COLLECT_CHANNEL_NUM-1:0]  trigflg;
wire   [BUFLENWIDTH:0]  cachsize;
wire   [BUFLENWIDTH:0]  pre_cachsize;
//wire [COLLECT_CHANNEL_NUM-1:0]  collect_endreq_o;
wire   [15:0] 	ad_datin	;
wire  [15:0]  ad_datout	;
wire  [1:0]   ad_datoe	;
wire [127:0] sADdat;
wire          sADen;
wire [127:0] tADdat;
wire          tADen;

wire convin_en;
wire convout_en;
wire _ad_convst;
reg [1:0] ad_convst_t=0;
assign ad_clk=w_clk_100m;
assign ad_rst=~w_axifull_rstn;
assign collect_clk=w_clk_50m;
assign collect_rst=clk_50m_rst; 
assign ad_convst_out= convout_en ? _ad_convst : 1'b1;
assign ad_convst = ad_convst_t[1];
always @(posedge ad_clk) begin
	ad_convst_t[0]<= convin_en ? ad_convst_in : _ad_convst; 
	ad_convst_t[1]<= ad_convst_t[0];
end
cm2268_drv#(
    .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH	),
    .C_S_AXI_DATA_WIDTH (AXILITE_DATA_WIDTH	)
    )cm2268_drv_u0(
	.ad_clk		(ad_clk	),
	.ad_rstn		(~ad_rst	),
    .s_axilite_clk		(w_axilite_clk		),
    .s_axilite_rst		(w_axilite_rst		),
    .s_axilite_AWADDR	(s_axilite_awaddr	[2]	),
    .s_axilite_AWVALID	(s_axilite_awvalid	[2]	),
    .s_axilite_AWREADY	(s_axilite_awready	[2]	),
    .s_axilite_WDATA	(s_axilite_wdata	[2]	),
    .s_axilite_WSTRB	(s_axilite_wstrb	[2]	),
    .s_axilite_WVALID	(s_axilite_wvalid	[2]	),
    .s_axilite_WREADY	(s_axilite_wready	[2]	),
    .s_axilite_BRESP	(s_axilite_bresp	[2]	),
    .s_axilite_BVALID	(s_axilite_bvalid	[2]	),
    .s_axilite_BREADY	(s_axilite_bready	[2]	),
    .s_axilite_ARADDR	(s_axilite_araddr	[2]	),
    .s_axilite_ARVALID	(s_axilite_arvalid	[2]	),
    .s_axilite_ARREADY	(s_axilite_arready	[2]	),
    .s_axilite_RDATA	(s_axilite_rdata	[2]	),
    .s_axilite_RRESP	(s_axilite_rresp	[2]	),
    .s_axilite_RVALID	(s_axilite_rvalid	[2]	),
    .s_axilite_RREADY	(s_axilite_rready	[2]	),
    //.ad_convst_in   (ad_convst_in   ),
    //.ad_convst_out  (ad_convst_out   ),
    
	.ad_reset	(ad_reset		),
	.ad_convst	(_ad_convst		),
	.ad_busy	(ad_busy		),
	.ad_csn		(ad_csn			),
	.ad_rdn		(ad_rdn			),
	.ad_wrn		(ad_wrn			),
	.ad_frstdat	(ad_frstdat		),
	.ad_datin	(ad_datin		),
	.ad_datout	(ad_datout		),
	.ad_datoe	(ad_datoe		),
	.collect_clk(collect_clk),
	.ad_data	(sADdat		),    
	.ad_daten		(sADen			)

	);
// wire [7:0] collect_en;
// wire [7:0] collect_endreq;
 wire DMA_oksta;
mstar_collectdma
#(
	// Parameter Declarations
	.C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH	),
    .C_S_AXI_DATA_WIDTH (AXILITE_DATA_WIDTH	),
	.C_M_AXI_ADDR_WIDTH (BUFLENWIDTH+1	),
	.C_M_AXI_DATA_WIDTH (AXIFUL_DATA_WIDTH	)
)mstar_collectdma_u0(
	// Input Ports
	
	.ad_clk		(collect_clk	),
	.ad_rst		(collect_rst	),
	.s_axis_tvalid	(tADen	),
	.s_axis_tdata	(tADdat),
	.s_axilite_clk		(w_axilite_clk		),
    .s_axilite_rst		(w_axilite_rst		),
    .s_axilite_AWADDR	(s_axilite_awaddr	[1]	),
    .s_axilite_AWVALID	(s_axilite_awvalid	[1]	),
    .s_axilite_AWREADY	(s_axilite_awready	[1]	),
    .s_axilite_WDATA	(s_axilite_wdata	[1]	),
    .s_axilite_WSTRB	(s_axilite_wstrb	[1]	),
    .s_axilite_WVALID	(s_axilite_wvalid	[1]	),
    .s_axilite_WREADY	(s_axilite_wready	[1]	),
    .s_axilite_BRESP	(s_axilite_bresp	[1]	),
    .s_axilite_BVALID	(s_axilite_bvalid	[1]	),
    .s_axilite_BREADY	(s_axilite_bready	[1]	),
    .s_axilite_ARADDR	(s_axilite_araddr	[1]	),
    .s_axilite_ARVALID	(s_axilite_arvalid	[1]	),
    .s_axilite_ARREADY	(s_axilite_arready	[1]	),
    .s_axilite_RDATA	(s_axilite_rdata	[1]	),
    .s_axilite_RRESP	(s_axilite_rresp	[1]	),
    .s_axilite_RVALID	(s_axilite_rvalid	[1]	),
    .s_axilite_RREADY	(s_axilite_rready	[1]	),

	// AXI4 master interface (write only)
	.m_axi_clk			(w_axifull_clk	),
	.m_axi_rst			(~w_axifull_rstn	),
	.m_axi_awvalid           ( s_axi_dma_awvalid           ) ,
	.m_axi_awready           ( s_axi_dma_awready           ) ,
	.m_axi_awaddr            ( s_axi_dma_awaddr            ) ,
	.m_axi_awlen             ( s_axi_dma_awlen             ) ,
	.m_axi_wvalid            ( s_axi_dma_wvalid            ) ,
	.m_axi_wready            ( s_axi_dma_wready            ) ,
	.m_axi_wdata             ( s_axi_dma_wdata             ) ,
	.m_axi_wstrb             ( s_axi_dma_wstrb             ) ,
	.m_axi_wlast             ( s_axi_dma_wlast             ) ,
	.m_axi_bvalid            ( s_axi_dma_bvalid            ) ,
	.m_axi_bready            ( s_axi_dma_bready            ) ,
    .DMA_oksta          (DMA_oksta),
	.buflen				(cachsize	),						
	.pre_buflen			(pre_cachsize	),	
	.collect_end    (collect_end)
);
// reg           trig_in_t=0;
//reg          trig_out_t=0;
// wire    trigout_en;
// wire    trigin_en;
// assign trig_out=trigout_en ? |trigflg : 1'b0;
// always @(posedge collect_clk)begin
    // trig_in_t<=trigin_en ? trig_in : 1'b0;
// end

mstar_collect
#(
	.C_S_AXI_ADDR_WIDTH (MODEL_ADDRESS_SPACE	),
	.C_S_AXI_DATA_WIDTH (AXILITE_DATA_WIDTH	),
	.BUFLENWIDTH		(BUFLENWIDTH	),
	.MODEL_ADDRESS_SPACE (MODEL_ADDRESS_SPACE),
	.AD_DATWIDTH        (AD_DATWIDTH)
)mstar_collect_u0(
	.ad_clk		(collect_clk	),
	.ad_rst		(collect_rst	),
	.ADdat		(sADdat	),
	.ADen		(sADen	),
	
	.s_axilite_clk		(w_axilite_clk		),
	.s_axilite_rst		(w_axilite_rst		),
	.s_axilite_AWADDR	(s_axilite_awaddr	[0]),
	.s_axilite_AWVALID	(s_axilite_awvalid	[0]),
	.s_axilite_AWREADY	(s_axilite_awready	[0]),
	.s_axilite_WDATA	(s_axilite_wdata	[0]),
	.s_axilite_WSTRB	(s_axilite_wstrb	[0]),
	.s_axilite_WVALID	(s_axilite_wvalid	[0]),
	.s_axilite_WREADY	(s_axilite_wready	[0]),
	.s_axilite_BRESP	(s_axilite_bresp	[0]),
	.s_axilite_BVALID	(s_axilite_bvalid	[0]),
	.s_axilite_BREADY	(s_axilite_bready	[0]),
	.s_axilite_ARADDR	(s_axilite_araddr	[0]),
	.s_axilite_ARVALID	(s_axilite_arvalid	[0]),
	.s_axilite_ARREADY	(s_axilite_arready	[0]),
	.s_axilite_RDATA	(s_axilite_rdata	[0]),
	.s_axilite_RRESP	(s_axilite_rresp	[0]),
	.s_axilite_RVALID	(s_axilite_rvalid	[0]),
	.s_axilite_RREADY	(s_axilite_rready	[0]),
	
	.tADdat			(tADdat	),
	.tADen			(tADen	),
	.cachsize		(0|cachsize[BUFLENWIDTH:4]	),						
	.pre_cachsize	(0|pre_cachsize),
	.convin_en		(convin_en	),
	.convout_en		(convout_en	),
	.collect_end    (collect_end),
    .collect_doing  (collect_doing   ),
	.out_trigflg	(trig_out	),						//触发信号输出
	.in_trigflg		(trig_in	),					//外部触发输入
	.out_port		(out_port	),
	.in_port		(in_port	)
	);

genvar i;
generate 
    for (i=0; i<COLLECT_CHANNEL_NUM; i=i+1)
    begin 
        PH1P_LOGIC_IOTRIBUF u1_PH1P_LOGIC_IOTRIBUF_u1 (
    		.i(ad_datout[i]),
    		.t(ad_datoe[0]),
    		.o(ad_datin[i]),
    		.io(ad_data[i])
    	);
        PH1P_LOGIC_IOTRIBUF u1_PH1P_LOGIC_IOTRIBUF_u2 (
    		.i(ad_datout[i+8]),
    		.t(ad_datoe[1]),
    		.o(ad_datin[i+8]),
    		.io(ad_data[i+8])
    	);
    end
endgenerate

	 PH1P_LOGIC_IOTRIBUF MdIO_PH1P_LOGIC_IOTRIBUF_U0 (
		 .i(mdio_out),
		 .t(mdio_oe),
		 .o(mdio_in),
		 .io(mdio)
	 );
//	mstar_rgmii mstar_rgmii_u0
//   (
//		.reset(clk_125M_rst),
//		.clk_125M	(w_clk_125M	),
//		.speed_10_int		(1'b0	),
//		.speed_100_int		(speed_status_100M	),
//		.speed_1000_int		(speed_status_1g	),
//		.rx_axis_mac_tdata	(rx_axis_mac_tdata	),
//		.rx_axis_mac_tvalid	(rx_axis_mac_tvalid	),
//		.rx_axis_mac_tlast	(rx_axis_mac_tlast	),
//		//.rx_axis_mac_tuser	(rx_axis_mac_tuser	),
//		.rx_axis_mac_tready	(rx_axis_mac_tready	), 
//		.tx_axis_mac_tdata  (tx_axis_mac_tdata	),
//		.tx_axis_mac_tvalid (tx_axis_mac_tvalid	),
//		.tx_axis_mac_tlast  (tx_axis_mac_tlast	),
//		.tx_axis_mac_tready (tx_axis_mac_tready	),
//      // RGMII 接口
//      //----------------------------------
//		.rgmii_txd		(rgmii_txd			),
//		.rgmii_tx_ctl	(rgmii_tx_ctl		),
//		.rgmii_txc		(rgmii_txc			),
//		.rgmii_rxd		(rgmii_rxd			),
//		.rgmii_rx_ctl	(rgmii_rx_ctl		),
//		.rgmii_rxc		(rgmii_rxc			)

//   );
   
   
//    mac_progress mac_progress_u0(
//    .clk    (w_axilite_clk),
//	.rst    (w_axilite_rst),
//    .speed_status(speed_status),
//	.link_error         (_link_error),
//	.read_ack_error     (_phy_ack_error),	//
//	.mdc                (mdc),
//	.mdio_in            (mdio_in),
//	.mdio_out           (mdio_out),
//	.mdio_oe            (mdio_oe)
//	);

endmodule

