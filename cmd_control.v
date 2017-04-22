module cmd_control(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

input [7:0] cmd;
input cmd_rdy, OK2Move, ID_vld, clk, rst_n;
output reg clr_cmd_rdy, in_transit, go, buzz, clr_ID_vld;
output buzz_n;
input [7:0] ID;
reg in_transit_ff, en;
reg [13:0] buzz_cnt= 0;

parameter INIT_VALUE = 14'b0; 
parameter EXP_VALUE = 14'd12500; // 50MHZ clock divided by 4KHZ signal

always @(posedge clk, negedge rst_n) begin

	if (!rst_n) begin
		in_transit <= 0;
		in_transit_ff <= 0;
	end else 
		in_transit <= in_transit_ff;
		
end

always @(*) begin

	go = in_transit & OK2Move;
	en = (~OK2Move & in_transit);

end


always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    buzz <= 1'b0; 
    buzz_cnt <= INIT_VALUE; // Initial value = 0;
  end
  else begin
    if (en) // Increase when enabled
      buzz_cnt <= buzz_cnt + 1'b1;
    if (buzz_cnt >= EXP_VALUE/2) // 50% duty
        buzz <= 1'b1;
    else
        buzz <= 1'b0;
    end
    if (buzz_cnt == EXP_VALUE) // Prevent Overflow
        buzz_cnt <= INIT_VALUE;
 end


assign buzz_n = (en)? ~buzz : buzz; // Inversion only when enabled to vibrate.



localparam IDLE = 1'b0;
localparam GO = 1'b1;

reg state, nxt_state;

always @(posedge clk, negedge rst_n) begin

	if (!rst_n) 
		state <= IDLE;
	else 
		state <= nxt_state;
		
end

always @(*) begin
	
	clr_ID_vld = 1'b0;
	clr_cmd_rdy = 0;

	case (state) 

		IDLE: if (cmd_rdy && cmd[7:6] == 2'b01) begin
			nxt_state = GO;
			in_transit_ff = 1;
			clr_cmd_rdy = 1;
		end else begin
			nxt_state = IDLE;
		end		
		
		
		GO: if (cmd_rdy & cmd [7:6] == 2'b00) begin
			nxt_state = IDLE;
			in_transit_ff = 0;
			clr_cmd_rdy = 1;
		end else if (cmd_rdy == 0 && ID_vld) begin
			clr_ID_vld = 1;
			if (ID[5:0] == cmd[5:0]) begin
				in_transit_ff = 0;
				nxt_state = IDLE;
			end else begin
				nxt_state = GO;
			end
		end else if (cmd_rdy && cmd[7:6] == 2'b00) begin
			in_transit_ff = 0;
			nxt_state = IDLE;
			clr_cmd_rdy = 1;
		end else begin
			nxt_state = GO;
		end

	endcase
end 

endmodule
