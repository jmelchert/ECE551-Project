module barcode(clk, rst_n, BC, ID_vld, ID, clr_ID_vld);
	
input BC, clr_ID_vld, clk, rst_n; 
output reg ID_vld;
output reg[7:0] ID;
reg[21:0] counter;
reg[21:0] timer;
reg[7:0] ID_inter;
reg [3:0] shift_cnt;
reg shift, shift_rst, cnt_rst, BC_async1, BC_asynch, update_ID, update_timer, update_ID_inter, inc_shift_cnt;

// USUAL DEFINITIONS FOR SM, will use 3 states
typedef enum reg [2:0] {IDLE, CAPTURE, TRANSMIT, WAIT_LOW, WAIT_HIGH} state_t;
state_t state, nxt_state;




// 22 bit counter for BIT transmission
always@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		counter <= 22'd0;
		shift <= 0;
	end else if (cnt_rst) begin //reset entire counter if any of those signals asserted
		counter <= 22'd0;
		shift <= 0;
	end	else begin
		if(counter == timer) begin // TIME TO LOAD THE BIT INTO OUR ID!!!
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
		shift_cnt <= shift_cnt+1; // increment if shift is asserted
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
		ID_vld <= 0;
	end else if (update_ID) begin
  		if (ID_inter[7:6] == 2'b00) begin // check IF VALID
			ID_vld <= 1; 
			ID <= ID_inter;
		end else begin
			ID_vld <= 0;
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
		timer <= 22'b1111111111111111111111;
	else if (update_timer) 
		timer <= counter; // PERIOD CALCULATION
	else
		timer <= timer;
end

// ID_inter register
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		ID_inter <= 0;
	else if (update_ID_inter) 
		ID_inter[7-shift_cnt] <= BC_asynch;
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


// HERE ALL THE TRICKY JOB WAS DONE: GENERATE THE ID FROM BC SIGNAL!

always_comb begin

	update_ID = 0;
	update_timer = 0;
	nxt_state = IDLE;
	cnt_rst = 1;
	shift_rst = 0;
	update_ID_inter = 0; 
	inc_shift_cnt = 0;

	case(state) // SM begins

/* IDLE is IDLE, keeps the values and waits intil BC goes 0. As long as BC == 0 jumps to CAPTURE */

	IDLE: begin 

		if (BC_asynch == 0) begin
    		nxt_state = CAPTURE;
		end else begin
			nxt_state = IDLE;	
		end
	end

/* CAPTURE CAPTURES THE TIME WHEN BC CHANGES FROM 0 TO 1, AND MULTIPLIES IT BY 2, GIVING US PERIOD OF THE TRANSMISSION
	AS SOON AS PERIOD IS CALCULATED JUMPS TO THE TRANSMIT STATE */

	CAPTURE: begin
		if (BC_asynch == 1) begin
			update_timer = 1;
			nxt_state = WAIT_HIGH;
		end else begin
			nxt_state = CAPTURE;
			cnt_rst = 0;
		end
	end

/* THE MOST IMPORTANT STATE, ASSIGNS ALL BC VALUES TO ID ONCE EVERY PERIOD. AS SOON AS LAST BIT TO BE TRANSMITTED CHECKS IF THE FIRST TWO BITS
  ARE 2'b00, IF NOT THEN ID IS NOT VALID AND ID_VLD SIGNAL STAYS LOW. GOES BACK TO IDLE AS SOON AS ITS DONE.
 */
	TRANSMIT: begin
		if (shift) begin // ACTUAL transmitting part
 			
			if (shift_cnt < 4'd7)begin
	 			update_ID_inter = 1; 
	 			inc_shift_cnt = 1;
	 			if (BC_asynch == 0)
	 				nxt_state = WAIT_LOW;
	 			else
	 				nxt_state = WAIT_HIGH;
 			end else begin
 				inc_shift_cnt = 1;
	  			update_ID_inter = 1;
	   			nxt_state = WAIT_LOW; // Go to WAIT if done;
   			end
		end else begin
    		nxt_state = TRANSMIT; // keep SM in transmit state until transmission is done
    		cnt_rst = 0;
		end
	end

	WAIT_LOW: begin
		if (BC_asynch == 1) begin
			if (shift_cnt == 4'd8) begin
				shift_rst = 1;
				update_ID = 1;
				nxt_state = IDLE;
			end else 
				nxt_state = WAIT_HIGH;
		end else 
			nxt_state = WAIT_LOW;
	end

	WAIT_HIGH: begin
		if (BC_asynch == 0) begin
			nxt_state = TRANSMIT;
		end else 
			nxt_state = WAIT_HIGH;
	end

	
	endcase
end


endmodule
