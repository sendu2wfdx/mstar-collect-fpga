/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Jun 22 2026 19:42:11
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ps
module axis_dmadat_fifo
(
  input                         us_aclk,
  input                         us_aresetn,
  input                         us_tvalid,
  output                        us_tready,
  input   [127:0]               us_tdata,
  input                         ds_aclk,
  output                        ds_tvalid,
  input                         ds_tready,
  output  [127:0]               ds_tdata,
  output  [0:0]                 ds_tuser,
  output  [31:0]                axis_rd_data_count
);

  axis_data_fifo_axis_dmadat_fifo
  #(
      .AL_AXIS_TDATA_WIDTH(128),
      .AL_AXIS_TID_WIDTH(1),
      .AL_AXIS_TDEST_WIDTH(1),
      .AL_AXIS_TUSER_WIDTH(1),
      .AL_AXIS_SIGNAL_SET(32'b00000011),
      .AL_FIFO_DEPTH(512),
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
      .ds_aclk(ds_aclk),
      .ds_tvalid(ds_tvalid),
      .ds_tready(ds_tready),
      .ds_tdata(ds_tdata),
      .ds_tuser(ds_tuser),
      .axis_rd_data_count(axis_rd_data_count)
  );
endmodule
