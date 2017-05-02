module motion_cntrl_tb();

//inputs
reg clk, rst_n, go, cnv_cmplt;
reg [11:0] A2D_res;
reg [3:0] loop;

//outputs
wire strt_cnv, IR_in_en, IR_mid_en, IR_out_en;
wire [2:0] chnnl;
wire [7:0] LEDs;
wire [10:0] lft, rht;

// Instantiate DUT
motion_cntrl iDUT (.clk(clk), .rst_n(rst_n), .go(go), .strt_cnv(strt_cnv), .chnnl(chnnl), .cnv_cmplt(cnv_cmplt), .A2D_res(A2D_res),
    .IR_in_en(IR_in_en), .IR_mid_en(IR_mid_en), .IR_out_en(IR_out_en), .LEDs(LEDs), .lft(lft), .rht(rht));


always #5 clk = ~clk;

initial begin

	// Initially reset
    clk = 0;
    go = 1;
    cnv_cmplt = 0;
    rst_n = 0;
    A2D_res = 12'hFFF; // Set static value for A2D_res
    #150;

    rst_n = 1;
    #100;
    //starts by asserting go
    go = 1;
	
	repeat(5000) @(posedge clk); // Wait for timer to be finished
	#5;
	cnv_cmplt = 1; // Should transition to performing Accum caluculations
	
	#20;
	cnv_cmplt = 0;
	
	repeat(200) @(posedge clk); // Wait for 32 bit timer, start conversion after this
	#5;
	cnv_cmplt = 1; // Should perform Accum calculations
	
	#20;
	cnv_cmplt = 0;

	// Repeat this same process until all 6 channels have been read and the PI control math has been done
	// At the end of this loop FWD should be calculated once and should be 1
	for (loop = 0; loop < 12; loop = loop + 1) begin
		repeat(5000) @(posedge clk);
		#5;
		cnv_cmplt = 1;
		
		#20;
		cnv_cmplt = 0;
		
		repeat(200) @(posedge clk);
		#5;
		cnv_cmplt = 1;
		
		#20;
		cnv_cmplt = 0;
	end


	
	// PI math should be computed once, all channels should have been read
	// All ALU registers should still be 0 but FWD should be 1
	
	$stop;

end


endmodule
