module A2D_intf_tb();

 reg clk, rst_n, strt_cnv; // Inputs 
 wire a2d_SS_n, SCLK, MOSI, cnv_cmplt; // Outputs
 reg [2:0] chnnl; // Channel for choosng inputs
 wire [11:0] res; // Result
 wire MISO;

// initiate interface and ADC simulator
A2D_intf iDUT(.clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv),  .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));

ADC128S  ADC128S_0(.clk(clk), .rst_n(rst_n), .SS_n(a2d_SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));

initial begin
	clk = 0;
	rst_n = 0;
	chnnl = 3'b011; // Reset and set channel to 3
	strt_cnv = 0;
	#100;
	rst_n = 1;
	strt_cnv = 1; // Start conversion
 	#10;
	strt_cnv = 0; 
	// Allow time for the second transaction to occur
	#5600;
	// At this time the slave should have recieved the channel number we sent and should be sending back the result
	#50;
	strt_cnv = 1; // start conversion
	#10;
	strt_cnv = 0; // Output should be 16'hf18, the inverse of 16'h00E7
	#5600
	
	rst_n = 0; // Have to reset because ptr signal in the ADC slave will count up but there is no information in analog.dat at that location
	chnnl = 3'b001;
	#20;
	rst_n = 1;
	#100;
	strt_cnv = 1; // Start conversion
 	#10;
	strt_cnv = 0; 
	// Allow time for the second transaction to occur
	#5600;
	// At this time the slave should have recieved the channel number we sent and should be sending back the result
	#50;
	strt_cnv = 1; // start conversion
	#10;
	strt_cnv = 0; // Output should be 16'hffa, the inverse of 16'h0005
	#5600
	$stop;
end

always begin
  #5 clk = !clk;
end

endmodule

