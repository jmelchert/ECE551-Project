module cmd_control_tb();

reg clk, rst_n; // Clock and reset signals
reg [7:0] cmd, ID; // 8 bit cmd and ID signals
reg cmd_rdy, OK2Move, ID_vld;
wire clr_cmd_rdy, in_transit, go, buzz, buzz_n, clr_ID_vld;

// Instantiate DUT
cmd_control iDUT(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

initial begin
	clk = 0; 
	rst_n  = 0; // Assert reset
	
	// Set all inputs to DUT initially
	cmd_rdy = 0;
	OK2Move = 0;
	ID_vld = 0;
	cmd = 8'h00;
	ID = 8'h0A;
	
	#20;
	rst_n = 1; // Deassert reset
	
	#50;
	cmd_rdy = 1; // cmd_rdy = 1
	cmd = 8'b01000000; // cmd = go
	// Should set in_transit to 1, go to state GO
	// Buzzer should start buzzing when in_transit is 1
	
	#50;
	cmd = 8'h00; // cmd = stop
	// Should clear in_transit and go to state IDLE
	
	#50;
	cmd = 8'b01000000; // cmd = go
	// Should set in_transit to 1, go to state GO
	// Buzzer should start buzzing when in_transit is 1
	
	#50;
	cmd_rdy = 0;
	// Should branch to check ID_vld
	
	#50;
	ID_vld = 1;
	// Should next check if ID = dest_ID
	
	#10;
	ID = 8'h00;
	// Change ID to be equal to dest_ID, should clear in_transit and go to state IDLE
	
	#50;
	$stop;

	// Every path in the command and control flow has been tested
	
end


always begin
	#5 clk = !clk;
end
	

endmodule