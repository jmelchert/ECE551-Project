module uart_tx(clk, rst_n, TX, trmt, tx_data, tx_done);

input clk, rst_n;
output TX;
input trmt;
input [7:0] tx_data;
output reg tx_done;

logic [11:0] baud_cnt;
logic [3:0] bit_cnt;
logic [9:0] shift_reg;

reg load, shift, transmitting, set_done, clr_done;

typedef enum reg [1:0] {IDLE, TRANSMITTING} state_t;
state_t state, nxt_state;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) 
    shift_reg <= 10'h3FF; // fill in with bit 1’s because the LSB should should be the stop bit in IDLE state 
  else if (load) 
    shift_reg <= {1'b1,tx_data,1'b0}; // start bit and stop bit are loaded as well as data to TX 
  else if (shift) 
    shift_reg <= {1'b1,shift_reg[9:1]}; // LSB shifted out and idle state shifted in 
end

assign TX = shift_reg[0];

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) 
    baud_cnt <= 12'h000; // reset to 0 on reset 
  else if (load || shift) 
    baud_cnt <= 12'h000; // reset when baud count indicates 19200 baud 
  else if (transmitting) 
    baud_cnt <= baud_cnt+1; // only burn power incrementing if tranmitting
end

assign shift = (baud_cnt == 12'hA2B); // assert shift when baud_cnt reaches 2603 (small cloud in the middle of the diagram)


always @(posedge clk or negedge rst_n) begin
  if (!rst_n) 
    bit_cnt <= 4'b0000; // reset to 0 on reset 
  else if (load) 
    bit_cnt <= 4'b0000; // reset when baud count indicates 19200 baud 
  else if (shift) 
    bit_cnt <= bit_cnt+1; // only burn power incrementing if tranmitting
end

always @(posedge clk, negedge rst_n) begin

	if (!rst_n)
		tx_done  = 0;
	else begin
		if (set_done)
			tx_done = 1;
		else if (clr_done)
			tx_done = 0;
		else 
			tx_done = tx_done;
	end
end

// Alays block for reset and going to next state
always @(posedge clk, negedge rst_n)  begin
	if (!rst_n) 
		state <= IDLE; 
	else
		state <= nxt_state;

end

always_comb begin
	
		load = 0;
		transmitting = 0;
		set_done = 0;
		clr_done = 0;
	
	case (state) 

		IDLE : if (trmt) begin  	 // If in state S1 and a 1 is asserted go to state 2
			nxt_state = TRANSMITTING; // This means 2 consecutive 1s are detected
			load = 1;
			transmitting = 1;
			clr_done = 1;
		end else begin
			nxt_state = IDLE;
		end

		TRANSMITTING : if (bit_cnt[3:0] == 4'b1010) begin	 // If in state S11 and another 1 is detected, then output 1
			nxt_state = IDLE; // This means 3 consecutive 1s are detected
			set_done = 1;
		end else begin
			nxt_state = TRANSMITTING;
			transmitting = 1;
		end
	

	endcase
end

endmodule
