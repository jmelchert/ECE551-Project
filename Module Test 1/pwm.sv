module pwm(duty, clk, rst_n, PWM_sig);

input [9:0] duty;
input clk, rst_n;
output reg PWM_sig;
reg [9:0] cnt;
wire set, reset;

always @(posedge clk or negedge rst_n) begin
  
  if (rst_n == 0) begin
    PWM_sig <= 0; 
    cnt <= 0;
  end else begin
    cnt <= cnt + 1;
    if (set == 1) 
      PWM_sig <= 1;
    else if (reset == 1)
      PWM_sig <= 0;
    else 
      PWM_sig <= PWM_sig;
  end
end

assign set = &cnt;
assign reset = (cnt == duty)? 1:0;

endmodule
