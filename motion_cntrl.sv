module motion_cntrl(clk, rst_n, go, strt_cnv, chnnl, cnv_cmplt, A2D_res,
IR_in_en, IR_mid_en, IR_out_en, LEDs, lft, rht);

//inputs
input clk, rst_n, go, cnv_cmplt;
input [11:0] A2D_res;

//outputs
output reg strt_cnv, IR_in_en, IR_mid_en, IR_out_en;
output reg [2:0] chnnl;
output [7:0] LEDs;
output [10:0] lft, rht;

// ALU registers
reg [15:0] dst;
reg [15:0] Accum, Pcomp;
wire [13:0] Pterm;
wire [11:0] Iterm;
reg [11:0] Error, Intgrl, Icomp;
reg [11:0] Fwd;
reg [2:0] src0sel, src1sel;
reg sub, multiply, mult2, mult4, saturate;

// Registers for motion controller model itself
reg [4:0] timer32;
reg [11:0] timer4096;
reg timer32_en, timer4096_en;
reg [2:0] channel;
reg [1:0] int_dec;

reg [11:0] lft_reg, rht_reg;
reg dst2Accum, dst2Err, dst2Int, dst2Icmp, dst2Pcmp, dst2lft, dst2rht, rstAccum, inc_int_dec, inc_channel, en_pwm; //other signals we will need for SM and updating ALU registers

// Output of pwm for IR enables
wire pwm8_out;

// States for SM
typedef enum reg[3:0]{IDLE, PWM_IR_sel, A2D_Conv_1, Stall_1, Accum_Calc_1, A2D_Conv_2, Stall_2, Accum_Calc_2, Int_calc, Icomp_calc, Pcomp_calc, PI_Accum_calc, rht_calc, PI_Accum2_calc, lft_calc} state_t;
state_t state, nxt_state;

// ALU instantiation
alu iALU(.Accum(Accum), .Pcomp(Pcomp), .Pterm(Pterm), .Fwd(Fwd), .A2D_res(A2D_res), .Error(Error), .Intgrl(Intgrl),
         .Icomp(Icomp), .Iterm(Iterm), .src1sel(src1sel), .src0sel(src0sel), .multiply(multiply), 
         .sub(sub), .mult2(mult2), .mult4(mult4), .saturate(saturate), .dst(dst));


// PWM instantiation
pwm8 pwm_IR (.duty(8'h8C), .clk(clk), .rst_n(rst_n), .PWM_sig(pwm8_out));

// Assign Pterm and Iterm constants
assign Pterm = 14'h3680;
assign Iterm = 12'h500;

// Synchronous state assignment
always @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end


// state transition logic
always_comb begin

// Defaults for all SM signals
	nxt_state = IDLE;
	src1sel = 3'b000;
	src0sel = 3'b000;
	multiply = 0;
	mult2 = 0;
	mult4 = 0;
	sub = 0;
	saturate = 0;
	dst2Accum = 0;
	dst2Err = 0;
	dst2Int = 0;
	dst2Icmp = 0;
	dst2Pcmp = 0;
	dst2lft = 0;
	dst2rht = 0;
	rstAccum = 0;
	timer4096_en = 0;
	timer32_en = 0;
	inc_int_dec = 0;
	strt_cnv = 0;
	inc_channel = 0;
	en_pwm = 1;
  
  case (state)
  
	// Reset state 
    IDLE: begin
		if (go) begin
		
			// Set SM signals for starting the timer and resetting the channel
			rstAccum = 1;
			strt_cnv = 0;
			timer4096_en = 1;
			nxt_state = PWM_IR_sel;
		end else begin
			en_pwm = 0;
			nxt_state = IDLE;
		end
	end
    
    PWM_IR_sel: begin

		// Wait for the timer to be done
		if (timer4096 == 12'd4095) begin
			nxt_state = A2D_Conv_1;
			strt_cnv = 1; // Start the A2D conversion
		end else begin
			nxt_state = PWM_IR_sel;
			timer4096_en = 1;
  		end
	end
	
    
	A2D_Conv_1: begin
	
		strt_cnv = 0;
		
		// Wait for conversion to be complete
		if (cnv_cmplt == 1) begin
		
			// Set ALU signals based on channel number
			if(channel == 3'd2) begin
				mult2 = 1;
			end else if(channel == 3'd4) begin
				mult4 = 1;
			end else if(channel == 3'd0) begin
				mult2 = 0;
				mult4 = 0;
			end else begin
				nxt_state = IDLE;
			end
			
			nxt_state = Accum_Calc_1;
			timer32_en = 1'b1; // Start the 32 bit timer
			dst2Accum = 1; // Update Accum
			
		end else begin
			nxt_state = A2D_Conv_1;
		end
	end
   
    // Finished acuum calc, now wait for timer32 to be done
    Accum_Calc_1: begin
		if (channel == 0 || channel == 2 || channel == 4)
			inc_channel = 1; // Increment channel
	
		if (timer32 == 5'd31) begin
			nxt_state = A2D_Conv_2;
			strt_cnv = 1;
		end else begin
		   nxt_state = Accum_Calc_1;
		   timer32_en = 1;
		end
	end

    // Wait for A2D conversion to be done
    A2D_Conv_2: begin
		
		strt_cnv = 0;
		
		if (cnv_cmplt == 1) begin
			
			
			// Set registers for ALU signals to compute Acuum
			sub = 1;
				
			if(channel == 3'd3) begin
				mult2 = 1;
			end else if(channel == 3'd5) begin
				mult4 = 1;
			end else if(channel == 3'd1) begin
				mult2 = 0;
				mult4 = 0;
			end else begin
				nxt_state = IDLE;
			end;
		
			
			nxt_state = Accum_Calc_2;
			
			// Update error or accum based on channel
			if (channel == 5)
				dst2Err = 1;
			else 
				dst2Accum = 1;
			
		end else begin
			nxt_state = A2D_Conv_2;
		end 
	end


	// Branch back to beginning or PI math based on channel
    Accum_Calc_2: begin
		
		if (channel == 5) begin
			nxt_state = Int_calc;
		end else begin
			timer4096_en = 1;
			nxt_state = PWM_IR_sel;
		end

		if (channel == 1 || channel == 3 || channel == 5)
			inc_channel = 1; // increment channel
		else 
			inc_channel = 0;
		
	end

    Int_calc: begin
     	nxt_state = Icomp_calc;
		
	//	dst2Int = Error>>4 + Intgrl;
		saturate = 1;
		src1sel = 3'b011;
		src0sel = 3'b001;
		
		dst2Int = &int_dec;
		inc_int_dec = 1;
	end
	
	Icomp_calc: begin 
		nxt_state = Stall_1;
	
	//	dst2Icmp = Iterm*Intgrl;
		src1sel = 3'b001;
		src0sel = 3'b001;
		multiply = 1;
		saturate = 0;
		
	end
	
	// Additional state for 1 more cycle for multiplication
	Stall_1: begin
		nxt_state = Pcomp_calc;
		src1sel = 3'b001;
		src0sel = 3'b001;
		multiply = 1;
		saturate = 0;
		dst2Icmp = 1;
		
	end
	
	Pcomp_calc: begin 
		nxt_state = Stall_2;
		
	//	dst2Pcmp = Error*Pterm;
		src1sel = 3'b010;
		src0sel = 3'b100;
		multiply = 1;
		saturate = 0;
		
	end
	
	// Additional cycle for multiplication
	Stall_2: begin 
		nxt_state = PI_Accum_calc;
		src1sel = 3'b010;
		src0sel = 3'b100;
		multiply = 1;
		saturate = 0;
		dst2Pcmp= 1;
	end
	
	PI_Accum_calc: begin 
		nxt_state = rht_calc;
		
	//	dst2Accum = Fwd - Pcomp;
		src1sel = 3'b100;
		src0sel = 3'b011;
		multiply = 0;
		saturate = 0;
		sub = 1;
		dst2Accum = 1;
	end
		
	rht_calc: begin
		nxt_state = PI_Accum2_calc;
		
	//	dst2rht = Accum - Icomp;
		src1sel = 3'b000;
		src0sel = 3'b010;
		multiply = 0;
		saturate = 1;
		sub = 1;
		dst2rht = 1;
	end
	
	PI_Accum2_calc: begin 
		nxt_state = lft_calc;
	//	dst2Accum = Fwd + Pcomp;
		src1sel = 3'b100;
		src0sel = 3'b011;
		multiply = 0;
		saturate = 0;
		sub = 0;
		dst2Accum = 1;
	end
	
	lft_calc: begin 
		nxt_state = IDLE;
	//	dst2lft = Accum + Icomp;
		src1sel = 3'b000;
		src0sel = 3'b010;
		multiply = 0;
		saturate = 1;
		sub = 0;
		dst2lft = 1;		
	end
	
	default: 
		nxt_state = IDLE;

	endcase
end
   
// inc_channel logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		channel <= 3'b000;
	else if (inc_channel) 
		if (channel == 5)
			channel <= 0;
		else
			channel <= channel + 1;
	else 
		channel <= channel;
end 

// int_dec logic
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		int_dec <= 2'b00;
	else if (inc_int_dec) 
		int_dec <= int_dec + 1;
	else 
		int_dec <= int_dec;
end 


// Timer4096 logic
always_ff @ (posedge clk or negedge rst_n) begin
  if (!rst_n) begin
	timer4096 <= 0;
  end else if (timer4096_en == 1 && timer4096 != 12'd4095)
    timer4096 <= timer4096 + 1;
  else begin
    timer4096 <= 0;
  end
end

// Timer32 logic
always_ff @ (posedge clk or negedge rst_n) begin
  if (!rst_n) begin
	timer32 <= 0;
  end else if (timer32_en == 1 && timer32 != 5'd31) begin
    timer32 <= timer32 + 1;
  end else begin
    timer32 <= 0;
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
  else 
  	Fwd <= Fwd;
end 

// Logic for chnnl assignment
always_comb begin

	if (channel == 0)
		chnnl = 1;
	else if (channel == 1)
		chnnl = 0;
	else if (channel == 2)
		chnnl = 4;
	else if (channel == 3)
		chnnl = 2;
	else if (channel == 4)
		chnnl = 3;
	else if (channel == 5)
		chnnl = 7;
	else
		chnnl = 0;

end

// Determining the value of Intgrl
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Intgrl <= 12'h000;
  else if (dst2Int)
    Intgrl <= dst[11:0];
  else 
  	Intgrl <= Intgrl;
end 

// Determining the value of Icomp
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Icomp <= 12'h000;
  else if (dst2Icmp)
    Icomp <= dst[11:0];
  else
  	Icomp <= Icomp;
end 

// Determining the value of Pcomp
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Pcomp <= 12'h000;
  else if (dst2Pcmp)
    Pcomp <= dst[11:0];
  else
  	Pcomp <= Pcomp;
end 

// Determining the value of Error
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Error <= 12'h000;
  else if (dst2Err)
    Error <= dst[11:0];
  else 
  	Error <= Error;
end 

assign LEDs = Error[11:4];

// Determining the value of Accum
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    Accum <= 16'h000;
  else if (rstAccum)
	Accum <= 16'h000;
  else if (dst2Accum)
    Accum <= dst[15:0];
  else 
  	Accum <= Accum;
end 

// Determining the value of rht_reg
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    lft_reg <= 12'h000;
  else if (!go)
    lft_reg <= 12'h000;
  else if (dst2lft)
    lft_reg <= dst[11:0];
  else
  	lft_reg <= lft_reg;
end 


// Determining the value of rht_reg
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    rht_reg <= 12'h000;
  else if (!go)
    rht_reg <= 12'h000;
  else if (dst2rht)
    rht_reg <= dst[11:0];
  else
  	rht_reg <= rht_reg;
end 

// Assign lft and rht outputs
assign lft = lft_reg[11:1];
assign rht = rht_reg[11:1];

// Assign IR enable signals to pwm signal
always_comb begin

	if (en_pwm) begin
		if (channel == 0 || channel == 1) begin
			IR_in_en = pwm8_out;
			IR_mid_en = 0;
			IR_out_en = 0;
		end else if (channel == 2 || channel == 3) begin
			IR_in_en = 0;
			IR_mid_en = pwm8_out;
			IR_out_en = 0;
		end else if (channel == 4 || channel == 5) begin
			IR_in_en = 0;
			IR_mid_en = 0;
			IR_out_en = pwm8_out;
		end else begin
			IR_in_en = 0;
			IR_mid_en = 0;
			IR_out_en = 0;
		end
	end else begin
		IR_in_en = 0;
		IR_mid_en = 0;
		IR_out_en = 0;
	end

end

endmodule
