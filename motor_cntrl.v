module motor_cntrl(lft, rht, clk, rst_n, fwd_lft, rev_lft, fwd_rht, rev_rht);
 
 // Inputs
input [10:0] lft, rht;
input clk, rst_n;

// Ouputs
output reg fwd_lft, rev_lft, fwd_rht, rev_rht;

// Magnitudes
reg [9:0] mag_lft, mag_rht;

// Signals from pwm
wire pwm_lft, pwm_rht;

// Left and right PWM instantiation
pwm PWM_lft(.duty(mag_lft), .clk(clk), .rst_n(rst_n), .PWM_sig(pwm_lft));
pwm PWM_rht(.duty(mag_rht), .clk(clk), .rst_n(rst_n), .PWM_sig(pwm_rht));


// getting absolute value of the input (left and right) signals
always @ (*) begin

  // Get the magnitude
  mag_lft = (lft[10] == 1) ? (lft[9:0] == 10'b0) ? (~lft[9:0]) : (~lft[9:0] + 1) : (lft[9:0]);
  mag_rht = (rht[10] == 1) ? (rht[9:0] == 10'b0) ? (~rht[9:0]) : (~rht[9:0] + 1) : (rht[9:0]); 
 

  if ((lft == 0) & (rht == 0)) begin // Full stop
    rev_lft = 1'b1;
    fwd_lft = 1'b1;
    rev_rht = 1'b1;
    fwd_rht = 1'b1;
  end else begin
    if (lft[10] == 1) begin // Reverse left
      rev_lft = pwm_lft;
      fwd_lft = 1'b0;
    end else begin
      fwd_lft = pwm_lft; // Forward left
      rev_lft = 0;
    end 

    if (rht[10] == 1) begin
      rev_rht = pwm_rht; // Reverse Right
      fwd_rht = 1'b0;
    end else begin
      fwd_rht = pwm_rht; // Forward Right
      rev_rht = 0;
    end 
  end


end

endmodule
