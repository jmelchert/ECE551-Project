module cmd_cntrl(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

input [7:0] cmd; // 8 Bit input command
input [7:0] ID; // ID 8 bit input
input cmd_rdy, OK2Move, ID_vld, clk, rst_n; // Inputs for clk, rst, and ready signals
output reg clr_cmd_rdy, in_transit, go, buzz, clr_ID_vld; // Ouputs
output buzz_n;

// Registers for internal signals
reg en, rst_in_transit, set_in_transit;

// Variables for the buzzer pwm signal
reg [13:0] buzz_cnt; 
parameter INIT_VALUE = 14'b0; 
parameter EXP_VALUE = 14'd12500; // 50MHZ clock divided by 4KHZ signal


// Flopping the in_transit signal
always @(posedge clk, negedge rst_n) begin

	if (!rst_n) begin
		in_transit <= 0;
	end else if (rst_in_transit) begin
		in_transit <= 0;
	end else if (set_in_transit) begin
		in_transit <= 1;
	end else
		in_transit <= in_transit;
		
end

// Combinational logic for the go and buzzer signal
always @(*) begin

	go = in_transit & OK2Move;
	en = (~OK2Move & in_transit);

end

// Buzzer pwm logic
always @(posedge clk, negedge rst_n) begin

	if (!rst_n) begin
 	   buzz <= 1'b0; 
	   buzz_cnt <= INIT_VALUE; // Initial value = 0;
 	end else begin
	    if (en) begin // Increase when enabled
			buzz_cnt <= buzz_cnt + 1'b1;
		end
		if (buzz_cnt >= EXP_VALUE/2) begin // 50% duty
	        buzz <= 1'b1;
	    end else begin
			buzz <= 1'b0;
		end
   		if (buzz_cnt == EXP_VALUE) begin // Prevent Overflow
	        buzz_cnt <= INIT_VALUE;
		end
	end
end

// Assign bzz_n to the inverse of buzz
assign buzz_n = (en)? ~buzz : buzz; // Inversion only when enabled to vibrate.


// State machine states
localparam IDLE = 1'b0;
localparam GO = 1'b1;

reg state, nxt_state;

// Synchronous state logic
always @(posedge clk, negedge rst_n) begin

	if (!rst_n) 
		state <= IDLE;
	else 
		state <= nxt_state;
		
end

// nxt_state logic
always @(*) begin
	
	// Default output values
	clr_ID_vld = 0;
	clr_cmd_rdy = 0;
	set_in_transit = 0;
	rst_in_transit = 0;

	case (state) 

		IDLE: if (cmd_rdy && cmd[7:6] == 2'b01) begin
			nxt_state = GO; // if cmd = go, set GO to nxt_state 
			set_in_transit = 1; // Set in_transit
			clr_cmd_rdy = 1;
		end else begin
			nxt_state = IDLE;
		end		
		
		
		GO: if (cmd_rdy & cmd [7:6] == 2'b00) begin
				nxt_state = IDLE;  // If cmd_rdy = 1 and cmd = stop loop back to beginning and clear in_transit
				rst_in_transit = 1;
				clr_cmd_rdy = 1;
			end else if (cmd_rdy == 0 && ID_vld) begin
				clr_ID_vld = 1; // Set clr_ID_cld to 1
				if (ID[5:0] == cmd[5:0]) begin // Now check ID
					rst_in_transit = 1;
					nxt_state = IDLE;
				end else begin
					nxt_state = GO;
				end
			end else if (cmd_rdy) begin
				clr_cmd_rdy = 1;
				nxt_state = GO;
			end else begin
				nxt_state = GO;
			end

		default: 
			nxt_state = IDLE;
	endcase
end 

endmodule
