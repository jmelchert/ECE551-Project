module alu(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl, src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

// Initialize inputs
input [15:0] Accum; 
input [15:0] Pcomp;
input [11:0] Icomp;
input [13:0] Pterm;
input [11:0] Iterm;
input [11:0] Fwd;
input [11:0] A2D_res;
input [11:0] Error;
input [11:0] Intgrl;
input [2:0] src0sel;
input [2:0] src1sel;
input multiply;
input sub;
input mult2;
input mult4;
input saturate;

// Initialize ouput
output [15:0] dst;

// Initialize wires for internal signals
wire [15:0] src1; 	// Source 1 for the adder
wire [15:0] src0; 	// Source 0 for the adder
wire [15:0] pre_src0;	// Initial unmodified source from the input mux
wire [15:0] scaled_src0;// scaled version of pre_src0 based on the mult2 and mult4 signals
wire [15:0] sum;	// Result of the adder
wire [15:0] sat_out;	// Saturated result of the adder
wire signed [14:0] src1_2mul;	// Source 1 for the multiplier
wire signed [14:0] src0_2mul;	// Source 0 for the multiplier
wire signed [29:0] mul_product;// Result of the multiplier
wire [15:0] mul_sat_out;// Saturated result of the multiplier

// Assign src1 based on the src1sel signal
assign src1 = (src1sel == 3'b000) ? Accum : (src1sel == 3'b001) ? {4'b0000,Iterm} : (src1sel == 3'b010) ? {{4{Error[11]}},Error} : (src1sel == 3'b011) ? {{8{Error[11]}},Error[11:4]} : (src1sel == 3'b100) ? {4'b0000,Fwd} : 16'h0000;

// Assign pre_src0 based on the src0sel signal, it will be processed later
assign pre_src0 = (src0sel == 3'b000) ? {4'b0000,A2D_res} : (src0sel == 3'b001) ? {{4{Intgrl[11]}},Intgrl} : (src0sel == 3'b010) ? {{4{Icomp[11]}},Icomp} : (src0sel == 3'b011) ? Pcomp : (src0sel == 3'b100) ? {2'b00,Pterm} : 16'h0000;

// If mult2 or mult4 are enabled, then assign scaled_src0 the scaled version of src0
// If neither are asserted, then just assign it pre_src0
assign scaled_src0 = mult2 ? {pre_src0[14:0], 1'b0} : mult4 ? {pre_src0[13:0], 2'b00} : pre_src0;

// If sub is 1, then invert all the bits of scaled_src0 and assign it src0
assign src0 = sub ? ~scaled_src0 : scaled_src0;

// Add together src0 and src1. If sub is 1 then use it as a carry in to complete 2's compliment subtraction
assign sum = src0 + src1 + sub;

// If saturate is enabled, then compare sum with 07FF and F800 and saturate sum to 12 bits, put this in sat_out
assign sat_out = saturate ? (sum[15] == 1'b0) ? (sum[14:11] != 4'b0000) ? 16'h07FF : sum[15:0] : (sum[14:11] != 4'b1111) ? 16'hF800 : sum[15:0] : sum[15:0];

// Assign src1_2mul and src0_2mul the first 15 bits of src1 and src0, this is used for the 15x15 multiplication
assign src1_2mul = src1[14:0];
assign src0_2mul = src0[14:0];

// Compute the product of src1_2mul and src0_2mul and put it in mul_product
assign mul_product = src1_2mul * src0_2mul;

// Saturate the result of the multiplication to 15 bits
assign mul_sat_out = (mul_product[29]) ? ((&mul_product[28:26]) ? mul_product[27:12] : 16'hC000) : // If negative, saturate to 0xC000 (15-bit maximum, signed extended to 16-bit)
                                       ((|mul_product[28:26]) ? 16'h3FFF : mul_product[27:12]); // If positive, saturate to 0x3FFF (15-bit minimum, signed extended to 16-bit)

// Assign dst to either the result of the multiplication or the addition based on the multiply signal
assign dst = multiply ?  mul_sat_out : sat_out;

endmodule