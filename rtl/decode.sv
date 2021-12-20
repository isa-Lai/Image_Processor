`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif


module decode(
		input logic CLOCK_50_I,
		input logic resetn,
		input logic enable,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic [17:0] SRAM_address,
		output logic SRAM_we_n,
		output logic finish,
		
		//for ram
		output logic [6:0] address_b,
		output logic [31:0] write_data_b,
		output logic write_enable_b,
		input logic signed[31:0] read_data_b,
		
		//flag
		output logic one_block_finished,
		input logic newblock_start
		
);

// milestone 3 states
enum logic [4:0]{
	IDLE,
	R0,
	H0,H1,
	Wait,
	Read0,Read1,Read2,Read_init,
	D,
	W,W_zeros,W_all_zeros,
	check,
	M3_com
}decode_state;

logic [5:0]inblock_address;
logic signed[5:0] decode_dir;
logic signed[17:0] SRAM_dir;// might not used in completed 

logic [15:0] decode_buf;
logic [15:0] shift_result;
logic Q_choice;
logic [3:0] Q_index;

logic [2:0] counter; 
logic [3:0] zero_counter;

logic [17:0] SRAM_address_buf;  //for read
logic [17:0] W_address_buf;  //for write
logic [31:0] read_data_buf;
logic [4:0] pointer;


logic block_odd;
//block address
logic[5:0] block_col;
logic[5:0] block_row;

logic newblock_start_buf;

logic[15:0] w_data_buf [7:0];


//buf newblock_start
always @(posedge CLOCK_50_I) begin
	newblock_start_buf <= newblock_start;
end

always @(posedge CLOCK_50_I) begin
	address_b <= {2'b0,inblock_address[5:1]};
end

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		//output
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		SRAM_we_n <= 1'd1;
		finish <= 1'd0;
		SRAM_address_buf<= 18'b0;
		read_data_buf <= 32'd0;
		
		//parameters
		Q_choice <= 1'b0;
		decode_buf <= 16'b0;
		counter <= 3'b0;
		
		inblock_address<= 6'b0;
		//flag
		one_block_finished <= 1'b0;
		
		//ram
		write_enable_b <= 1'b0;
		
		decode_state <= IDLE;
	end
	else if(enable)  begin
		case(decode_state)
//--------------------------Wait to start--------------------------//		
		IDLE: begin
			SRAM_address_buf<= 18'd76801; //start of next data
			SRAM_address <= 18'd76800; //start of data
			W_address_buf <= 18'd76800;
			
			counter <= 3'b0;
			
			pointer<=5'b0;
			
			block_col <= 6'b0;
			block_row <= 6'b0;
			
			inblock_address<= 6'b0;
			decode_state <= R0;
		end
//--------------------------read header--------------------------//
		R0: begin
			// read three
			SRAM_address <= SRAM_address_buf;
			SRAM_address_buf <= SRAM_address_buf + 18'd1;
			
			counter <= counter + 3'b1;
			
			//wait for read in sram
			if(counter == 3'd1) begin
				counter <= 3'b0;
				decode_state <= H0;
			end
			else
				counter <= counter + 3'b1;
		end
		H0: begin
			// read two
			SRAM_address <= SRAM_address_buf;
			SRAM_address_buf <= SRAM_address_buf + 18'd1;
		
			if(SRAM_read_data == 16'hDEAD & counter == 3'b0) begin
				
				counter <= counter + 3'b1;
			end
			else if(SRAM_read_data == 16'hBEEF & counter == 3'b1) begin
				counter <= 3'b0;
				decode_state <= H1;
			end
		end
		H1: begin
			
		
			if(counter == 3'b0) begin
				//assign the dequant Q
				Q_choice <= SRAM_read_data[15];
				counter <= counter + 3'b1;
				
				// read one
				SRAM_address <= SRAM_address_buf;
				SRAM_address_buf <= SRAM_address_buf + 18'd1;
			end
			else if(counter == 3'b1) begin
				counter <= 3'b0;
				decode_state <= Read1;
			end
		
		end
//--------------------------If one block finished, wait when next box start--------------------------//
		Wait: begin
			if(newblock_start_buf == 1'b0 & newblock_start == 1'b1)
				decode_state <= D;
		end
//--------------------------Read from SRAM--------------------------//		
		Read0: begin
			//used to buf new
			read_data_buf <= read_data_buf | ({16'b0,SRAM_read_data}<<(pointer-5'd16));
			pointer <= pointer - 5'd16;
			
			//if start of the block
			if(~|inblock_address) begin
				decode_state <= Wait; // might fixed after the ms2 ms3 concurrently
				one_block_finished <= 1'b1;
			end
			else
				decode_state <= D;
			
			counter <= 3'b0;
		end
		Read1: begin
			read_data_buf[31:16] <= SRAM_read_data;
			pointer <= pointer - 5'd16;
			decode_state <= Read2;
		end
		Read2: begin
			read_data_buf[15:0] <= SRAM_read_data;
			pointer <= pointer - 5'd16;
			decode_state <= D;
			
			counter <= 3'b0;
		end
//--------------------------Decode--------------------------//
		D: begin
			//if start then put down flag of one block
			one_block_finished <= 1'b0;
			
			//check header
			if(read_data_buf[31:30] == 2'd00) begin
			//-----------------------------------------------00---------------------
				//read zeros
				if(read_data_buf[29:28] == 2'b0) begin
					zero_counter <= 4'd3;
					decode_state <= W_zeros;
					inblock_address <= inblock_address + decode_dir;

				end
				else if(read_data_buf[29:28] == 2'b1) begin
					decode_state <= check;
				end
				else begin
					decode_state <= W_zeros;
					zero_counter <= {2'b0,read_data_buf[29:28]} - 4'd1;
					inblock_address <= inblock_address + decode_dir;
				end
					
				//move pointer
				read_data_buf <= read_data_buf<<4;
				pointer <= pointer + 5'd4;
				
				//write into RAM if nexr one is odd
				if(inblock_address[0]) begin //odd
					write_data_b <= {w_data_buf[inblock_address[5:3]],16'b0};
					write_enable_b <=1'b1;
				end else begin
					w_data_buf[inblock_address[5:3]] <= 16'b0;
				end
				
			end
			if(read_data_buf[31:30] == 2'd01) begin
				if(read_data_buf[29]) begin
					//-----------------------------------------------011---------------------
					//move pointer
					read_data_buf <= read_data_buf<<3;
					pointer <= pointer + 5'd3;
					
					//write into RAM
					if(inblock_address[0]) begin //odd
						write_data_b <= {w_data_buf[inblock_address[5:3]],16'b0};
						write_enable_b <=1'b1;
					end else begin
						w_data_buf[inblock_address[5:3]] <= 16'b0;
					end
					
					
					if( inblock_address == 6'd63)
						decode_state <= check;
					else begin
						decode_state <= W_all_zeros;
						inblock_address <= inblock_address + decode_dir;
						
					end
				end
				else begin
					//-----------------------------------------------010---------------------
					//read zeros
					if(read_data_buf[28:25] == 4'b0) begin
						zero_counter <= 4'd15;
						decode_state <= W_zeros;
						inblock_address <= inblock_address + decode_dir;
					end
					else if(read_data_buf[28:25] == 4'b1) begin
						decode_state <= check;
					end
					else begin
						decode_state <= W_zeros;
						zero_counter <= read_data_buf[28:25] - 4'd1;
						inblock_address <= inblock_address + decode_dir;
					end
						
					//move pointer
					read_data_buf <= read_data_buf<<7;
					pointer <= pointer + 5'd7;
					
					//write into RAM
					if(inblock_address[0]) begin //odd
						write_data_b <= {w_data_buf[inblock_address[5:3]],16'b0};
						write_enable_b <=1'b1;
					end else begin
						w_data_buf[inblock_address[5:3]] <= 16'b0;
					end					
					
					decode_state <= W_zeros;

				end
			end
			if(read_data_buf[31:30] == 2'b10) begin
				//-----------------------------------------------101---------------------
				if(read_data_buf[29]) begin
					//read 5 bits
					if(read_data_buf[28])
						decode_buf <= {11'b11111111111,read_data_buf[28:24]};
					else
						decode_buf <= {11'b0,read_data_buf[28:24]};
				
					//move pointer
					read_data_buf <= read_data_buf<<8;
					pointer <= pointer + 5'd8;
					
					
					
					decode_state <= W;
				end
				//-----------------------------------------------100---------------------
				else begin
					//read 9 bits
					if(read_data_buf[28])
						decode_buf <= {7'b1111111,read_data_buf[28:20]};
					else
						decode_buf <= {7'b0,read_data_buf[28:20]};
				
					//move pointer
					read_data_buf <= read_data_buf<<12;
					pointer <= pointer + 5'd12;
					
					
					decode_state <= W;
				end
			end
			//-----------------------------------------------11---------------------
			if(read_data_buf[31:30] == 2'b11) begin
					//read 3 bits
					if(read_data_buf[29])
						decode_buf <= {13'b1111111111111,read_data_buf[29:27]};
					else
						decode_buf <= {13'b0,read_data_buf[29:27]};
					
					//move pointer
					read_data_buf <= read_data_buf<<5;
					pointer <= pointer + 5'd5;
					
					
					decode_state <= W;
			
			end
		end
//--------------------------Write into SRAM--------------------------//
		W: begin
		//write into RAM
			if(inblock_address[0]) begin //odd
				write_data_b <= {w_data_buf[inblock_address[5:3]],shift_result};
				write_enable_b <=1'b1;
			end else begin
				w_data_buf[inblock_address[5:3]] <= shift_result;
			end			
			decode_state <= check;
		end
		W_zeros: begin
			if(zero_counter > 4'b1) 
				inblock_address <= inblock_address + decode_dir; //update times same as zero times
			
			//count zero
			zero_counter <= zero_counter - 4'b1;
			if(zero_counter == 4'b0) begin
				decode_state <= check;
				write_enable_b <= 1'b0;
			end
			else begin
				//write into RAM
				if(inblock_address[0]) begin //odd
					write_data_b <= {w_data_buf[inblock_address[5:3]],16'b0};
					write_enable_b <= 1'b1;
				end else begin
					w_data_buf[inblock_address[5:3]] <= 16'b0;
					write_enable_b <=1'b0;
				end
				
			end
		end
		W_all_zeros: begin
			//write into RAM
				if(inblock_address[0]) begin //odd
					write_data_b <= {w_data_buf[inblock_address[5:3]],16'b0};
					write_enable_b <=1'b1;
				end else begin
					w_data_buf[inblock_address[5:3]] <= 16'b0;
					write_enable_b <=1'b0;
				end
			
			if(&inblock_address) begin
				decode_state <= check;
			end
			else begin
				inblock_address <= inblock_address + decode_dir;
			end
		end
//-------------------check if completed-----------//
		check: begin
			
			write_enable_b <= 1'b0;
			// if need to read new
			if(pointer > 5'd19)begin
					//go read one
					SRAM_address <= SRAM_address_buf;
					SRAM_address_buf <= SRAM_address_buf + 18'd1;
					counter <= 3'd2;
					decode_state <= Read_init;
				
			end
			else begin
				if(&inblock_address)
					decode_state <=Wait;
				else
				decode_state <= D;
					
			end

			
			//check if reach the end
			if(&inblock_address) begin
				if(pointer <= 5'd19)
				//raise flag for one block finished. //if need to read, raise after read
					one_block_finished<= 1'b1;
//				//move write buf
//				if(block_row < 6'd30 )begin
//					if(block_col==6'd39)
//						W_address_buf <= W_address_buf + 18'd1; //for y
//					else
//						W_address_buf <= W_address_buf - 18'd2239;
//				end
//				else begin
//					if(block_col==6'd19 | block_col==6'd39)
//						W_address_buf <= W_address_buf + 18'd1; //for u v
//					else
//						W_address_buf <= W_address_buf - 18'd1119;
//				end
				
				//update col
				if(block_col==6'd39) begin
					block_col <= 6'b0;
					block_row <= block_row + 6'b1;
				end
				else
					block_col <= block_col + 6'b1;
					
				//finish everything
				if(block_row == 6'd60 & block_col == 6'd0 ) begin //since work with ms2 need to read one more, but not used
					finish <= 1'b1;
					one_block_finished<= 1'b1;
					decode_state <= M3_com;
				end
				//clear 
				inblock_address <=6'b0; 
			end
			else 
				inblock_address <= inblock_address + decode_dir;

			
			
		end
		Read_init: begin
			//wait sram to load
			if (counter==3'd0) begin
				//gp buf
				decode_state <= Read0;
			end
			else
				counter <= counter - 3'b1;

		end
//--------------------------complete MS3--------------------------//		
		M3_com: begin
			//if(newblock_start) begin
			finish <= 1'b1;
			decode_state <= IDLE;
			//end
		end
		default: decode_state <= IDLE;
		endcase
	end
end

//-------------------assign direction----------------//
always_comb begin
	//reuse Q_index
	//if sum is odd number
	if(Q_index[0]) begin
		//odd line gose down
		if (inblock_address[5:3]==3'd7) begin
			decode_dir <= 6'sd1;
			//SRAM_dir <= 18'sd1;
		end
		else if( inblock_address[2:0]==3'b0 ) begin
			decode_dir <= 6'sd8;
			//SRAM_dir <= 18'sd320;
		end
		else begin
			decode_dir <=  6'sd7;
			//SRAM_dir <= 18'sd319;
		end
	end
	else begin
		//even line gose up
		if( inblock_address[2:0]==3'd7 ) begin
			decode_dir <= 6'sd8;
			//SRAM_dir <= 18'sd320;
		end
		else if (inblock_address[5:3]==3'd0) begin
			decode_dir <= 6'sd1;
			//SRAM_dir <= 18'sd1;
		end
		else begin
			decode_dir <=  -6'sd7;
			//SRAM_dir <= -18'sd319;
		end
	end
end


//--------------------------shift of decoding-------------------------//
assign Q_index = {1'b0,inblock_address[5:3]} + {1'b0,inblock_address[2:0]};

always_comb begin
	// use Q1
	if (Q_choice) begin
		
		shift_result = decode_buf << 5;
		if(Q_index<11)
			shift_result = decode_buf << 4;
		if(Q_index<8)
			shift_result = decode_buf << 3;
		if(Q_index<6)
			shift_result = decode_buf << 2;
		if(Q_index<4)
			shift_result = decode_buf << 1;
		if(Q_index<1)
			shift_result = decode_buf << 3;
	
	end
	// use Q0
	else begin
		shift_result = decode_buf << 6;
		if(Q_index<8)
			shift_result = decode_buf << 5;
		if(Q_index<6)
			shift_result = decode_buf << 4;
		if(Q_index<4)
			shift_result = decode_buf << 3;
		if(Q_index<2)
			shift_result = decode_buf << 2;
		if(Q_index<1)
			shift_result = decode_buf << 3;
	end
end


endmodule