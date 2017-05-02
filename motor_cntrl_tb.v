module motor_cntrl_tb();
 
reg [10:0] lft, rht;
reg clk, rst_n;
wire fwd_lft, rev_lft, fwd_rht, rev_rht;

// Instantiate DUT
motor_cntrl iDUT(lft, rht, clk, rst_n, fwd_lft, rev_lft, fwd_rht, rev_rht);

initial begin

  // Reset everything
  clk = 0;
  rst_n = 0;
  lft = 0;
  rht = 0;
  #10;
  rst_n = 1; // Disassert reset
  #10;

  // Reverse case
  lft = 11'b11111000000;
  rht = 11'b11111000000;
  repeat (1300) @(posedge clk);

  // Forward case
  lft = 11'b00001000000;
  rht = 11'b00001000000;
  repeat (1300) @(posedge clk);

  // Full Reverse lft, full forware rht
  lft = 11'b10000000000;
  rht = 11'b01111111111;
  repeat (1300) @(posedge clk);

  // Full Reverse rht, full forware lft
  lft = 11'b01111111111;
  rht = 11'b10000000000;
  repeat (1300) @(posedge clk);


  // Brake case
  lft = 0;
  rht = 0;
  repeat (1300) @(posedge clk);
  $stop;

end

// Clock generation
always
  forever #1 clk = ~clk;

endmodule
