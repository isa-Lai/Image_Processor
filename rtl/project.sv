/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This is the top module (same as experiment4 from lab 5 - just module renamed to "project")
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_N_I,         // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);
	
logic resetn;

top_state_type top_state;

// For Push button
logic [3:0] PB_pushed;

// For VGA SRAM interface
logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;

// For SRAM
logic [17:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];

// For error detection in UART
logic Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

//for ram
logic [6:0] address_a[1:0], address_b[1:0];
logic [31:0] write_data_b[1:0];
logic [31:0] write_data_a[1:0];
logic write_enable_b[1:0];
logic write_enable_a[1:0];
logic signed[31:0] read_data_a[1:0];
logic signed[31:0] read_data_b[1:0];

// buf and flag
logic IDCT_oneblock_finish_buf;
logic decode_oneblock_finish_buf;
logic switch_RAM;
logic firstMS3_finished;

// ms1 unsampling block
logic unsampling_enable;
logic unsampling_end;
logic upsampling_we_n;
logic [15:0] upsampling_write_data;
logic [17:0] upsampling_address;

// ms2 IDCT block
logic IDCT_enable;
logic IDCT_end;
logic IDCT_we_n;
logic [15:0] IDCT_write_data;
logic [17:0] IDCT_address;

//for idct ram1
logic [6:0] IDCT_address_a, IDCT_address_b,S_IDCT_address_a,S_IDCT_address_b;
logic [31:0] IDCT_write_data_b;
logic [31:0] IDCT_write_data_a;
logic IDCT_write_enable_b;
logic IDCT_write_enable_a;
logic signed[31:0] IDCT_read_data_a;
logic signed[31:0] IDCT_read_data_b;
logic signed[31:0] S_IDCT_read_data_a;
logic signed[31:0] S_IDCT_read_data_b;
logic IDCT_oneblock_finish;
logic [10:0] blockcounter;

// ms3 decode block
logic decode_enable;
logic decode_end;
logic decode_we_n;
logic [15:0] decode_write_data;
logic [17:0] decode_address;
logic one_block_finished;
logic newblock_start;
//working with ms2
logic [6:0] decode_address_b;
logic [31:0] decode_write_data_b;
logic decode_write_enable_b;
logic signed[31:0] decode_read_data_b;
logic decode_oneblock_finish;


unsampling unsampling_block(
	.CLOCK_50_I(CLOCK_50_I),
	.resetn(resetn),
	.enable(unsampling_enable),
	.SRAM_read_data(SRAM_read_data),	
	.SRAM_write_data(upsampling_write_data),
	.SRAM_address(upsampling_address),
	.SRAM_we_n(upsampling_we_n),	
	.finish(unsampling_end)
);



IDCT IDCT_block(
	.CLOCK_50_I(CLOCK_50_I),
	.resetn(resetn),
	.enable(IDCT_enable),
	.SRAM_read_data(SRAM_read_data),	
	.SRAM_write_data(IDCT_write_data),
	.SRAM_address(IDCT_address),
	.SRAM_we_n(IDCT_we_n),	
	.finish(IDCT_end),
	
	//for ram a
	.address_0a(IDCT_address_a),
	.write_data_0a(IDCT_write_data_a),
	.write_enable_0a(IDCT_write_enable_a),
	.read_data_a_extra(IDCT_read_data_a),
		//for ram b
	.address_0b(IDCT_address_b),
	.write_data_b_extra(IDCT_write_data_b),
	.write_enable_b_extra(IDCT_write_enable_b),
	.read_data_b_extra(IDCT_read_data_b),
	// ram for reading S in the other RAM
	.S_address_0a(S_IDCT_address_a),
	.S_read_data_a_extra(S_IDCT_read_data_a),
	.S_address_0b(S_IDCT_address_b),
	.S_read_data_b_extra(S_IDCT_read_data_b),
		
		//flag
	.one_block_finished(IDCT_oneblock_finish),
	.decode_finished(decode_oneblock_finish)
);




decode decode_block(
	.CLOCK_50_I(CLOCK_50_I),
	.resetn(resetn),
	.enable(decode_enable),
	.SRAM_read_data(SRAM_read_data),	
	.SRAM_write_data(decode_write_data),
	.SRAM_address(decode_address),
	.SRAM_we_n(decode_we_n),	
	.finish(decode_end),
	
	//for ram
	.address_b(decode_address_b),
	.write_data_b(decode_write_data_b),
	.write_enable_b(decode_write_enable_b),
	.read_data_b(decode_read_data_b),
	
	//flag
	.one_block_finished(decode_oneblock_finish),
	.newblock_start(newblock_start)
);
assign newblock_start = IDCT_oneblock_finish;


// Push Button unit
PB_controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_N_I),	
	.PB_pushed(PB_pushed)
);

VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
   
	// For accessing SRAM
	.SRAM_base_address(VGA_base_address),
	.SRAM_address(VGA_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
   
	// To VGA pins
	.VGA_CLOCK_O(VGA_CLOCK_O),
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O),
	.VGA_GREEN_O(VGA_GREEN_O),
	.VGA_BLUE_O(VGA_BLUE_O)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn), 
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	//.SRAM_write_data(16'b0),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O[17:0]),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

//-------------------RAM----------//
dual_port_RAM3 dual_port_RAM_3 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50_I ),
	.data_a (  write_data_a[1]),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);

	
dual_port_RAM0 dual_port_RAM_0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50_I ),
	.data_a (  write_data_a[0]),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

//------------------------------------assign ram to ms3 and ms2
always_comb begin
	if(switch_RAM) begin
		//ms3
		address_b[1] <= decode_address_b;
		write_data_b[1] <= decode_write_data_b;
		write_enable_b[1] <= decode_write_enable_b;
		decode_read_data_b <= read_data_b[1];
		address_a[1] <=S_IDCT_address_a;
		write_data_a[1] <= 32'b0;
		write_enable_a[1] <= 1'b0;
		S_IDCT_read_data_a <= read_data_a[1];
		//ms2
		address_b[0] <= IDCT_address_b;
		write_data_b[0] <= IDCT_write_data_b;
		write_enable_b[0] <= IDCT_write_enable_b;
		IDCT_read_data_b <= read_data_b[0];
		address_a[0] <= IDCT_address_a;
		write_data_a[0] <= IDCT_write_data_a;
		write_enable_a[0] <= IDCT_write_enable_a;
		IDCT_read_data_a <= read_data_a[0];
		
	end
	else begin
		//ms3
		address_b[0] <= decode_address_b;
		write_data_b[0] <= decode_write_data_b;
		write_enable_b[0] <= decode_write_enable_b;
		decode_read_data_b <= read_data_b[0];
		address_a[0] <=S_IDCT_address_a;
		write_data_a[0] <= 32'b0;
		write_enable_a[0] <= 1'b0;
		S_IDCT_read_data_a <= read_data_a[0];
		//ms2
		address_b[1] <= IDCT_address_b;
		write_data_b[1] <= IDCT_write_data_b;
		write_enable_b[1] <= IDCT_write_enable_b;
		IDCT_read_data_b <= read_data_b[1];
		address_a[1] <= IDCT_address_a;
		write_data_a[1] <= IDCT_write_data_a;
		write_enable_a[1] <= IDCT_write_enable_a;
		IDCT_read_data_a <= read_data_a[1];
	end
end



assign SRAM_ADDRESS_O[19:18] = 2'b00;

//buf flag

always @(posedge CLOCK_50_I or negedge resetn) begin
	if(~resetn) begin
		IDCT_oneblock_finish_buf<= 1'b0;
		decode_oneblock_finish_buf <= 1'b0;
	end
	else begin
		IDCT_oneblock_finish_buf<= IDCT_oneblock_finish;
		decode_oneblock_finish_buf <= decode_oneblock_finish;
	end
end

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		switch_RAM  <= 1'b0;
		firstMS3_finished <= 1'b0;
	end
	else begin
		if(!firstMS3_finished) begin 
			if(!decode_oneblock_finish_buf & decode_oneblock_finish) begin
			switch_RAM <= switch_RAM^1'b1;
			firstMS3_finished <= 1'b1;
			end
		end
		else if(!IDCT_oneblock_finish & IDCT_oneblock_finish_buf)
		//else if(decode_oneblock_finish_buf ^ decode_oneblock_finish)
			switch_RAM <= switch_RAM^1'b1;
	end
end


always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		
		VGA_enable <= 1'b1;
		unsampling_enable <= 1'b0;

	end else begin

		// By default the UART timer (used for timeout detection) is incremented
		// it will be synchronously reset to 0 under a few conditions (see below)
		UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			VGA_enable <= 1'b1;  
			if (~UART_RX_I) begin
				// Start bit on the UART line is detected
				UART_rx_initialize <= 1'b1;
				UART_timer <= 26'd0;
				VGA_enable <= 1'b0;
				top_state <= S_UART_RX;
			end
		end

		S_UART_RX: begin
			// The two signals below (UART_rx_initialize/enable)
			// are used by the UART to SRAM interface for 
			// synchronization purposes (no need to change)
			UART_rx_initialize <= 1'b0;
			UART_rx_enable <= 1'b0;
			if (UART_rx_initialize == 1'b1) 
				UART_rx_enable <= 1'b1;

			// UART timer resets itself every time two bytes have been received
			// by the UART receiver and a write in the external SRAM can be done
			if (~UART_SRAM_we_n) 
				UART_timer <= 26'd0;

			// Timeout for 1 sec on UART (detect if file transmission is finished)
			if (UART_timer == 26'd49999999) begin
				top_state <= S_M3;
				UART_timer <= 26'd0;
				decode_enable <= 1'b1;
			end
		end
		S_M3: begin
			if (decode_oneblock_finish & ~decode_oneblock_finish_buf)begin
				top_state <= L_M2;
				IDCT_enable <= 1'b1;
			end
		end
		L_M2: begin
			if(IDCT_oneblock_finish & ~IDCT_oneblock_finish_buf) begin
				if(blockcounter==11'd2399) begin
					top_state <= S_M1;
					IDCT_enable <= 1'b0;
					unsampling_enable <= 1'b1;
				end
				else begin
					top_state <= L_M3;
				end
				blockcounter <= blockcounter+ 1'b1;
			end
			

		end
		L_M3: begin
			if (decode_oneblock_finish & ~decode_oneblock_finish_buf)begin
				top_state <= L_M2;
			end
			if (IDCT_end)begin
				top_state <= S_M1;
				IDCT_enable <= 1'b0;
				unsampling_enable <= 1'b1;
			end
		end
		S_M2: begin
			if (IDCT_end)begin
				top_state <= S_M1;
				IDCT_enable <= 1'b0;
				unsampling_enable <= 1'b1;
			end
		end
		S_M1: begin
			if (unsampling_end)begin
				top_state <= S_IDLE;
				unsampling_enable <= 1'b0;
			end
		end

		default: top_state <= S_IDLE;

		endcase
	end
end

// for this design we assume that the RGB data starts at location 0 in the external SRAM
// if the memory layout is different, this value should be adjusted 
// to match the starting address of the raw RGB data segment
assign VGA_base_address = 18'd146944;

// Give access to SRAM for UART and VGA at appropriate time
// modify here to use proper block
always_comb begin
	if(top_state == S_M3 | top_state == L_M3) begin
		SRAM_address  = decode_address;
		SRAM_write_data = decode_write_data;
		SRAM_we_n = decode_we_n;
	end
	else if(top_state == S_M2 | top_state == L_M2) begin
		SRAM_address  = IDCT_address;
		SRAM_write_data = IDCT_write_data;
		SRAM_we_n = IDCT_we_n;
	end
	else if(top_state == S_M1) begin
		SRAM_address  = upsampling_address;
		SRAM_write_data = upsampling_write_data;
		SRAM_we_n = upsampling_we_n;
	end
	else if(top_state ==S_UART_RX) begin
		SRAM_address  = UART_SRAM_address;
		SRAM_write_data = UART_SRAM_write_data;
		SRAM_we_n = UART_SRAM_we_n;
	end
	else begin
		SRAM_address  = VGA_SRAM_address;
		SRAM_write_data = 16'd0;
		SRAM_we_n = 1'b1;
	end

end

// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[17:16]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, Frame_error, UART_rx_initialize, PB_pushed};

endmodule
