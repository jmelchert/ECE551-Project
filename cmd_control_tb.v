module cmd_control_tb();

reg clk, rst_n;
reg [7:0] cmd, ID;
reg cmd_rdy, OK2Move, ID_vld;
wire clr_cmd_rdy, in_transit, go, buzz, buzz_n, clr_ID_vld;


cmd_control iDUT(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

initial begin
	clk = 0; 
	rst_n  = 0; // Assert reset
	cmd_rdy = 0;
	OK2Move = 0;
	ID_vld = 0;
	cmd = 8'h00;
	ID = 8'h00;
	
	#20;
	rst_n = 1; // Deassert reset
	
	#20;
	cmd_rdy = 1;
	cmd = 8'b01000000;
	#20;
	cmd = 8'h00;
	
	

end


always begin
	#5 clk = !clk;
end
	

endmodule