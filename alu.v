module alu (Accum, Pcomp, Pterm, Fwd, A2D_res, Error, Intgrl, Icomp, Iterm,
             src1sel, src0sel, multiply, sub, mult2, mult4, saturate, dst);

  input signed [15:0] Accum, Pcomp;
  input [13:0] Pterm;
  input signed [11:0] Icomp, Error, Intgrl;
  input [11:0] Iterm, Fwd, A2D_res;
  input [2:0] src0sel, src1sel;
  input mult2, mult4, sub, multiply, saturate;

  reg [15:0] sum;
  reg [15:0] pre_src0, pre_src1;
  reg signed [15:0] saturated_sum;
  reg signed [15:0] saturated_mult;
  reg signed [14:0] signed_src0, signed_src1;
  reg signed [29:0] signed_mult;  
  output reg signed [15:0] dst;

  
  // values for src1sel
  localparam Accum2Src1 = 3'b000;
  localparam Iterm2Src1 = 3'b001;
  localparam Err2Src1 = 3'b010;
  localparam ErrDiv22Src1 = 3'b011;
  localparam Fwd2Src1 = 3'b100;
  
  // values for src0sel
  localparam A2D2Src0 = 3'b000;
  localparam Intgrl2Src0 = 3'b001;
  localparam Icomp2Src0 = 3'b010;
  localparam Pcomp2Src0 = 3'b011;
  localparam Pterm2Src0 = 3'b100;
    

always @ (src0sel, src1sel, Accum, Pcomp, Pterm, Icomp, Error, Intgrl, Iterm, Fwd, A2D_res, mult2, mult4, sub, multiply, saturate) begin
  assign pre_src0[15:0] = (src0sel == A2D2Src0)? {4'b0000,A2D_res}:
                        (src0sel == Intgrl2Src0)? {{4{Intgrl[11]}},Intgrl}:
			(src0sel == Icomp2Src0)? {{4{Icomp[11]}},Icomp}:
			(src0sel == Pcomp2Src0)? Pcomp:
			(src0sel == Pterm2Src0)? {2'b00,Pterm}:
			16'h0000; // set the result to 0 by default  */

  assign pre_src1[15:0] = (src1sel == Accum2Src1) ? Accum:
                        (src1sel == Iterm2Src1) ? {4'b0000,Iterm}:
			(src1sel == Err2Src1) ? {{4{Error[11]}},Error}:
			(src1sel == ErrDiv22Src1) ? {{8{Error[11]}},Error[11:4]}:
			(src1sel == Fwd2Src1) ? {4'b0000,Fwd}:
			16'h0000; // set the resulting src1 to 0 by default


  // scale src0 depending on the input signal
  assign pre_src0 = (mult2 == 1'b1) ? pre_src0 << 1:
 		        (mult4 == 1'b1) ? pre_src0 << 2:
		    	pre_src0; 	
 
  assign pre_src0 = (sub == 1'b1) ? ~pre_src0 : pre_src0; // perform 1's complement to prepare src0 for subtraction
		

  assign sum = (sub == 1) ? pre_src0 + pre_src1 + sub: // make src0 negative to do subtraction from src1
				    pre_src0 + pre_src1; // default case, just adding

  assign saturated_sum = (saturate == 1 && sum[15] == 1'b0 && sum > 16'h07FF) ? 16'h07FF:
 			 (saturate == 1 && sum[15] == 1'b1 && sum < 16'hF800) ? 16'hF800:
	   		 sum;

  // 15x15 multiplier
  assign signed_src0 = pre_src0[14:0];
  assign signed_src1 = pre_src1[14:0];
  assign signed_mult = signed_src0 * signed_src1;

  // saturate multiplication result from the 15x15 multiplier
  assign saturated_mult = (signed_mult[29] == 1'b1 && signed_mult[28:26] != 3'b111) ? 16'hC000:
				  (signed_mult[29] == 1'b0 && signed_mult[28:26] != 3'b000) ? 16'h3FFF:
				  signed_mult[27:12];

  // select which saturated result to out put as dst
  assign dst = (multiply == 1'b1) ? saturated_mult:
               (multiply == 1'b0) ? saturated_sum:
	       16'h0000;
end

endmodule
