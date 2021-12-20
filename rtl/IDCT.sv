`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif


module IDCT(
		input logic CLOCK_50_I,
		input logic resetn,
		input logic enable,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic [17:0] SRAM_address,
		output logic SRAM_we_n,
		output logic finish,
		
		//for ram a
		output logic [6:0] address_0a,
		output logic [31:0] write_data_0a,
		output logic write_enable_0a,
		input logic signed[31:0] read_data_a_extra,
		//for ram b
		output logic [6:0] address_0b,
		output logic [31:0] write_data_b_extra,
		output logic write_enable_b_extra,
		input logic signed[31:0] read_data_b_extra,
		
		//ram for reading S in the other RAM
		output logic [6:0] S_address_0a,
		input logic signed[31:0] S_read_data_a_extra,
		output logic [6:0] S_address_0b,
		input logic signed[31:0] S_read_data_b_extra,
		
		//flag
		output logic one_block_finished,
		input logic decode_finished
		
);
// milestone 2 states
enum logic [6:0]{
	IDLE,
	Fs0,Fs1,Fs2,Fs3,Fs4,Fs5,Fs6,
	CtW0,CtW1,CtW2,
	Ct_com0,Ct_com1,
	CsFs0,CsFs1,CsFs2,
	Cs_com0,Cs_com1,Wait,Cs_com2,
	comp
}IDCT_state;

logic [31:0] read_data_0a_ext;
logic [31:0] read_data_0b_ext;	
logic [31:0] read_data_1a_ext;
logic [31:0] read_data_1b_ext;

logic signed[31:0] mul0;
logic signed[31:0] mul1; 
logic signed[31:0] mul2;
logic signed[31:0] op0;
logic signed[31:0] op1; 
logic signed[31:0] op2;

logic [5:0] c_index;
logic signed[31:0] C;
logic [5:0] c1_index;
logic signed[31:0] C1;
logic [5:0] c2_index;
logic signed[31:0] C2;

assign mul0 = op0 * C;
assign mul1 = op1 * C1;
assign mul2 = op2 * C2;


logic [6:0] address_1a, address_1b, address_2a, address_2b, address_0b_buf;//buf used to buf s address
logic [31:0] write_data_b[2:0];
logic write_enable_b [2:0];
logic signed[31:0] read_data_a [2:0];
logic signed[31:0] read_data_b [2:0];

//special edit for ms3
assign write_data_b_extra = write_data_b[0];
assign write_enable_b_extra = write_enable_b[0];
assign S_address_0a = address_0b;

dual_port_RAM2 dual_port_RAM_2 (
	.address_a ( address_2a ),
	.address_b ( address_2b ),
	.clock ( CLOCK_50_I ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[2] ),
	.wren_a ( 1'b0 ), 
	.wren_b ( write_enable_b[2] ),
	.q_a ( read_data_a[2] ),
	.q_b ( read_data_b[2] )
	);


dual_port_RAM1 dual_port_RAM_1 (
	.address_a ( address_1a ),
	.address_b ( address_1b ),
	.clock ( CLOCK_50_I ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[1] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);


	
logic isfirst;	
logic isfirstwrite;
logic isodd;
logic bufeven;
logic isfirstblock;

logic [5:0]inblock_address;	
logic [15:0]sprime_sram_address;
logic [2:0] counter8;  //used to count if there is one row
logic [31:0] sprime_buf;
logic [17:0] sram_block_address_start;
logic [17:0] sram_write_address_start;
logic [31:0]T;

//block address
logic[5:0] block_col;
logic[5:0] block_row;

logic [7:0] clip_s;


always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		//output
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		SRAM_we_n <= 1'd1;
		
		//all flag
		finish <= 1'd0;
		isfirst <= 1'b0;
		isodd <= 1'b0;
		bufeven <= 1'b0;
		isfirstblock <= 1'b0;
		isfirstwrite <= 1'b0;
		one_block_finished <= 1'b0;
		
		//address
		inblock_address <= 6'd0;
		block_col <= 6'b0;
		block_row <= 6'b0;
		sprime_sram_address <= 16'd0;
		sram_block_address_start <= 18'd0;
		sram_write_address_start <= 18'd0;
		
		//buf
		T<=32'd0;
		sprime_buf <= 32'b0;
		block_col <= 6'b0;
		block_row <= 6'b0;
		
		//counter 
		counter8 <= 3'd0;
		
		//ram
		address_0a<= 7'b0;
		address_0b<= 7'b0; 
		address_1a<= 7'b0; 
		address_1b<= 7'b0; 
		address_2a<= 7'b0;
		address_2b<= 7'b0;
		address_0b_buf <= 7'b0;
		
		
		IDCT_state <= IDLE;
	end
	else if(enable) begin
		case(IDCT_state)
//--------------------------Wait to start--------------------------//
		IDLE: begin
			//output
			SRAM_write_data <= 16'd0;
			SRAM_address <= 18'd0;
			SRAM_we_n <= 1'd1;
			
			//all flag
			finish <= 1'd0;
			isfirst <= 1'b0;
			isodd <= 1'b0;
			bufeven <= 1'b0;
			isfirstblock <= 1'b0;
			isfirstwrite <= 1'b0;
			
			//address
			inblock_address <= 6'd0;
			block_col <= 6'b0;
			block_row <= 6'b0;
			sprime_sram_address <= 16'd0;
			sram_block_address_start <= 18'd0;
			sram_write_address_start <= 18'd0 - 18'd4;
			
			//buf
			T<=32'd0;
			sprime_buf <= 32'b0;
			block_col <= 6'b0;
			block_row <= 6'b0;
			
			//counter 
			counter8 <= 3'd0;
			
			//ram
			address_0a<= 7'b0;
			address_0b<= 7'b0; 
			address_1a<= 7'b0; 
			address_1b<= 7'b0; 
			address_2a<= 7'b0;
			address_2b<= 7'b0;
			address_0b_buf <= 7'b0;
				
			//check start
			
			//IDCT_state <= Fs0; //fentch no need after ms3
			
			IDCT_state <= Fs5;
		end
//--------------------------store s'--------------------------//		
		Fs0:begin
			SRAM_address<= 18'd76800;//read S00
			counter8 <= counter8 + 3'd1;
			IDCT_state <= Fs1;
		end
		Fs1:begin
			SRAM_address<= SRAM_address+ 18'd1;//read S01
			counter8 <= counter8 + 3'd1;
			IDCT_state <= Fs2;
		end
		Fs2:begin
			SRAM_address<= SRAM_address+ 18'd1;//read S02
			counter8 <= counter8 + 3'd1;
			IDCT_state <= Fs3;
		end
		Fs3:begin
			SRAM_address<= SRAM_address+ 18'd1;//read S03
			counter8 <= counter8 + 3'd1;
			//store s00
			write_data_0a[31:16] <= SRAM_read_data;
			write_enable_0a <= 1'b0;
			
			IDCT_state <= Fs4;
		end
		Fs4:begin
			if(counter8 == 3'b0)
				SRAM_address<= SRAM_address+ 18'd313; //go to next row
			else
				SRAM_address<= SRAM_address+ 18'd1;//read S04
			counter8 <= counter8 + 3'd1;
			
			//write into ram
			write_data_0a[15:0] <= SRAM_read_data;
			write_enable_0a <= 1'b1;
			if(isfirst) 
				address_0a <= address_0a + 7'd1;
			else begin
				address_0a <= 7'd0;
				isfirst <= 1'b1;
			end
			
			//after one block go cal T
			if(address_0a<6'd30)
				IDCT_state <= Fs3;
			else
				IDCT_state <= Fs5;
		end
//--------------------------prepare for cal T--------------------------//		
		Fs5:begin
			isfirst <= 1'b0;
			sram_block_address_start <= 18'd76808;
			
			//prepare for read of s'0s'1 s'2s'3
			address_0a <= 7'd0;
			write_enable_0a <= 1'b0;
			address_0b <= 7'd1;
			write_enable_b[0] <= 1'd0;
			
			IDCT_state <= Fs6;
		end
		Fs6:begin
			//prepare for read of s'4s'5
			address_0a <= 7'd2;
			
			//init C
			c_index <= 6'b111110;
			c1_index <= 6'b111111;
			c2_index <= 6'b111101;
			
			//init write in T:
			address_1b<=7'b1111111;
			address_2b<=7'b1111111;
			
			isodd <= isodd^1'b1;
			
			counter8<=3'd1;
			
			
			
			IDCT_state <= CtW0;
		end
//--------------------------cal T & Write--------------------------//
		CtW0:begin
			address_0a <= address_0a + 7'd1; //s'6s'7
				
			//use  s'0s'1 s'2s'3
			sprime_buf <= read_data_0b_ext; //buf s'3
			op0 <= read_data_1a_ext; //s'0
			op1 <= read_data_0a_ext; //s'1
			op2 <= read_data_1b_ext; //s'2
			
			//add into T
			T <= T + mul0+mul1;
			
			//write T into RAM
			if(isfirst) begin
				if(isodd) begin
					address_1b<=address_1b+7'b1;
					write_data_b[1] <=  T + mul0+mul1;
					write_enable_b[1]<= 1'b1;
				end
				else begin
					address_2b<=address_2b+7'b1;
					write_data_b[2] <=  T + mul0+mul1;
					write_enable_b[2]<= 1'b1;
				end
				inblock_address <= inblock_address + 6'b1;
			end
			else
				isfirst<=1'b1;
				
			
			//add C
			c_index <= c_index + 6'd2;
			c1_index <= c1_index + 6'd2;
			c2_index <= c2_index + 6'd5;
			
			//buf 
			if(isfirstblock) begin
				address_0b_buf <= address_0b;
			end
			
			
			IDCT_state <= CtW1;
		
		end
		CtW1:begin
			// read is finish if calculating one line
			if(counter8 == 3'b0) begin
				address_0a <= address_0a + 7'd1;
				address_0b <= address_0a + 7'd2;
				
			end
			else begin
				address_0a <= address_0a - 7'd3;
				address_0b <= address_0a - 7'd2;
			end
			if(counter8 ==6'd1)
				isodd <= isodd^1'b1;
			counter8 <= counter8 + 3'b1;
			
			//add into T
			T <= mul1+mul2+mul0;
			
			//cal
			op0 <= sprime_buf; //s'3
			op1 <= read_data_1a_ext; //s'4
			op2 <= read_data_0a_ext; //s'5
		
			//add C
			c_index <= c_index + 6'd3;
			c1_index <= c1_index + 6'd3;
			c2_index <= c2_index + 6'd3;
			
			//reset back to read in T
			write_enable_b[1]<= 1'b0;
			write_enable_b[2]<= 1'b0;
			
			//write into sram
			if(isfirstblock) begin
				if(bufeven) begin
					SRAM_write_data[7:0] <= clip_s;
					SRAM_we_n <= 1'b0;
					if(counter8 == 6'd2 & isfirstwrite) begin
						if(block_row < 6'd30 )
							SRAM_address <= SRAM_address + 18'd157; //y
						else
							SRAM_address <= SRAM_address + 18'd77; //u v
					end 
					else begin
						SRAM_address <= SRAM_address + 18'd1;
						isfirstwrite <= 1'b1;
					end
				end
				else
					SRAM_write_data[15:8] <= clip_s;
			bufeven <= bufeven^1'b1;	
			end
			
			
			IDCT_state <= CtW2;
		
		end
		CtW2:begin
			//read
			address_0a <= address_0a + 7'd2;
			
			//add into T
			T <= T + mul1+mul2+mul0;
			
			//assign op
			op0 <= read_data_1a_ext; //s'4
			op1 <= read_data_0a_ext; //s'5
		
			//add C
			c_index <= c_index + 6'd3;
			c1_index <= c1_index + 6'd3;
			
			
			//reset back to read in T
			write_enable_b[1]<= 1'b0;
			write_enable_b[2]<= 1'b0;
			
			//read another s
			SRAM_we_n <= 1'b1;
			
			//read next S
			if(isfirstblock) begin
				address_0b <= address_0b_buf + 7'b1;
			end
			
			
			//if finished 64 T
			if(inblock_address<6'd63)
				IDCT_state <= CtW0;
			else begin
				//prepare for next state
				isfirst<=1'b0;
				IDCT_state <= Ct_com0;
				
				
			end
		end
//--------------------------finish cal t and prepare for cal s--------------------------//		
		Ct_com0: begin
			
			//add into T
			T <= T + mul0+mul1;
			
			address_1b<=address_1b+7'b1;
			write_data_b[1] <= T + mul0+mul1;
			write_enable_b[1]<= 1'b1;
			
			//prepare to read two T even and one T odd
			address_2a <= 7'd0;
			address_2b <= 7'd8;
			address_1a <= 7'd0;
			
			//read from sram
			
			SRAM_address<=sram_block_address_start;
			
			IDCT_state <= Ct_com1;
			
			
		end
		Ct_com1: begin
			//finishing one block count block;
			if(isfirstblock) begin
				if(block_col==6'd39) begin
					block_col <= 6'b0;
					block_row <= block_row + 6'b1;
				end
				else
					block_col <= block_col + 6'b1;
			end
			isfirstblock <= 1'b1;
			
			//store start point of write block
			if(block_row < 6'd30 )begin
				if(block_col==6'd39)
					sram_write_address_start <= sram_write_address_start + 18'd1124; //for y
				else
					sram_write_address_start <= sram_write_address_start + 18'd4;
			end
			else begin
				if(block_col==6'd19 | block_col==6'd39)
					sram_write_address_start <= sram_write_address_start + 18'd564; //for u v
				else
					sram_write_address_start <= sram_write_address_start + 18'd4;
			end
		
			//reset back to read in T
			write_enable_b[1]<= 1'b0;
			write_enable_b[2]<= 1'b0;
			
			//prepare to read two T odd and one T even
			address_2a <= 7'd16;
			address_1a <= 7'd8;
			address_1b <= 7'd16;
			
			
			//reset C
			c_index <= 6'b111110;
			c1_index <= 6'b111111;
			c2_index <= 6'b111101;
			
			//reuse t gain for the calculation
			T <= 32'd0;
			
			//prepare
			inblock_address <= 6'd0;
			counter8<=3'd1;
			isfirst <= 1'b0;
			isodd <= 1'b0;
			address_0b <= 7'b0111111; //store s in the botton half
			address_0a <= 7'b1111111;
			
			//finish everything
			if(block_row == 6'd59 & block_col == 6'd39 ) begin
				finish <= 1'b1;
				IDCT_state <= comp;
			end
			else begin
				IDCT_state <= CsFs0;
				
			end
			
			//finished one block and start ms3
			one_block_finished <= 1'b1;
		end
//--------------------------Cal s and store s'--------------------------//
//--------------------------Note !! all fentch are disabled for ms3--------------------------//
		CsFs0:begin
			//read one from even, one from odd
			address_1a<= address_1a + 7'd16;
			address_2a <= address_2a + 7'd8;
			
			//add into T
			T <= T + mul1+mul0;
			
			//write s into RAM
			if(isfirst) begin
				address_0b<=address_0b+7'b1;
				write_data_b[0] <= T + mul1+mul0;
				write_enable_b[0]<= 1'b1;
				inblock_address <= inblock_address + 6'b1;
			end
			else 
				isfirst<=1'b1;
			
			//use T0T1T2
			op0 <= read_data_a[2] >>> 8;
			op1 <= read_data_a[1] >>> 8;
			op2 <= read_data_b[2] >>> 8;
			
			//add C
			if(counter8 == 3'b1) begin
				c_index <= c_index + 6'd2;
				c1_index <= c1_index + 6'd2;
				c2_index <= c2_index + 6'd5;
			end
			else begin
				c_index <= c_index - 6'd6;
				c1_index <= c1_index - 6'd6;
				c2_index <= c2_index - 6'd3;
			end
			
			IDCT_state <= CsFs1;
			
		end
		CsFs1:begin
			// read is finish if calculating one line
			if(counter8 != 3'b0) begin
				address_2a <= address_2a - 7'd23;
				address_2b <= address_2b + 7'd1;
				address_1a <= address_1a - 7'd23;
				address_1b <= address_1b + 7'd1;
				
			end
			else begin
				address_2a <= 7'd0;
				address_2b <= 7'd8;
				address_1a <= 7'd0;
				address_1b <= 7'd16;
			end
			counter8 <= counter8 + 3'b1;
			
			//add into S
			T <= mul1+mul2+mul0;
			
			//use T3T4T5
			op0 <= read_data_a[1]>>> 8;
			op1 <= read_data_a[2]>>> 8;
			op2 <= read_data_b[1]>>> 8;
			
			
			//reset back to read in s
			write_enable_b[0]<= 1'b0;
			write_enable_0a <= 1'b0;
		
			//add C
			c_index <= c_index + 6'd3;
			c1_index <= c1_index + 6'd3;
			c2_index <= c2_index + 6'd3;
			
//			//also store s'
//			if(isodd) begin
//				write_data_0a[15:0] <= SRAM_read_data;
//				write_enable_0a <= 1'b1;
//			end
//			else begin
//				write_data_0a[31:16] <= SRAM_read_data;
//				address_0a <= address_0a + 7'b1;
//			end
//			//read next s'
//			if(counter8==3'd0)begin
//					//for U
//					if(block_row >= 6'd30 | (block_row == 6'd29 & block_col== 6'd39))
//						SRAM_address<= SRAM_address+ 18'd153;
//						
//					//for Y
//					else
//						SRAM_address<= SRAM_address+ 18'd313;
//				end
//			else 
//				SRAM_address<= SRAM_address+ 18'd1;
//			isodd<= isodd ^ 1'b1;
			
			
			
			IDCT_state <= CsFs2;
		end
		CsFs2:begin
			//read t
			address_2a <= address_2a + 7'd16;
			address_1a <= address_1a + 7'd8;
			
			//add into T
			T <= T + mul1+mul2+mul0;
			
			//use t6t7
			op0 <= read_data_a[2]>>> 8;
			op1 <= read_data_a[1]>>> 8;
			
			//add C
			c_index <= c_index + 6'd3;
			c1_index <= c1_index + 6'd3;
			
			write_enable_0a <= 1'b0;
			
			
			//if finishing calculate one block
			if(inblock_address<6'd63)
				IDCT_state <= CsFs0;
			else begin
				//prepare for next state
				isfirst<=1'b0;
				IDCT_state <= Cs_com0;
			end
		end
//--------------------------finished Cs and prepare for next--------------------------//	
		Cs_com0: begin
			//add into S
			T <= T + mul0+mul1;
			
			address_0b<=address_0b+7'b1;
			write_data_b[0] <= T + mul0+mul1;
			write_enable_b[0]<= 1'b1;
			
			//swtich back
			if(decode_finished) begin
				one_block_finished <= 1'b0;
			
				IDCT_state <= Cs_com1;
			end
			else
				IDCT_state <= Wait;
		end
		Wait : begin
			if(decode_finished) begin
				one_block_finished <= 1'b0;
			
				IDCT_state <= Cs_com1;
			end
		end
		Cs_com1: begin
			//store start point of block
			//fentch start earlier so need to swtich also earlier
			
			if(block_row < 6'd30) begin
				if(block_col==6'd38)
					sram_block_address_start <= sram_block_address_start + 18'd2248; //for y
				else
					sram_block_address_start <= sram_block_address_start + 18'd8;
			end
			else begin
				if(block_col==6'd18| block_col==6'd38)
					sram_block_address_start <= sram_block_address_start + 18'd1128; //for u v
				else
					sram_block_address_start <= sram_block_address_start + 18'd8;
			end
				
			
			
			//prepare for next
			//prepare for read of s'0s'1 s'2s'3
			address_0a <= 7'd0;
			write_enable_0a <= 1'b0;
			address_0b <= 7'd1;
			write_enable_b[0] <= 1'd0;
			
			IDCT_state <= Cs_com2;
		end
		Cs_com2: begin
			//reset back to read in s
			write_enable_b[0]<= 1'b0;
			
			//prepare for next
			//prepare for read of s'4s'5
			address_0a <= 7'd2;
			
			//init C
			c_index <= 6'b111110;
			c1_index <= 6'b111111;
			c2_index <= 6'b111101;
			
			//init write in T:
			address_1b<=7'b1111111;
			address_2b<=7'b1111111;
			
			isodd <= isodd^1'b1;
			isfirst <= 1'b0;
			bufeven <= 1'b0;
			
			counter8<=3'd1;
			
			//prepare for write sram
			address_0b <= 7'b1000000;
			write_enable_b[0] <= 1'd0;
			SRAM_address <= sram_write_address_start - 18'd1;
			
			//init
			inblock_address <= 6'd0;
			isfirstwrite <= 1'b0;
			
			IDCT_state <= CtW0;
			
		end
//--------------------------completed MS2--------------------------//		
		comp: begin
			IDCT_state <= IDLE;
		end
		default: IDCT_state <= IDLE;
		endcase
	end
end
				

//-------------------- extend the read data from ram0-------------------------//				
				
			
 
assign read_data_1a_ext = read_data_a_extra[31]?{16'b1111111111111111,read_data_a_extra[31:16]}:{16'b0,read_data_a_extra[31:16]} ;//extend a[31:16]
assign read_data_0a_ext = read_data_a_extra[15]?{16'b1111111111111111,read_data_a_extra[15:0]}:{16'b0,read_data_a_extra[15:0]};			
assign read_data_1b_ext = read_data_b_extra[31]?{16'b1111111111111111,read_data_b_extra[31:16]}:{16'b0,read_data_b_extra[31:16]}; //extend b[31:16]
assign read_data_0b_ext = read_data_b_extra[15]?{16'b1111111111111111,read_data_b_extra[15:0]}:{16'b0,read_data_b_extra[15:0]};			

//clips
assign clip_s = S_read_data_a_extra[31] ? 8'b0 :(|S_read_data_a_extra[30:24]? 8'd255:S_read_data_a_extra[23:16]);		
				
				
//-------------------- multiplyer-------------------------//




// assign c value
always_comb begin
	case(c_index)
	0:   C = 32'sd1448;   
	1:   C = 32'sd2008;   
	2:   C = 32'sd1892;   
	3:   C = 32'sd1702;   
	4:   C = 32'sd1448;   
	5:   C = 32'sd1137;  
	6:   C = 32'sd783;   
	7:   C = 32'sd399;  
	
	8:   C = 32'sd1448;
	9:   C = 32'sd1702;
	10:  C = 32'sd783;
	11:  C = -32'sd399;   
	12:  C = -32'sd1448;
	13:  C = -32'sd2008;
	14:  C = -32'sd1892;
	15:  C = -32'sd1137;
	
	16:  C = 32'sd1448;
	17:  C = 32'sd1137;
	18:  C = -32'sd783;
	19:  C = -32'sd2008;
	20:  C = -32'sd1448;
	21:  C = 32'sd399;
	22:  C = 32'sd1892;
	23:  C = 32'sd1702;
	
	24:  C = 32'sd1448;
	25:  C = 32'sd399;
	26:  C = -32'sd1892;
	27:  C = -32'sd1137;
	28:  C = 32'sd1448;
	29:  C = 32'sd1702;
	30:  C = -32'sd783;
	31:  C = -32'sd2008;
	
	32:  C = 32'sd1448;
	33:  C = -32'sd399;
	34:  C = -32'sd1892;
	35:  C = 32'sd1137;
	36:  C = 32'sd1448;
	37:  C = -32'sd1702;
	38:  C = -32'sd783;
	39:  C = 32'sd2008;
	
	40:  C = 32'sd1448;
	41:  C = -32'sd1137;
	42:  C = -32'sd783;
	43:  C = 32'sd2008;
	44:  C = -32'sd1448;
	45:  C = -32'sd399;
	46:  C = 32'sd1892;
	47:  C = -32'sd1702;
	
	48:  C = 32'sd1448;
	49:  C = -32'sd1702;
	50:  C = 32'sd783;
	51:  C = 32'sd399;
	52:  C = -32'sd1448;
	53:  C = 32'sd2008;
	54:  C = -32'sd1892;
	55:  C = 32'sd1137;
	
	56:  C = 32'sd1448;
	57:  C = -32'sd2008;
	58:  C = 32'sd1892;
	59:  C = -32'sd1702;
   60:  C = 32'sd1448;
   61:  C = -32'sd1137;
   62:  C = 32'sd783;
   63:  C = -32'sd399;
	endcase
end

// assign c1 value
always_comb begin
	case(c1_index)
	0:   C1 = 32'sd1448;   
	1:   C1 = 32'sd2008;   
	2:   C1 = 32'sd1892;   
	3:   C1 = 32'sd1702;   
	4:   C1 = 32'sd1448;   
	5:   C1 = 32'sd1137;  
	6:   C1 = 32'sd783;   
	7:   C1 = 32'sd399;  
	
	8:   C1 = 32'sd1448;
	9:   C1 = 32'sd1702;
	10:  C1 = 32'sd783;
	11:  C1 = -32'sd399;   
	12:  C1 = -32'sd1448;
	13:  C1 = -32'sd2008;
	14:  C1 = -32'sd1892;
	15:  C1 = -32'sd1137;
	
	16:  C1 = 32'sd1448;
	17:  C1 = 32'sd1137;
	18:  C1 = -32'sd783;
	19:  C1 = -32'sd2008;
	20:  C1 = -32'sd1448;
	21:  C1 = 32'sd399;
	22:  C1 = 32'sd1892;
	23:  C1 = 32'sd1702;
	
	24:  C1 = 32'sd1448;
	25:  C1 = 32'sd399;
	26:  C1 = -32'sd1892;
	27:  C1 = -32'sd1137;
	28:  C1 = 32'sd1448;
	29:  C1 = 32'sd1702;
	30:  C1 = -32'sd783;
	31:  C1 = -32'sd2008;
	
	32:  C1 = 32'sd1448;
	33:  C1 = -32'sd399;
	34:  C1 = -32'sd1892;
	35:  C1 = 32'sd1137;
	36:  C1 = 32'sd1448;
	37:  C1 = -32'sd1702;
	38:  C1 = -32'sd783;
	39:  C1 = 32'sd2008;
	
	40:  C1 = 32'sd1448;
	41:  C1 = -32'sd1137;
	42:  C1 = -32'sd783;
	43:  C1 = 32'sd2008;
	44:  C1 = -32'sd1448;
	45:  C1 = -32'sd399;
	46:  C1 = 32'sd1892;
	47:  C1 = -32'sd1702;
	
	48:  C1 = 32'sd1448;
	49:  C1 = -32'sd1702;
	50:  C1 = 32'sd783;
	51:  C1 = 32'sd399;
	52:  C1 = -32'sd1448;
	53:  C1 = 32'sd2008;
	54:  C1 = -32'sd1892;
	55:  C1 = 32'sd1137;
	
	56:  C1 = 32'sd1448;
	57:  C1 = -32'sd2008;
	58:  C1 = 32'sd1892;
	59:  C1 = -32'sd1702;
   60:  C1 = 32'sd1448;
   61:  C1 = -32'sd1137;
   62:  C1 = 32'sd783;
   63:  C1 = -32'sd399;
	endcase
end


// assign c2 value
always_comb begin
	case(c2_index)
	0:   C2 = 32'sd1448;   
	1:   C2 = 32'sd2008;   
	2:   C2 = 32'sd1892;   
	3:   C2 = 32'sd1702;   
	4:   C2 = 32'sd1448;   
	5:   C2 = 32'sd1137;  
	6:   C2 = 32'sd783;   
	7:   C2 = 32'sd399;  
	
	8:   C2 = 32'sd1448;
	9:   C2 = 32'sd1702;
	10:  C2 = 32'sd783;
	11:  C2 = -32'sd399;   
	12:  C2 = -32'sd1448;
	13:  C2 = -32'sd2008;
	14:  C2 = -32'sd1892;
	15:  C2 = -32'sd1137;
	
	16:  C2 = 32'sd1448;
	17:  C2 = 32'sd1137;
	18:  C2 = -32'sd783;
	19:  C2 = -32'sd2008;
	20:  C2 = -32'sd1448;
	21:  C2 = 32'sd399;
	22:  C2 = 32'sd1892;
	23:  C2 = 32'sd1702;
	
	24:  C2 = 32'sd1448;
	25:  C2 = 32'sd399;
	26:  C2 = -32'sd1892;
	27:  C2 = -32'sd1137;
	28:  C2 = 32'sd1448;
	29:  C2 = 32'sd1702;
	30:  C2 = -32'sd783;
	31:  C2 = -32'sd2008;
	
	32:  C2 = 32'sd1448;
	33:  C2 = -32'sd399;
	34:  C2 = -32'sd1892;
	35:  C2 = 32'sd1137;
	36:  C2 = 32'sd1448;
	37:  C2 = -32'sd1702;
	38:  C2 = -32'sd783;
	39:  C2 = 32'sd2008;
	
	40:  C2 = 32'sd1448;
	41:  C2 = -32'sd1137;
	42:  C2 = -32'sd783;
	43:  C2 = 32'sd2008;
	44:  C2 = -32'sd1448;
	45:  C2 = -32'sd399;
	46:  C2 = 32'sd1892;
	47:  C2 = -32'sd1702;
	
	48:  C2 = 32'sd1448;
	49:  C2 = -32'sd1702;
	50:  C2 = 32'sd783;
	51:  C2 = 32'sd399;
	52:  C2 = -32'sd1448;
	53:  C2 = 32'sd2008;
	54:  C2 = -32'sd1892;
	55:  C2 = 32'sd1137;
	
	56:  C2 = 32'sd1448;
	57:  C2 = -32'sd2008;
	58:  C2 = 32'sd1892;
	59:  C2 = -32'sd1702;
   60:  C2 = 32'sd1448;
   61:  C2 = -32'sd1137;
   62:  C2 = 32'sd783;
   63:  C2 = -32'sd399;
	endcase
end

				

endmodule