module follower(clk,RST_n,next_ch,led,a2d_SS_n,SCLK,MISO,MOSI,rev_rht,
                rev_lft,fwd_rht,fwd_lft,IR_in_en,IR_mid_en,IR_out_en,
				in_transit,OK2Move,buzz,buzz_n,BC,TX,RX);

				
  input clk,RST_n;			// 50MHz clock and asynch active low reset (unsynched)
  input MISO;				// SPI input (from ADC)
  input BC;					// serial barcode data input
  input OK2Move;			// from proximity sensor,  when high we can move
  input RX;					// UART input
  input next_ch;
  output TX;				// UART ouput
  
  output reg [7:0] led;				// active high LEDs
  output a2d_SS_n,SCLK,MOSI;	// SPI signal outputs
  output rev_rht,fwd_rht;		// right motor PWM signals
  output rev_lft,fwd_lft;		// left motor PWM signals
  output IR_in_en,IR_mid_en,IR_out_en;	// Enables to IR sensors (PWM controlled)
  output buzz,buzz_n;			// Piezo buzzer drive (true & compliment)
  output in_transit;			// acts as enable to proximity sensor
  
  wire [10:0] lft, rht;			// signed 11-bit motor drive magnitudes
  wire [7:0] cmd;				// command from BLE112 to dig_core
  wire [7:0] ID;				// station ID from Barcode unit
  wire [7:0] dbg_data;			// debug data to send
  wire [11:0] A2D_res;			// result from A2D conversion
  reg [2:0] chnnl;				// A2D channel to convert
  wire cmd_rdy, clr_ID_vld, ID_vld;
  reg clr_cmd_rdy;
  wire dbg_tx, dbg_done;
  wire cnv_cmplt;
  reg strt_cnv;
  wire go;
  
  reg rst_ff_n,rst_n;
  reg OK2Move_ff1,OK2Move_ff2;
  
  //  UART TXs
  wire TX;
  reg strt_tx;
  wire [7:0] tx_data;
  wire tx_done;
  
  //////////////////////////////////////////////////////
  // Sync deassertion of rst_n with negedge of clock //
  ////////////////////////////////////////////////////
  always @(negedge clk, negedge RST_n)
    if (!RST_n)
	  begin
	    rst_ff_n <= 1'b0;
	    rst_n <= 1'b0;
	  end
	else
	  begin
	    rst_ff_n <= 1'b1;
		rst_n <= rst_ff_n;
	  end

  /////////////////////////////////
  //  Instantiate A2D Interface //
  ///////////////////////////////		
  A2D_intf iA2D(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),.cnv_cmplt(cnv_cmplt),.chnnl(chnnl),
                .res(A2D_res),.a2d_SS_n(a2d_SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));
					 
	reg next_ch_FF1, next_ch_FF2;
	
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			next_ch_FF1 <= 0;
			next_ch_FF2 <= 0;
		end else begin
			next_ch_FF1 <= next_ch;
			next_ch_FF2 <= next_ch_FF1;
		end
	end
				
	wire adv_chnnl;
	
	assign adv_chnnl = !next_ch_FF1 & next_ch_FF2;	
	
	reg [2:0] chnnl_cnt;		// channel counter for IR sensor measurements
		 
	always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		chnnl_cnt <= 3'b000;
	else begin 
	 if (adv_chnnl)
		if (chnnl_cnt == 3'b101)
			chnnl_cnt <= 3'b000;
		else
			chnnl_cnt <= chnnl_cnt + 1'b1;  
    end
	end

			
  ////////////////////////////////////////
  // Implement a general purpose timer //
  //////////////////////////////////////
  reg [11:0] tmr;			// general purpose timer
  reg clr_tmr;
  
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n)
	   tmr <= 12'h000;
	 else begin
      if (clr_tmr)
	     tmr <= 12'h000;
	   else
	     tmr <= tmr + 1'b1;
    end	  
  end	
		
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			led <= 0;
		end else begin
			if ( cnv_cmplt) begin
				led <= A2D_res[11:4];
			end
		end
	end
	
	reg [1:0] state, nstate;
	
	always @(*) begin
		strt_cnv = 0;
		nstate = 2'b00;
		clr_tmr = 1;
		case (state)
			2'b00: begin // WRITE
				strt_cnv = 1;
				nstate = 2'b01;
			end	
			2'b01: begin // WAIT
				if (cnv_cmplt)
					nstate = 2'b00;
				else 
					nstate = 2'b01;
			end
			2'b10: begin // DELAY
				clr_tmr = 0;
				if (&tmr)
					nstate = 2'b00;
				else
					nstate = 2'b10;
			end
			default:
				nstate = 2'b00;
		endcase
					end
	
	always @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= 0;
		else
			state <= nstate;
	end

	 
	 reg [2:0] IR_enables;					// 1 hot enable used for {IR_in,IR_mid,IR_out} gating
	 
    always @(*) begin
      case (chnnl_cnt)
	    3'b000 : begin
	     chnnl = 3'b001;		// convert IR_in_rht first
		  IR_enables = 3'b100;	// inner IRs enabled
		end
		3'b001 : begin
		  chnnl = 3'b000;		// convert IR_in_lft next
		  IR_enables = 3'b100;	// inner IRs enabled
		end
	    3'b010 : begin
	      chnnl = 3'b100;		// convert IR_mid_rht next
		  IR_enables = 3'b010;	// middle IRs enabled
		end
		3'b011 : begin
		  chnnl = 3'b010;		// convert IR_mid_lft next
		  IR_enables = 3'b010;	// middle IRs enabled
		end
	    3'b100 : begin
	      chnnl = 3'b011;		// convert IR_out_rht next
		  IR_enables = 3'b001;	// outer IRs enabled
		end
		3'b101 : begin			// 3'b101 case
		  chnnl = 3'b111;		// convert IR_out_lft next
		  IR_enables = 3'b001;	// outer IRs enabled
		end
		default : begin
		  chnnl = 3'b001;
		  IR_enables = 3'b100;
		end
	  endcase
	end
  
  assign {IR_in_en,IR_mid_en,IR_out_en} = IR_enables;
		
endmodule