module pwm8(duty, clk, rst_n, PWM_sig);

input [7:0] duty;	// Input 10 bit duty cycle
input clk, rst_n; 	// Input clock and reset
output reg PWM_sig;	// Output pwm signal
reg [7:0] cnt;		// 10 bit register for the counter
wire set, reset;	// Set and reset signals


// Always block for updating cnt and having an asynchronous reset
always @(posedge clk, negedge rst_n)  begin
	if (!rst_n) begin
		cnt <= 0; 
	end else begin
		cnt <= cnt + 1;
	end
end

// Assign reset equal to 1 if cnt is equal to duty
assign reset = (cnt == duty) ? 1 : 0;

// Assign set equal to 1 if count is equal to 0x3FF
assign set = (cnt == 8'hFF) ? 1 : 0;

// Set pwm signal equal to 1 if set is 1, set pwm to 0 if reset is 1
always @(posedge clk, negedge rst_n) begin

	if (!rst_n) begin
		PWM_sig <= 1;
	end else if (reset == 1) begin
		PWM_sig <= 0;
	end else if (set == 1) begin
		PWM_sig <= 1;
	end
	
end

endmodule