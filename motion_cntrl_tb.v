module motion_cntrl_tb();

//inputs
reg clk, rst_n, go, cnv_cmplt;
reg [11:0] A2D_res;

//outputs
wire start_conv, IR_in_en, IR_mid_en, IR_out_en;
wire [2:0] chnnl;
wire [7:0] LEDs;
wire [10:0] lft, rht;


motion_cntrl DUT (.clk(clk), .rst_n(rst_n), .go(go), .start_conv(start_conv), .chnnl(chnnl), .cnv_cmplt(cnv_cmplt), .A2D_res(A2D_res),
    .IR_in_en(IR_in_en), .IR_mid_en(IR_mid_en), .IR_out_en(IR_out_en), .LEDs(LEDs), .lft(lft), .rht(rht));


always #50 clk = ~clk;

initial begin
    clk = 0;
    go = 0;
    cnv_cmplt = 0;
    rst_n = 0;
    A2d_res = 354;
    #150;
    rst_n = 1;
    #100;
    //starts by asserting go
    go = 1;

    #100;
    cnv_cmplt = 1;

    #100;

    // test with different input for consistency
    go = 0;
     cnv_cmplt = 0;
    rst_n = 0;
    A2d_res = 712;
     #150;
                               




end


endmodule
