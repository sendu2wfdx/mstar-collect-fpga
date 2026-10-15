//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: triggel
// Description: 数据触发模块，支持边沿触发、电平触发等多种触发模式，
//              实现采集窗口的位置控制
//============================================================================
//数据触发
//
module triggel
#(
	parameter BUFLENWIDTH=18,					//BUF大小宽度
	parameter POSITION_WIDTH=BUFLENWIDTH,
	parameter AD_DATWIDTH=16
)
(
	// Input Ports
	input 			clk_50M,
	input 			rst,
	input 			colection_en,					//采样使能信号
	input 			colection_endreq,			//采样结束伸请信号
	//input [7:0] 	freqdiv,							//采样分频
	input [AD_DATWIDTH-1:0] 	trigdat,							//触发阿倿
	input [2:0]    trig_type,						//触发方式0：不触发 1：电平触发，2：上升沿触发 3：下降沿触发
	//input [1:0]    trig_en,							//使能触发 bit0：内部触发使能，bit1:外部触发使能;	
	input [AD_DATWIDTH-1:0] 	ADdat,
	input  			ADen,
	input wire [BUFLENWIDTH-1:0] 	cachsize,						//缓存大小
	input wire [BUFLENWIDTH-1:0] 	pre_cachsize,					//触发前缓存大尿
	//output wire [POSITION_WIDTH-1:0] 	cur_relative_position,	//当前采样相对位置
	output reg [POSITION_WIDTH-1:0] 	end_relative_position,		//采样结束相对位置
	output reg [POSITION_WIDTH-1:0] 	trig_relative_position,		//触发的相对位罿
	output reg		colection_end,						//触发结束信号
	output   		trigflg,							//触发标志
	//output			out_trigflg,						//输出外部触发
	input 			in_trigflg,							//外部触发
	output wire [AD_DATWIDTH-1:0] 	tADdat,
	output wire  			tADen
	//output wire trig_out,
	// input wire up_flg,
	// input wire down_flg
	
);
	localparam TRIG_TYPE_NORMAL=3'b000;		//采集一次
	localparam TRIG_TYPE_LEVEL=3'b001;		
	localparam TRIG_TYPE_UP=3'b010;
	localparam TRIG_TYPE_DOWN=3'b011;
	localparam TRIG_TYPE_CONTINUITY=3'b100;	//连续采集

reg [POSITION_WIDTH-1:0] r_position_counter;
reg r_triger_flg;					//触发标志
//reg [AD_DATWIDTH-1:0] 	r_ADdat_temp;		//ADdat信号延时1个CLK
//reg [15:0] 	r_ADdat_temp1;		//ADdat信号延时2个CLK
//reg [15:0] 	r_ADdat_temp2;		//ADdat信号延时3个CLK
//reg [15:0] 	r_ADdat_temp3;		//ADdat信号延时4个CLK
//reg r_ADen_temp;					//ADen信号延时1个CLK
reg r_colection_en;				//锁存弿始使能信叿
reg r_firststorage_flg;				//第一次缓存结束标忿

wire  w_up_flg,w_down_flg;
//reg [3:0] r_up_flg,r_down_flg;
wire w_trigel_datflg;				//触发判断标志
reg r_trigel_datflg=0;
wire w_triger_flgUD;


//wire [AD_DATWIDTH-1:0] 	w_div_ADdat;
//wire  			w_div_ADen;
//wire [AD_DATWIDTH-1:0] w_ADdat_P;
wire [AD_DATWIDTH-1:0] 	w_ADdat;
wire  			w_ADen;
wire [POSITION_WIDTH-1:0] w_max_position;
reg  			r_colection_end;
reg  			r_colection_end_delay;
reg r_colection_entemp1=0;
reg r_colection_entemp2=0;
wire w_enclr;
//wire out_trigen,cur_trigen;

//assign out_trigen=trig_en[1];	//外部触发使能
//assign cur_trigen=trig_en[0];	//本模块触发使胿
//assign out_trigflg=cur_trigen&trigflg;

//wire [POSITION_WIDTH-5:0] w_end_relative_position;
assign w_max_position= (cachsize-1'b1);
//assign w_max_position[1:0]=2'b11;
													
get_extreflg#(.AD_DATWIDTH(AD_DATWIDTH)) get_extreflg_u0			
(
	.clk_50M(clk_50M),
	.rst(rst),
	.addat_in(ADdat),
	.aden_in(ADen),
	.upflg(w_up_flg),	//上升标志
	.downflg(w_down_flg),//下降标志
	.maxdat_flg(),//朿大忼标忿
	.mindat_flg(),//朿小忼标忿
	.addat_out(w_ADdat),
	.aden_out(w_ADen)
);													
// assign w_ADen = ADen;
// assign w_ADdat = ADdat;
// assign w_down_flg = down_flg;
// assign w_up_flg = up_flg;
														
assign tADen 	= r_colection_en & w_ADen;
assign tADdat 	= r_colection_en ?  w_ADdat : 0;

//assign w_ADdat_P= w_ADdat[AD_DATWIDTH-1] ?  ((~w_ADdat)+1'b1) : w_ADdat;  //取绝对忿

assign w_trigel_datflg = (trigdat[AD_DATWIDTH-1] ? (~w_ADdat[AD_DATWIDTH-1] ? 1'b1 : ( w_ADdat <= trigdat)) : 
                                 (w_ADdat[AD_DATWIDTH-1] ? 1'b0 : ( w_ADdat >= trigdat)));//&&cur_trigen ;
assign trigflg=r_triger_flg;
wire in_trigflg_up;
reg _in_trigflg;
get_singer_edge#(.SING_WIDTH(1)) get_singer_edge_u0(.clk(clk_50M),.i_sing(in_trigflg),.o_sing_up(in_trigflg_up),.o_sing_down(),.o_sing_sync());

//assign w_trigel_datflg = w_ADdat[AD_DATWIDTH-1] ?  (trigdat[AD_DATWIDTH-1] ? (trigdat >= w_ADdat) : 0 ) : 
//															(trigdat[AD_DATWIDTH-1] ?  0 : (trigdat <= w_ADdat)) ;
//assign w_end_relative_position= (trig_relative_position[POSITION_WIDTH-1:4]==0) ? w_max_position[POSITION_WIDTH-1:4] : 
//											(trig_relative_position[POSITION_WIDTH-1:4]-1);
always @(posedge clk_50M)
begin
    if(rst|w_enclr)begin
        trig_relative_position<=0;
        _in_trigflg<=0;
    end else begin
        _in_trigflg<=in_trigflg;
        if(in_trigflg_up)
            trig_relative_position<=r_position_counter;
    end
end
always @(posedge clk_50M)
begin
    if(w_ADen) r_trigel_datflg<=w_trigel_datflg;
	r_colection_entemp1<=colection_en;
	r_colection_entemp2<=r_colection_entemp1;
end
assign w_triger_flgUD= r_trigel_datflg^w_trigel_datflg;
assign w_enclr=(r_colection_entemp1^r_colection_entemp2)&r_colection_entemp1;
always @(posedge clk_50M or posedge rst or posedge w_enclr)
begin
	if(rst|w_enclr)
	begin
		r_position_counter<=0;
		r_triger_flg<=0;
		r_colection_end<=0;
		r_colection_end_delay<=0;
		r_colection_en<=0;
		colection_end<=0;
		//trig_relative_position<=0;
		end_relative_position<=0;
		r_firststorage_flg<=0;
	end
	//else if(colection_endreq)
	//begin
	//	r_colection_end<=1;
	//	end_relative_position<=r_position_counter;
	//	r_colection_en<=0;
	//end
	else if(w_ADen)
	begin
		r_colection_end_delay<=r_colection_end;
		colection_end<=r_colection_end_delay;
		if(r_colection_entemp2&&(r_colection_en==0)&&(r_colection_end==0))
		begin
			r_colection_en<=1;
			//colection_end<=0;
			r_triger_flg<=0;
			r_firststorage_flg<=0;
			//trig_relative_position<=0;
		end
		else if(r_colection_en&&(r_colection_end==0))
		begin
			if(r_position_counter<w_max_position)
				r_position_counter<=r_position_counter+1'b1;
			else
			begin
				r_position_counter<=0;
				//r_firststorage_flg<=1;			//第一次缓存结束标志置使
			end
			if((r_position_counter>=pre_cachsize)&&~r_firststorage_flg)
			begin
				r_firststorage_flg<=1;			//第一次缓存结束标志置使
			end
			if((_in_trigflg==0)&&r_firststorage_flg)
			begin
				if(r_position_counter==w_max_position&&colection_endreq)begin
					r_colection_end<=1;
					end_relative_position<=r_position_counter;
					r_colection_en<=0;
				end else begin
					case(trig_type)
					TRIG_TYPE_NORMAL:		//无触发采集
					begin
						if(r_position_counter==w_max_position)
						begin
							r_colection_end<=1;
							end_relative_position<=r_position_counter;
							r_colection_en<=0;
						end
					end
					TRIG_TYPE_LEVEL:		//电平触发采集
					begin
						if(w_trigel_datflg)
						begin
							//trig_relative_position<=r_position_counter;
							r_triger_flg<=1;
						end
					end
					TRIG_TYPE_UP:		//上升沿触发采集
						begin
							if(w_up_flg&&w_triger_flgUD)
							begin
								//trig_relative_position<=r_position_counter;
								r_triger_flg<=1;
							end
						end
					TRIG_TYPE_DOWN:	//TRIG_TYPE_DOWN		//下隆沿触发采集
						begin
							if(w_down_flg&&w_triger_flgUD)
							begin
								//trig_relative_position<=r_position_counter;
								r_triger_flg<=1;
							end
						end
					endcase
				end
			end
			// if(in_trigflg)begin
				// if(r_position_counter>0)
					// trig_relative_position<=r_position_counter-1;
				// else
					// trig_relative_position<=w_max_position;
				// r_triger_flg<=1;
			// end
			if(_in_trigflg)
			begin
//				if(w_end_relative_position==r_position_counter[POSITION_WIDTH-1:4])
//				begin
//					colection_end<=1;
//					end_relative_position<=r_position_counter;
//					r_colection_en<=0;
//				end
				if(trig_relative_position>=pre_cachsize)
				begin
					if(r_position_counter==(trig_relative_position-pre_cachsize))
					begin
						r_colection_end<=1;
						end_relative_position<=r_position_counter;
						r_colection_en<=0;
					end
				end
				else
				begin
					if(r_position_counter==((cachsize+trig_relative_position)-pre_cachsize))
					begin
						r_colection_end<=1;
						end_relative_position<=r_position_counter;
						r_colection_en<=0;
					end
				end					
			end
		end
		else
		begin
			r_position_counter<=0;
		end
		
	end	
end


endmodule
