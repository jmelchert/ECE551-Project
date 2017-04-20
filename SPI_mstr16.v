module SPI_mstr(clk,rst_n,MISO, wrt, cmd, rd_data, SS_n, SCLK, MOSI, done);


input clk,rst_n;		// clock and active low asynch reset
input MISO;			// serial data in
input wrt;			// Write signal
input [15:0] cmd;		// Signal to output
output reg [15:0] rd_data;	// Signal input

output reg SS_n;		
output SCLK;			// Serial clock
output  MOSI;			// serial data out 
output reg done;

reg [4:0] count;		// Counter for the serial clock
reg [4:0] bit_count;		// Counter for bit number
reg shift_rx, shift_tx;		// Shift read and write signals
reg initialize;
reg [15:0] shift_reg_tx;	// Shift register for output

// Counter for serial clock
always @(posedge clk) begin
	if (SS_n) begin
		count = 5'b10000;
		bit_count = 5'b00000;
	end else if (count == 5'b11111) begin
		// This is for the little back shelf 
		if (bit_count[4]) begin
			count = 5'b10000;
		end else begin
			count = 5'b00000;
		end
		// Increase bit count 
		bit_count = bit_count + 1;
	end else
		count = count + 1;
end

// Assign serial clock to the fifth bit of count
assign SCLK = count[4];

// Shift register for reading data
always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		rd_data <= 16'h0000;
	else if (shift_rx) begin
		rd_data <= {rd_data[14:0], MISO};
	end
end

// Shift register for outputing data
always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		shift_reg_tx <= 16'h0000;
	else if (initialize)
		shift_reg_tx = cmd; // initialize the data top be transmitted
	else if (shift_tx) begin
		shift_reg_tx <= {shift_reg_tx[14:0], 1'b0};
	end
end

// Assign MOSI bit based on the shift write register
assign MOSI = (SS_n) ? 1'bz : shift_reg_tx[15];

// States for the state machine
reg [1:0] state,nstate;
localparam IDLE = 2'b00; 
localparam SHIFTING = 2'b01; 
localparam WAIT = 2'b10;
localparam FINISH = 2'b11;

// Next state assignment
always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= nstate;
end


// Next state and output logic
always @(*) begin

	// defaults
	shift_rx = 0;
	shift_tx = 0;
	SS_n = 1;
	done = 0;
	nstate = IDLE;	  
	initialize = 0;

	case (state)
		IDLE : begin
			if (wrt) begin
				// Begin the transmission process
				nstate = WAIT;
				SS_n = 0;
				initialize = 1;
			end 
		end

		SHIFTING : begin	

			if (SCLK) begin
				// assert shift_rx to shift read reg
				shift_rx = 1;
				nstate = WAIT; 
				SS_n = 0;
			end else begin
				// Stay in this loop until SCLK goes high
				nstate = SHIFTING;
				SS_n = 0;
			end 			
		end

		WAIT : begin		
			if (bit_count == 5'b10001) begin
				// Go to finish if all bits have been processed
				nstate = FINISH;
				SS_n = 0;
				shift_tx = 1;
			end else if (!SCLK) begin
				shift_rx = 0;
				// Need to assert shift_tx at the beginning
				if (!(bit_count == 5'b00001))					
					shift_tx = 1;
				nstate = SHIFTING;
				SS_n = 0;
			end else begin
				// Wait until SCLK goes low again
				nstate = WAIT;
				SS_n = 0;
			end 
		end

		FINISH : begin		
			if (count == 5'h1F) begin
				// Finished transmitting
				SS_n = 1;
				nstate = IDLE;
				done = 1;
			end else begin
				// Wait until the SCLK clock cycle has finished
				nstate = FINISH;
				SS_n = 0;
			end 
		end

	endcase
end

endmodule  

