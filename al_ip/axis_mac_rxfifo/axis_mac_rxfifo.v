/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Aug 10 2026 20:04:24
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ps
module axis_mac_rxfifo
(
  input                         us_aclk,
  input                         us_aresetn,
  input                         us_tvalid,
  output                        us_tready,
  input   [7:0]                 us_tdata,
  input                         us_tlast,
  input   [0:0]                 us_tuser,
  output                        almost_full,
  input                         ds_aclk,
  output                        ds_tvalid,
  input                         ds_tready,
  output  [7:0]                 ds_tdata,
  output                        ds_tlast,
  output  [0:0]                 ds_tuser
);

  axis_data_fifo_axis_mac_rxfifo
  #(
      .AL_AXIS_TDATA_WIDTH(8),
      .AL_AXIS_TID_WIDTH(1),
      .AL_AXIS_TDEST_WIDTH(1),
      .AL_AXIS_TUSER_WIDTH(1),
      .AL_AXIS_SIGNAL_SET(32'b10010011),
      .AL_FIFO_DEPTH(4096),
      .AL_FIFO_MODE(1),
      .AL_IS_ACLK_ASYNC(1),
      .AL_ACLKEN_CONV_MODE(0)
  )axis_data_fifo_Inst
  (
      .us_aclk(us_aclk),
      .us_aresetn(us_aresetn),
      .us_tvalid(us_tvalid),
      .us_tready(us_tready),
      .us_tdata(us_tdata),
      .us_tlast(us_tlast),
      .us_tuser(us_tuser),
      .almost_full(almost_full),
      .ds_aclk(ds_aclk),
      .ds_tvalid(ds_tvalid),
      .ds_tready(ds_tready),
      .ds_tdata(ds_tdata),
      .ds_tlast(ds_tlast),
      .ds_tuser(ds_tuser)
  );
endmodule
