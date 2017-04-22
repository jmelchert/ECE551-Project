module motion_cntrl(clk, rst_n, go, start_conv, chnnl, cnv_cmplt, A2D_res,
IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht);

//inputs
input clk, rst_n, go, cnv_cmplt;
input [11:0] A2D_res;

//outputs
output reg start_conv, IR_in_en, IR_mid_en, IR_out_en;
output reg [2:0] chnnl = 0;
output [7:0] LEDs;
output [10:0] lft, rht;

// ALU registers
reg signed [15:0] dst;
reg [15:0] Accum, Pcomp, IR_in_rht, IR_mid_rht, IR_out_rht, IR_in_lft, IR_mid_lft, IR_out_lft;
wire [13:0] Pterm;
wire [11:0] Iterm;
reg signed [11:0] Error, Intgrl, Icomp;
reg [11:0] Fwd;
reg [2:0] src0sel, src1sel;
reg sub, multiply, mult2, mult4, saturate;

// Registers for motion controller model itself
reg [4:0] timer32 = 0;
reg [11:0] timer4096 = 0;
reg timer32_en = 0, timer4096_en = 0;


reg [11:0] lft_reg, rht_reg, res;
reg dst2Accum, dst2Err, dst2Int, dst2Icmp, dst2Pcmp, dst2lft, dst2rht, //other signals we will need
	a2d_SS_n, SCLK, MOSI, MISO;
	
reg [1:0] int_dec; // - keep the integration from running to fast
                   // - only assert to write back to Intgrl when it == 4

wire pwm8_out;

typedef enum reg [3:0] {IDLE, PWM_IR_sel, A2D_Conv_1, Stall_1, Accum_Calc_1, A2D_Conv_2, Stall_2, Accum_Calc_2, PI_Ctrl_PWM} state_t;
state_t state, nxt_state;


alu iALU(.Accum(Accum), .Pcomp(Pcomp), .Pterm(Pterm), .Fwd(Fwd), .A2D_res(A2D_res), .Error(Error), .Intgrl(Intgrl),
         .Icomp(Icomp), .Iterm(Iterm), .src1sel(src1sel), .src0sel(src0sel), .multiply(multiply), 
         .sub(sub), .mult2(mult2), .mult4(mult4), .saturate(saturate), .dst(dst));


//A2D_intf iA2D(.clk(clk), .rst_n(rst_n), .strt_cnv(start_conv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
pwm8 pwm_IR (.duty(8'h8C), .clk(clk), .rst_n(rst_n), .PWM_sig(pwm8_out));


assign Pterm = 14'h3680;
assign Iterm = 12'h500;

/*localparam idle = 3'b000;
localparam PWM_IR_sel = 3'b001;
localparam A2D_Conv_1 = 3'b010;
localparam Accum_Calc_1 = 3'b011;
localparam A2D_Conv_2 = 3'b100;
localparam Accum_Calc_2 = 3'b101;
localparam PI_Ctrl_PWM = 3'b110; */

always @(posedge clk, negedge rst_n) begin 
if(!rst_n)
state <= IDLE;
else
state <= nxt_state;
end


// state transition logic
always @(*) begin
  nxt_state = IDLE;
  case (state)
    IDLE: begin
      if (chnnl == 0 || chnnl > 3'd6) begin
	Accum = 0;
	chnnl = 0;
        timer4096_en = 1;
	IR_in_en = pwm8_out;
        nxt_state = PWM_IR_sel;
      end
	else if (chnnl == 3'd6) begin
	chnnl = 6;
        timer4096_en = 1;
	IR_in_en = pwm8_out;
        nxt_state = PWM_IR_sel;
	end
      else begin
        nxt_state = IDLE;
      end
        
end
    /* TODO: Enable PWM to selected IR seensor pair
       Enable timer*/
    PWM_IR_sel: begin

      if (timer4096_en == 0) begin
        timer4096_en = 1;
	nxt_state = A2D_Conv_1;
	start_conv = 1;
  	end else 
	nxt_state = PWM_IR_sel;
  	
end
    /* TODO: Invoke A2D conversion*/
    A2D_Conv_1: begin
      if (cnv_cmplt == 1) begin
	start_conv = 0;
	nxt_state = Stall_1;
	if (chnnl == 3'b0)
	Accum = dst;
	else if(chnnl == 3'd2)
	Accum = Accum + dst*2;
	else if(chnnl == 3'd4)
	Accum = Accum + dst*4;
	else
	nxt_state = IDLE;
      end else begin
        nxt_state = A2D_Conv_1;
      end
end

	// Additional state for 1 more cycle for multiplication
	Stall_1: begin
 	nxt_state = Accum_Calc_1;
	timer32_en = 1'b1;
	end
   
    /* TODO: Invoke ALU to perform three calculations based on chnnl counter*/
    Accum_Calc_1: begin
      if (timer32_en == 0) begin
	nxt_state = A2D_Conv_2;
	start_conv = 1;
      end else begin
       nxt_state = Accum_Calc_1;
      end
end

    /* TODO: Invoke A2D conversion*/
    A2D_Conv_2: begin
      if (cnv_cmplt == 1) begin
	start_conv = 0;
	nxt_state = Stall_2;
	if (chnnl == 3'b1)
	Accum = Accum - dst;
	else if(chnnl == 3'd3)
	Accum = Accum - dst*2;
	else if(chnnl == 3'd5)
	Error = Accum - dst*4;
	else
	nxt_state = IDLE;
      end else begin
        state = A2D_Conv_2;
      end 
end

	// Additional cycle for multiplication
	Stall_2: begin 
	chnnl = chnnl + 1;
	timer32_en = 0;
	timer4096_en = 0;
	nxt_state = Accum_Calc_2;
	end

    Accum_Calc_2: begin
      if (chnnl == 6) begin
	nxt_state = IDLE;
      end else begin
	nxt_state = PI_Ctrl_PWM;
      end
	end

    PI_Ctrl_PWM:begin
     	nxt_state = IDLE;
	Intgrl = Error>>4 + Intgrl;
	Icomp = Iterm*Intgrl;
	Pcomp = Error*Pterm;
	Accum = Fwd - Pcomp;
	rht_reg = Accum - Icomp;
	Accum = Fwd + Pcomp;
	lft_reg = Accum + Icomp;
	
end // end of PI control

endcase
end
    
// Timer4096 logic
always @ (posedge clk or negedge rst_n) begin
  if (timer4096_en == 1 && timer4096 <= 12'd4095)
    timer4096 = timer4096 + 1;
    
  else begin
    timer4096 = 0;
    timer4096_en = 0;
  end
end

// Timer32 logic
always @ (posedge clk or negedge rst_n) begin
  if (timer32_en == 1 && timer32 <= 5'd31)
    timer32 = timer32 + 1;
    
  else begin
    timer32 = 0;
    timer32_en = 0;
  end
end

/* Logic for Fwd*/
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Fwd <= 12'h000;
  else if (~go) // if go deasserted Fwd knocked down so
    Fwd <= 12'b000; // we accelerate from zero on next start.
  else if (dst2Int & ~&Fwd[10:8]) // 43.75% full speed
    Fwd <= Fwd + 1'b1;
end 

/* Determining the value of rht_reg
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    lft_reg <= 12'h000;
  else if (!go)
    lft_reg <= 12'h000;
  else if (dst2lft)
    lft_reg <= dst[11:0];
end */


/* Determining the value of rht_reg
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    rht_reg <= 12'h000;
  else if (!go)
    rht_reg <= 12'h000;
  else if (dst2rht)
    rht_reg <= dst[11:0];
end */

endmodule
