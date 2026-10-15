//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: get_extreflg
// Description: 外部参考标志检测，提取 AD 数据中的参考信号边沿
//============================================================================
module get_extreflg				//delay 2 clk
#(
	parameter AD_DATWIDTH=32
)
(
	input clk_50M,
	input rst,
	input [AD_DATWIDTH-1:0] addat_in,
	input aden_in,
	output wire upflg,	//上升标志
	output wire downflg,//下降标志
	output wire maxdat_flg,//�?大�?�标�?
	output wire mindat_flg,//�?小�?�标�?
	output reg [AD_DATWIDTH-1:0] addat_out,
	output reg aden_out
);

reg [AD_DATWIDTH-1:0] 	r_ADdat_temp;		//ADdat信号延时1个CLK
//reg r_ADen_temp;
reg r_up_flg_temp;
reg r_down_flg_temp;
wire w_up_flg,w_down_flg;
always @(posedge clk_50M)begin
    aden_out<=aden_in;
    addat_out<=r_ADdat_temp;
end
always @(posedge clk_50M or posedge rst)
begin
	if(rst)
	begin
		r_ADdat_temp<=0;
		r_up_flg_temp<=0;
		r_down_flg_temp<=0;
		//r_ADen_temp<=0;
		//r_up_flg_temp1<=0;
		//r_down_flg_temp1<=0;
	end
	else if(aden_in)
	begin
		r_ADdat_temp<=addat_in;
		//r_up_flg_temp1<=r_up_flg_temp;
		//r_down_flg_temp1<=r_down_flg_temp;										
		r_up_flg_temp<=w_up_flg;		
		r_down_flg_temp<=w_down_flg;
		
	end
end

assign w_up_flg =  addat_in[AD_DATWIDTH-1] ? (r_ADdat_temp[AD_DATWIDTH-1] ? (addat_in>r_ADdat_temp) : 0) : 
													r_ADdat_temp[AD_DATWIDTH-1] ?  1 : (addat_in>r_ADdat_temp);
assign w_down_flg = addat_in[AD_DATWIDTH-1] ? (r_ADdat_temp[AD_DATWIDTH-1] ? (addat_in<r_ADdat_temp) : 1) : 
													r_ADdat_temp[AD_DATWIDTH-1] ?  0 : (addat_in<r_ADdat_temp);
assign maxdat_flg=(r_up_flg_temp^w_up_flg)&r_up_flg_temp;
assign mindat_flg=(r_down_flg_temp^w_down_flg)&r_down_flg_temp;
assign upflg=r_up_flg_temp;
assign downflg=r_down_flg_temp;
//assign	addat_out=r_ADdat_temp;
//assign	aden_out=r_ADen_temp;
endmodule

