module motion_control(clk, rst_n, go, start_conv, chnnl, cnv_cmplt, A2D_res,
IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht);

//inputs
input clk, rst_n, go, cnv_cmplt;
input[11:0] A2D_res;

//outputs
output start_conv, IR_in_en, IR_mid_en, IR_out_en;
output reg [2:0] chnnl;
output[7:0] LEDs;
output[10:0] lft, rht;

//Other registers we will need
reg[4:0] timer32 = 0;
reg[11:0] timer4096 = 0;
reg timer32_en = 0, timer4096_en = 0;

reg[15:0] Accum, Pcomp;
reg[11:0] Error, Intgrl, Icomp, lft_reg, rht_reg, Fwd;

alu iALU(Accum, Pcomp, );


//other signals we will need
reg [2:0] src1sel, src0sel;
reg sub, multiply, mult2, mult4, saturate, dst2Accum, 
    dst2Err, dst2Int, dst2Icmp, dst2Pcmp, dst2lft, dst2rht;

reg [2:0] state;
reg [1:0] int_dec; // - keep the integration from running to fast
                   // - only assert to write back to Intgrl when it == 4

localparam idle = 3'b000;
localparam PWM_IR_sel = 3'b001;
localparam A2D_Conv_1 = 3'b010;
localparam Accum_Calc_1 = 3'b011;
localparam A2D_Conv_2 = 3'b100;
localparam Accum_Calc_2 = 3'b101;
localparam PI_Ctrl_PWM = 3'b110;

// state transition logic
always @ (posedge clk or negedge rst_n) begin
  case (state)
  
    idle: 
      if (chnnl != 0) begin
        state <= idle;
      end
  
      else begin
        Accum = 0;
        state = PWM_IR_sel;
      end
        

    /* TODO: Enable PWM to selected IR seensor pair
       Enable timer*/
    PWM_IR_sel:
      if (timer4096_en == 0)
        timer4096_en = 1;
  
    /* TODO: Invoke A2D conversion*/
    A2D_Conv_1:
      if (cnv_cmplt == 1) begin
	state = Accum_Calc_1;
      end else begin
        state = A2D_Conv_1;
      end
   
    /* TODO: Invoke ALU to perform three calculations based on chnnl counter*/
    Accum_Calc_1:
      if (timer32 == 32) begin
        timer32 = 0; 
        state = A2D_Conv_2;
      end else begin
        timer32 = timer32 + 1;
      end

    /* TODO: Invoke A2D conversion*/
    A2D_Conv_2:
      if (cnv_cmplt == 1) begin
	state = Accum_Calc_2;
      end else begin
        state = A2D_Conv_2;
      end 

    Accum_Calc_2:
      if (chnnl == 6) begin
	state = PI_Ctrl_PWM;
      end else begin
	state = PWM_IR_sel;
      end

    PI_Ctrl_PWM:
      state = idle;

  endcase
end
    
// Timer4096 logic
always @ (posedge clk or negedge rst_n) begin
  if (timer4096_en == 1 && timer4096 < 4096)
    timer4096 = timer4096 + 1;
    
  else begin
    timer4096 = 0;
    timer4096_en = 0;
  end
end

/* Logic for Fwd*/
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Fwd <= 12'h000;
  else if (~go) // if go deasserted Fwd knocked down so
    Fwd <= 12'b000; // we accelerate from zero on next start.
  else if (dst2intgrl & ~&Fwd[10:8]) // 43.75% full speed
    Fwd <= Fwd + 1'b1;
end 

/* Determining the value of rht_reg*/
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    lft_reg <= 12'h000;
  else if (!go)
    lft_reg <= 12'h000;
  else if (dst2lft)
    lft_reg <= dst[11:0];
end

/* Determining the value of rht_reg*/
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    rht_reg <= 12'h000;
  else if (!go)
    rht_reg <= 12'h000;
  else if (dst2rht)
    rht_reg <= dst[11:0];
end

endmodule
