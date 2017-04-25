module barcode(clk, rst_n, BC, ID_vld, ID, clr_ID_vld);
	
input BC, clr_ID_vld, clk, rst_n;
output reg ID_vld;
output reg[7:0] ID;
reg[21:0] counter;
reg[21:0] timer;
reg[7:0] ID_inter;
reg [3:0] shift_cnt;
reg shift, shift_rst, cnt_rst, BC_async1, BC_asynch;

// USUAL DEFINITIONS FOR SM, will use 3 states
typedef enum reg [1:0] {IDLE, CAPTURE, TRANSMIT} state_t;
state_t state, nxt_state;

// FF for changing states
always@(posedge clk, negedge rst_n) begin
if(!rst_n)
state <= IDLE;
else
state <= nxt_state;
end


// 22 bit counter for BIT transmission
always@(posedge clk, negedge rst_n) begin

if(!rst_n | cnt_rst | clr_ID_vld) begin //reset entire counter if any of those signals asserted
counter <= 22'd0;
shift <= 0;
end
else begin
	if(counter == timer) begin // TIME TO LOAD THE BIT INTO OUR ID!!!
	   counter <= 22'd0; // reset counter now
 	   shift <= 1; // when counter is ready shift
	end
	 else
	shift <= 0;
	counter <= counter+1; // IF NOT TIME TO LOAD JUST KEEP COUNTING
end
end

//3-bit shift counter, too see how many bits we already shifted into the ID
always@(posedge clk, negedge rst_n) begin
if(!rst_n | clr_ID_vld | shift_rst) // if any asserted reset
shift_cnt <= 0;
else 
  if(shift)
	shift_cnt <= shift_cnt+1; // increment if shift is asserted
  else if(shift_cnt == 4'd9) // shift_cnt never goes higher than 9 :/
	shift_cnt <= 0;
  else 
	shift_cnt <= shift_cnt; // keep the value if nothing is happening yet
end


// Double flop the BC signal
always@ (posedge clk) begin
BC_async1 <= BC; 
BC_asynch <= BC_async1;
end

// HERE ALL THE TRICKY JOB WAS DONE: GENERATE THE ID FROM BC SIGNAL!

always_comb begin

// reset id_vld signal if clear asserted
if(clr_ID_vld | !rst_n) begin
 ID_vld = 0;
 ID = 0;
end

case(state) // SM begins

/* IDLE is IDLE, keeps the values and waits intil BC goes 0. As long as BC == 0 jumps to CAPTURE */

IDLE: begin 
cnt_rst = 0;
shift_rst = 0;
timer = 22'b1111111111111111111111;
if (BC_asynch == 0) begin
ID_vld = 0;
ID_inter = 0;
cnt_rst = 1;
    //timer = 22'b1111111111111111111111;
    nxt_state = CAPTURE;
end else begin
nxt_state = IDLE;	
end
end

/* CAPTURE CAPTURES THE TIME WHEN BC CHANGES FROM 0 TO 1, AND MULTIPLIES IT BY 2, GIVING US PERIOD OF THE TRANSMISSION
	AS SOON AS PERIOD IS CALCULATED JUMPS TO THE TRANSMIT STATE */

CAPTURE: begin
cnt_rst = 0; 
if (BC_asynch == 1) begin
timer = (counter-2)*2; // PERIOD CALCULATION
cnt_rst = 1; 
nxt_state = TRANSMIT;
end
else 
nxt_state = CAPTURE;
end

/* THE MOST IMPORTANT STATE, ASSIGNS ALL BC VALUES TO ID ONCE EVERY PERIOD. AS SOON AS LAST BIT TO BE TRANSMITTED CHECKS IF THE FIRST TWO BITS
  ARE 2'b00, IF NOT THEN ID IS NOT VALID AND ID_VLD SIGNAL STAYS LOW. GOES BACK TO IDLE AS SOON AS ITS DONE.
 */
TRANSMIT: begin
if (shift && (shift_cnt <= 4'd7)) begin // ACTUAL transmitting part
    ID_inter[7-shift_cnt] = BC_asynch; // 	assigning values in proper order
    cnt_rst = 1; 	  // reset counter every time bit is read
    nxt_state = TRANSMIT; // keep in the state of transmit until done
end
else if(shift_cnt == 8) begin // IF hit the end of the transmission

    ID_vld = (ID_inter[7:6] == 2'b00)? 1'b1: 1'b0; // check IF VALID
    ID = (ID_inter[7:6] == 2'b00)? ID_inter : ID;
    cnt_rst = 1;
    shift_rst = 1;
    nxt_state = IDLE; // Go back to IDLE if done;
end 
else begin
    cnt_rst = 0;
    nxt_state = TRANSMIT; // keep SM in transmit state until transmission is done
end
end

endcase


end


endmodule
