module uart_rcv_tb();

reg clk;		// Clock
reg rst_n;		// Active low reset
reg RX;			// Rx input, this is coming from the trasnmitter
reg rx_rdy_clr;		// Reset rx_rdy

wire [7:0] rx_data;	// Data recieved
wire rx_rdy;		// Ready to recieve another byte

// Instantiate the DUT
uart_rcv iDUT(clk, rst_n, RX, rx_data, rx_rdy, rx_rdy_clr);



initial begin
	
	clk = 0; // Set initial clock
	rst_n = 0; // Reset the pwm signal
	rx_rdy_clr = 0;
	RX = 1;
	#50
	rst_n = 1;
	
	RX = 0; // Start UART transfer, send data 0x4D
	#26040;
	RX = 1;
	#26040;
	RX = 0;
	#26040;
	RX = 1;
	#26040;
	RX = 1;
	#26040;
	RX = 0;
	#26040;
	RX = 0;
	#26040;
	RX = 1;
	#26040;
	RX = 0;
	#26040;
	RX = 1; // Stop bit, rx_data should be 0x4D, rx_rdy should go high 
	#20000;

 	if (rx_data != 8'h4D)begin
	  $display("ERROR: rx_data should be 0x4D");
	  $stop;
	end

	#20000;
	RX = 0; // Start second UART transfer, send data 0x0F
	#26040;
	RX = 1;
	#26040;
	RX = 1;
	#26040;
	RX = 1;
	#26040;
	RX = 1;
	#26040;
	RX = 0;
	#26040;
	RX = 0;
	#26040;
	RX = 0;
	#26040;
	RX = 0;
	#26040;
	RX = 1; // Stop bit, rx_data should be 0x0F, rx_rdy should go high 
	#40000;
	rx_rdy_clr = 1; // Clear rx_rdy, rx_rdy should go low
	#25000;

	if (rx_data != 8'h0F)begin
	  $display("ERROR: rx_data should be 0x0F");
	  $stop;
	end

	$display("UART_tb passed!");
	$stop;
	
end

// Clock with period of 10
always begin
  #5 clk = !clk;
end

endmodule
