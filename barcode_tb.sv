module barcode_tb();

// regular input and output validations for testbench

reg clk,rst_n, clr_ID_vld;				
reg [24:0] period;		
reg send;				
reg [7:0] station_ID;	
wire BC;			
wire BC_done;		
wire ID_vld;
wire [7:0] ID;

//instantiate BC generator, needs 1 pulse of send signal, and station_ID as well as period inputs to start producing BC signal

barcode_mimic BC_generator(clk,rst_n,period,send,station_ID,BC_done, BC);


// instantiate barcode.sv feed BC from BC_generator
barcode iDUT(clk, rst_n, BC, ID_vld, ID, clr_ID_vld);


// clock
always begin
forever #5 clk = ~clk;
end


initial begin 
// set initial values to get rid of red lines and start the process
clk = 1;
rst_n = 0; 
clr_ID_vld = 0;
period = 22'd520; // 520 will be a period for first transmission 
send = 1; // used for PULSE
station_ID = 8'h37; // ID to be passed, expect ID = 8'h37 and ID_vld = 1
#5 rst_n = 1;
repeat(1)
@ (negedge clk);
send = 0; // pulse ends

// wait for long time 
repeat (10000) begin
@ (negedge clk);
end

 	if (ID != 8'h37 || ID_vld == 0)begin
	  $display("ERROR: ID should be 0x37 and ID_vld should be 1");
	  $stop;
	end


station_ID = 8'hc5; // THIS TIME ID IS INVALID!!! EXPECT: ID_vld to be low at the end and ID = 8'h37 still
clr_ID_vld = 1; // clear previous transmission with clr_ID_vld pulse
repeat(10)
@ (negedge clk);

send = 1; // start a SEND PULSE 
repeat(1)
@ (negedge clk);
send = 0;
clr_ID_vld = 0;
period = 22'd1024; // Period is a bit LARGER this time

// wait for some long time
repeat (10000) begin
@ (negedge clk);
end

 	if (ID != 8'h37 || ID_vld != 0)begin
	  $display("ERROR: ID should be 0x37 and ID_vld should be 0");
	  $stop;
	end


// set new values to variables
station_ID = 8'h0f; // THIS TIME ID IS VALID!!! EXPECT: ID_vld to be high at the end and ID = 8'h0f
clr_ID_vld = 1; // clear previous transmission with clr_ID_vld pulse
send = 1; // start a SEND PULSE 
repeat(1)
@ (negedge clk);
send = 0;
clr_ID_vld = 0;
period = 22'd1024; // Period is the samke this time

// wait for some long time
repeat (10000) begin
@ (negedge clk);
end

	if (ID != 8'h0F || ID_vld == 0)begin
	  $display("ERROR: ID should be 0x0f and ID_vld should be 1");
	  $stop;
	end

// set new values to variables ####### NOW DO NOT CLEAR ID WITH CLR_ID_VLD SIGNAL ################

station_ID = 8'h5f; // THIS TIME ID IS INVALID!!! EXPECT: ID_vld to be low at the end and ID to still be 8'h0f

send = 1; // start a SEND PULSE 
repeat(1)
@ (negedge clk);
send = 0;
clr_ID_vld = 0;
period = 25'hFFFFFFF; // Period is the same this time

// wait for some long time
repeat (10000) begin
@ (negedge clk);
end

	if (ID != 8'h0F || ID_vld == 1)begin
	  $display("ERROR: ID should be 0x0f and ID_vld should be 0");
	  $stop;
	end

$display("Passed barcode tb!");
$stop;
end


endmodule
