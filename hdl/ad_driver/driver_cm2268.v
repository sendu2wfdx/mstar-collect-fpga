//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: driver_cm2268
// Description: CM2268 ADC 芯片驱动，实现 AD 采样时序控制、数据读写
//              及寄存器/采样双模式切换
//============================================================================
module driver_cm2268#(
	parameter FREQ_DIV_MIN=100
)
(
	input 			clk, 		//100M
	input 			rstn,
	input [15:0] 	freq_div,
	input 			collect_en,
    input           in_convclk_en,
	output reg 		modeflg, 	//0: regmode  1: admode
	input [6:0] 	ctrl_addr,
	input [1:0]     ctrl_size, //num dat byte
	input [31:0]		ctrl_wdata,
	input 			ctrl_wrflg,	//0:write,1:read
	output reg [31:0]    ctrl_rdata=0,
	input 			ctrl_start,
	output reg      ctrl_done=1,
	//output 			ad_reset,
	output reg		ad_convst=1,
	input  			ad_busy,
	output reg		ad_csn=1,
	output reg      ad_rdn=1,
	output reg		ad_wrn=1,
	input           ad_frstdat,
	input [15:0] 	ad_datin,
	output reg [15:0]    ad_datout,
	output reg [1:0]    ad_datoe,
	input 				collect_clk,	//50M
	output reg [128:0]  ad_data,    
	output reg		    ad_dataen=0
);
//reg [15:0] 	freq_cnt;
reg [5:0] 	cnt;
reg  [3:0]  cur_state     ;
reg  [3:0]  cur_next      ;

reg r_collect_en=0;

localparam  st_idle      = 'd0;
localparam  st_inreg     = 'd1;
localparam  st_read      = 'd2;
localparam  st_write     = 'd3;
localparam  st_exitreg	 = 'd4;
localparam  st_wstz      = 'd5;
localparam  st_busydown  = 'd6;
localparam  st_adread    = 'd7;

reg ad_frstdat_temp;
wire [15:0] w_freq_div;
reg [15:0] r_freq_cnt;
reg [1:0] busy_temp=0;
wire busy_down;
reg [31:0]	ctrl_wdata_temp;
reg [128:0]  ad_dat=0;    
reg		ad_daten=0;
reg [1:0] ad_dataen_temp;



assign w_freq_div=freq_div<FREQ_DIV_MIN ? (FREQ_DIV_MIN-1) : (freq_div-1);
always @(posedge collect_clk) begin
    if(ad_dataen_temp[0]) ad_data<=ad_dat;
	ad_dataen_temp<={ad_dataen_temp[0],ad_daten};
	ad_dataen<=(ad_dataen_temp[0]^ad_dataen_temp[1])&ad_dataen_temp[0];
end
always @(posedge clk) begin
	if(~rstn)begin
		r_freq_cnt<=0;
	end else begin
		//if(cur_state==st_busydown||cur_state==st_adread)begin
		if(r_collect_en&(~in_convclk_en))begin
			if(r_freq_cnt<w_freq_div) begin
				r_freq_cnt<=r_freq_cnt+1'b1;
			end else begin
				r_freq_cnt<=0;
			end
		end else begin
			r_freq_cnt<=0;
		end
	end
end
	
always @(posedge clk) begin
	busy_temp<={busy_temp[0],ad_busy};
	ad_convst<= r_freq_cnt<(FREQ_DIV_MIN-2)||r_freq_cnt>FREQ_DIV_MIN;
	r_collect_en<=collect_en;
end
assign busy_down=busy_temp[1]^busy_temp[0]&busy_temp[1];
always @(posedge clk) begin
	if (~rstn)
		cur_state <= st_idle;
	else
		cur_state <= cur_next;
end
always @(*) begin
	case (cur_state)
		st_idle:
			if (r_collect_en)
				cur_next = st_busydown;
			else if(ctrl_start) 
				cur_next = st_inreg;
			else 
				cur_next = st_idle;
		st_inreg:begin
		   if(cnt[2:0]==3'b111)begin
				cur_next = ctrl_wrflg ? st_read : st_write;
			end else 
				cur_next = st_inreg;
		end
		st_read:
			if(cnt[2:0]==3'b111&&cnt[4:3]==ctrl_size)begin
				cur_next = st_exitreg;
			end else 
				cur_next = st_read;
		st_write:
			if(cnt[2:0]==3'b111&&cnt[4:3]==ctrl_size)begin
				cur_next = st_exitreg;
			end else 
				cur_next = st_write;
		st_exitreg:
			if(cnt[2:0]==3'b111)begin
				cur_next = st_wstz;
			end else 
				cur_next = st_exitreg;
		st_wstz:
			if(~ctrl_start)
				cur_next = st_idle;
			else
				cur_next = st_wstz;
		st_busydown:
			if(~r_collect_en) 
				cur_next = st_idle;
			else if (busy_down) 
				cur_next = st_adread;
			else
				cur_next = st_busydown;
		st_adread:
			if (cnt==6'h1F) begin
				cur_next = st_busydown; 
			end else
				cur_next = st_adread;
		default:
				cur_next = st_idle;
	endcase
end

always @(posedge clk)
begin
	if (~rstn) begin
		cnt<=0;
		modeflg<=0;
		ad_csn<=1;
		ad_rdn<=1;
		ad_wrn<=1;
		ctrl_done<=1;
		ad_datoe<=2'b11;
        ad_datout<=0;
		ad_daten<=0;
	end else begin
		
		case(cur_state)
		st_idle:begin
			modeflg<=0;
			ad_rdn<=1;
			ad_wrn<=1;
			ad_daten<=0;
			cnt<=0;
			if(ctrl_start)begin
				ctrl_done<=0;
				ad_csn<=0;
		        ad_datoe[1]<=0;
			end else begin
				ctrl_done<=1;
				ad_csn<=1;
		        ad_datoe[1]<=1;
			end
		end
		st_inreg:begin
		    if(cnt[3:0]==0)begin
		        ad_wrn<=0;
				ad_datout[15:8]<={1'b1,ctrl_addr};
		    end
			if(cnt[2:0]==3'b100) begin ad_wrn<=1; end
			if(cnt[2:0]==3'b111) begin
			     cnt<=0;
			     ctrl_wdata_temp<=ctrl_wdata;
			end else begin
			     cnt<=cnt+1'b1;
			end
		end
		st_read: begin
			cnt<=cnt+1'b1;
			if(cnt[2:0]==0) begin 
				ad_rdn<=0;
				ad_datout[15]<=1'b0;
				ad_datout[14:8]<=ctrl_addr+cnt[4:3];
			end
			if(cnt[2:0]==3'b100) begin ad_rdn<=1;ctrl_rdata<={ad_datin[7:0],ctrl_rdata[31:8]}; end
			//if(cnt[2:0]==3'b111) begin ctrl_rdata<={ad_datin[7:0],ctrl_rdata[31:8]};end
		end			
		st_write:begin
			//ad_csn<=0;
			cnt<=cnt+1'b1;
			ad_datoe<=2'b00;
			//ad_rdn<=1;
			if(cnt[2:0]==0) begin 
				ad_wrn<=0;
				ad_datout[15]<=1'b0;
				ad_datout[14:8]<=ctrl_addr+cnt[4:3];
				ad_datout[7:0]<=ctrl_wdata_temp[7:0];
			end
			if(cnt[2:0]==3'b100) begin ad_wrn<=1; end
            if(cnt[2:0]==3'b111) begin ctrl_wdata_temp<={8'd0,ctrl_wdata_temp[31:8]};end
		end
		st_exitreg:begin
			cnt<=cnt+1'b1;
			//ad_rdn<=1;
			ad_datout<=0;
			if(cnt[2:0]==0)begin
				ad_wrn<=0;
			end
			if(cnt[2:0]==3'b100) begin ad_wrn<=1;end
		end
		st_wstz: begin
			ad_datoe<=2'b11;
			ad_csn<=1;
			ctrl_done<=1;
		end
		st_busydown: begin
			modeflg<=1;
			cnt<=0;

			if(busy_down)begin 
				ad_csn<=0;
				 ad_daten<=0;
				//ad_rdn<=0;
			end else begin
				ad_csn<=1;
				//ad_rdn<=0;
			end
		end
		st_adread: begin
			cnt<=cnt+1'b1;
			
			if(cnt[1:0]==0) ad_rdn<=0;
			if(cnt[1:0]==2'b10)begin
			     //ad_rdn<=1;
				
			     ad_frstdat_temp<=ad_frstdat;
			     ad_dat<={ad_datin,ad_dat[127:16]};
			end
			if(cnt[1:0]==2'b11) begin
			     ad_rdn<=1;
				//if(ad_frstdat_temp) cnt<=6'b000100;
			end
			if (cnt==6'h1F) ad_daten<=1;
		end
		endcase
	end
end
endmodule
