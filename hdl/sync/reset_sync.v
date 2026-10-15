// ===========================================================================
// Copyright (c) 2011-2020 Anlogic Inc. All Right Reserved.
//
// TEL: 86-21-61633787
// WEB: http://www.anlogic.com/
// ===========================================================================
//
//
//  
//
//
// ===========================================================================
module reset_sync 
#(
  parameter INITIALISE = 2'b11
)
(
   input       reset_in,
   input       clk,
   //input       enable,
   output reg  reset_out
);

reg reset_1dly;
reg reset_2dly;
reg reset_3dly;

always @ (posedge clk or posedge reset_in)
begin
    if (reset_in == 1'b1) begin
        reset_1dly <= 1'b1;
        reset_2dly <= 1'b1;
        reset_3dly <= 1'b1;
        reset_out  <= 1'b1;
    end else begin
        reset_1dly <= 1'b0;
        reset_2dly <= reset_1dly;
        reset_3dly <= reset_2dly;
        reset_out  <= reset_3dly;
    end
end

/*  FDPE #(
   .INIT (INITIALISE[0])
  ) reset_sync1 (
  .C  (clk), 
  .CE (enable),
  .PRE(reset_in),
  .D  (1'b0),
  .Q  (reset_stage1) 
  );
  
  FDPE #(
   .INIT (INITIALISE[1])
  ) reset_sync2 (
  .C  (clk), 
  .CE (enable),
  .PRE(reset_in),
  .D  (reset_stage1),
  .Q  (reset_stage2) 
  );*/


//assign reset_out = reset_stage2;



endmodule
