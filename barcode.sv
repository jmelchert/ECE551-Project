module barcode(clk, rst_n, BC, ID_vld, ID, clr_ID_vld);
	
input BC, clr_ID_vld, clk, rst_n; 
output reg ID_vld;
output reg[7:0] ID; // Output ID
reg[21:0] counter; // 22 bit counter for timing
reg[21:0] timer;   // Timer value for period calculation
reg[7:0] ID_inter; // ID value used in shifting
reg [3:0] shift_cnt; // number of bits shifted

// State machine signals for controlling registers
reg shift, shift_rst, cnt_rst, BC_async1, BC_asynch, update_ID, update_timer, update_ID_inter, inc_shift_cnt;

// USUAL DEFINITIONS FOR SM, will use 3 states
typedef enum reg [2:0] {IDLE, CAPTURE, TRANSMIT, WAIT_LOW, WAIT_HIGH} state_t;
state_t state, nxt_state;


// 22 bit counter for BIT transmission
always@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin  //reset entire counter
		counter <= 22'd0;
		shift <= 0;
	end else if (cnt_rst) begin //reset entire counter if cnt_rst signal asserted
		counter <= 22'd0;
		shift <= 0;
	end	else begin
		if(counter == timer) begin 
		   counter <= 22'd0; // reset counter now
 		   shift <= 1; // when counter is ready shift
		end else begin
			shift <= 0;
			counter <= counter+1; // IF NOT TIME TO LOAD JUST KEEP COUNTING
		end
	end
end

//3-bit shift counter, too see how many bits we already shifted into the ID
always@(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		shift_cnt <= 0;
	else if (clr_ID_vld || shift_rst) // if any asserted reset
		shift_cnt <= 0;
	else if(inc_shift_cnt)
		shift_cnt <= shift_cnt + 1; // increment if shift is asserted
	else 
		shift_cnt <= shift_cnt; // keep the value if nothing is happening yet
end


// Double flop the BC signal
always@ (posedge clk) begin
	BC_async1 <= BC; 
	BC_asynch <= BC_async1;
end

// ID Logic
always@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		ID <= 0;
		ID_vld <= 0;
	end else if (clr_ID_vld) begin
		ID_vld <= 0; // Rest ID_vld
	end else if (update_ID) begin
  		if (ID_inter[7:6] == 2'b00) begin // check IF VALID
			ID_vld <= 1; 
			ID <= ID_inter; // Update ID with ID_inter value
		end else begin
			ID_vld <= 0; // ID not valid, just keep ID what it was
			ID <= ID;
		end
	end else begin
		ID <= ID;
		ID_vld <= ID_vld;
	end
end

// Timer register
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		timer <= 22'b1111111111111111111111; // Reset to max value 
	else if (clr_ID_vld)
		timer <= 22'b1111111111111111111111; // Reset to max value
	else if (update_timer) 
		timer <= counter; // Calculate period
	else
		timer <= timer;
end

// ID_inter register
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		ID_inter <= 0;
	else if (update_ID_inter) 
		ID_inter[7-shift_cnt] <= BC_asynch; // Shift in the BC signal, this will become ID after all bits have been recieved
	else
		ID_inter <= ID_inter;
end

// FF for changing states
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end


// Next state and signal logic

always_comb begin

	// Set default values for all signals
	update_ID = 0;
	update_timer = 0;
	nxt_state = IDLE;
	cnt_rst = 1;
	shift_rst = 0;
	update_ID_inter = 0; 
	inc_shift_cnt = 0;

	case(state) // SM begins

/* IDLE is IDLE, keeps the values and waits intil BC goes 0. When BC == 0 jumps to CAPTURE */

	IDLE: begin 

		if (BC_asynch == 0) begin
    		nxt_state = CAPTURE;
		end else begin
			nxt_state = IDLE;	
		end
	end

/* CAPTURE CAPTURES THE TIME WHEN BC CHANGES FROM 0 TO 1, GIVING US PERIOD OF THE TRANSMISSION */

	CAPTURE: begin
		if (BC_asynch == 1) begin
			update_timer = 1;
			nxt_state = WAIT_HIGH;
		end else begin
			nxt_state = CAPTURE;
			cnt_rst = 0; // Keep counter running until we have a timer value
		end
	end

/* Assigns and updated ID_inter if the timer interrupts. This samples the BC signal at the correct time. After all 
	bits have been recieved then we are done */

	TRANSMIT: begin
		if (shift) begin // Sample BC at this time
 			
			if (shift_cnt < 4'd7) begin // If we are not done yet
	 			update_ID_inter = 1; 
	 			inc_shift_cnt = 1;
	 			if (BC_asynch == 0)		// Either have to wait for a high signal or low signal based on BC
	 				nxt_state = WAIT_LOW;
	 			else
	 				nxt_state = WAIT_HIGH;
 			end else begin
 				inc_shift_cnt = 1; // Done!, Shift one last time
	  			update_ID_inter = 1;
	   			nxt_state = WAIT_LOW; // Wait for a high signal to occur
   			end
		end else begin
    		nxt_state = TRANSMIT; // keep SM in transmit state until transmission is done
    		cnt_rst = 0;
		end
	end

// Waits for a high signal to proceed

	WAIT_LOW: begin
		if (BC_asynch == 1) begin
			if (shift_cnt == 4'd8) begin // If we have shifted all the bits
				shift_rst = 1;
				update_ID = 1; // Update ID and we are done!
				nxt_state = IDLE;
			end else 
				nxt_state = WAIT_HIGH;
		end else 
			nxt_state = WAIT_LOW;
	end

// Waits for a low signal to proceed back to transit
	WAIT_HIGH: begin
		if (BC_asynch == 0) begin
			nxt_state = TRANSMIT;
		end else 
			nxt_state = WAIT_HIGH;
	end

	default : 
		nxt_state = IDLE;
	
	endcase
end

endmodule
