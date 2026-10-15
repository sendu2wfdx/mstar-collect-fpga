`timescale 1ns / 1ps
//============================================================================
// Copyright (c) 2026 Hangzhou Magicstar Technology Co., Ltd.
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Module: get_singer_edge
// Description: 单边沿检测模块，检测输入信号的上升沿或下降沿
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


module get_singer_edge#(
        parameter SING_WIDTH=1
     )(
        input clk,
        input wire [SING_WIDTH-1:0] i_sing,
        output wire [SING_WIDTH-1:0] o_sing_up, 
        output wire [SING_WIDTH-1:0] o_sing_down,
		output wire [SING_WIDTH-1:0] o_sing_sync
    );
    reg [SING_WIDTH-1:0] i_sing_temp0= 0;
    reg [SING_WIDTH-1:0] i_sing_temp1= 0;
    always @(posedge clk) begin
         {i_sing_temp1,i_sing_temp0}<={i_sing_temp0,i_sing};
    end
    assign o_sing_up = ~i_sing_temp1 & i_sing_temp0;
    assign o_sing_down = i_sing_temp1 & ~i_sing_temp0;
	assign o_sing_sync = i_sing_temp1;
endmodule
