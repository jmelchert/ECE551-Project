module uart_rcv(clk, rst_n, RX, rx_data, rx_rdy, rx_rdy_clr);

input clk, rst_n;		// Clock and reset signal
input RX, rx_rdy_clr;		// RX and rx_rdy_clear inputs
output reg [7:0] rx_data;	// Recieved data
output reg rx_rdy;		// rx_rdy output

reg [9:0] shift_reg;		// Asserted when we are recieving data
reg shift, start_count, done_recieving; // Global variables for shifting, counting, and recieving
reg [11:0] baud_count;		// 12 bit baud counter
reg [3:0] bit_count;		// 4 bit bit counter

reg RX_sync_0, RX_sync_1;

always @ (posedge clk) begin
        RX_sync_0 <= RX;
        RX_sync_1 <= RX_sync_0;
end


// Shifting block for recieving data, also assigns rx_data at the same time
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		shift_reg <= 10'h000; 	// Reset to 0
		rx_data = 8'h00;
	end else if (shift) begin
		shift_reg <= {RX_sync_1, shift_reg[9:1]}; // Shift in when shift is asserted
		rx_data <= shift_reg[8:1];
	end else begin
		shift_reg <= shift_reg; // Keep shift_reg and rx_data values
		rx_data <= shift_reg[8:1];
	end
end


// Baud counter. Counts up to 2604
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		baud_count <= 12'h000; // Reset to 0
	else if (baud_count == 12'hA2C) 
		baud_count <= 12'h000;
	else if (start_count)
		baud_count <= baud_count + 1; // Increment if start_count is asserted
	else
		baud_count <= 12'h000; // Reset to 0 when nothing is sending
end

// Bit counter, counts up to 10 and then resarts
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		bit_count <= 4'h0;
	else if (bit_count == 4'hA) 
		bit_count <= 4'h0;
	else if (shift)
		bit_count <= bit_count + 1;
	else
		bit_count <= bit_count;
end

// rx_rdy logic, will assert rx_rdy when it is done recieving a byte
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		rx_rdy <= 0;
	else if (rx_rdy_clr)
		rx_rdy <= 0; // Clear when rx_rdy_clr is asserted
	else if (start_count)
		rx_rdy <= 0; // Clear when starting a new byte
	else if (done_recieving) 
		rx_rdy <= 1;
	else
		rx_rdy <= rx_rdy;
end

localparam IDLE = 1'b0;
localparam SHIFTING = 1'b1;
reg state, nxt_state;

// FSM states
always @(posedge clk, negedge rst_n)  begin
	if (!rst_n) 
		state <= IDLE; 
	else
		state <= nxt_state;
end


// Next state logic
always @(*) begin
	
		shift = 0;
		start_count = 1;
		done_recieving = 0;
	
	case (state) 

		IDLE : if (RX_sync_1) begin
			nxt_state = IDLE; // Wait for byte to start
			start_count = 0;
		end else begin
			nxt_state = SHIFTING; // Begin recieving
		end

		SHIFTING : if (bit_count == 4'hA) begin
				nxt_state = IDLE; // Recied an entire byte, done recieving
				start_count = 0;
				done_recieving = 1;
			end else begin
				if (baud_count == 12'h516) begin 
					shift = 1; // Recieve new bit every half a baud count
				end else begin
					nxt_state = SHIFTING; // Otherwise just wait
			end
		end
	endcase
end

endmodule