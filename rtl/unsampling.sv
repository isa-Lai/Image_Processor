`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module unsampling(
		input logic CLOCK_50_I,
		input logic resetn,
		input logic enable,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic [17:0] SRAM_address,
		output logic SRAM_we_n,
		output logic finish
		
);
// milestone 1 states
enum logic [4:0]{
	IDLE,
	I0,I1,I2,I3,I4,I5,I6,I7,
	L0,L1,L2,L3,L4,L5,L6,L7,L8,
	F0,F1,F2,F3,F4,F5,F6

}upsample_state;
// offset parameters
parameter U_offset = 18'd38400,
		V_offset = 18'd57600;

logic [7:0] Y;
logic [7:0] U [5:0];
logic [7:0] V [5:0];
logic [7:0] Y_buf;
logic [7:0] U_buf;
logic [7:0] V_buf;

logic signed[31:0] U_un;
logic signed[31:0] V_un;

logic [31:0] R;
logic [31:0] G;
logic [31:0] B;
logic [7:0] R_out;
logic [7:0] G_out;
logic [7:0] B_out;
logic [7:0] B_buf;

logic signed[31:0] mul1;
logic signed[31:0] mul2; 
logic signed[31:0] op11;
logic signed[31:0] op12; 
logic signed[31:0] op21;
logic signed[31:0] op22; 

logic [17:0] y_counter;
logic [17:0] uv_counter;
logic [17:0] rgb_counter;
logic [17:0] row_counter;
logic isfirst;


always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		//output
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		SRAM_we_n <= 1'd1;
		finish <= 1'd0;
		//parameters
		Y <= 8'd0;
		U[0] <= 8'd0;
		U[1] <= 8'd0;
		U[2] <= 8'd0;
		U[3] <= 8'd0;
		U[4] <= 8'd0;
		U[5] <= 8'd0;
		V[0] <= 8'd0;
		V[1] <= 8'd0;
		V[2] <= 8'd0;
		V[3] <= 8'd0;
		V[4] <= 8'd0;
		V[5] <= 8'd0;
		
		Y_buf <= 8'd0;
		U_buf <= 8'd0;
		V_buf <= 8'd0;
		R <= 32'd0;
		G <= 32'd0;
		B <= 32'd0;
		B_buf <= 8'd0;
		U_un <= 32'b0;
		V_un <= 32'b0;
		
		op11 <= 32'd0;
		op12 <= 32'd0;
		op21 <= 32'd0;
		op22 <= 32'd0;
		
		y_counter <= 18'd0;
		uv_counter <= 18'd0;
		row_counter <= 18'd0;
		rgb_counter <= 18'd146944;
		
		isfirst = 1'b0;
		
		upsample_state <= IDLE;
	end
	else if(enable)  begin
		case(upsample_state)
//--------------------------Wait to start--------------------------//
		IDLE: begin
			//initial parameters
			y_counter <= 18'd0;
			uv_counter <= 18'd0;
			row_counter <= 18'd0;
			rgb_counter <= 18'd146944;
			SRAM_address <= 18'd0;
			SRAM_we_n <= 1'd1;
			finish <= 1'd0;
			isfirst = 1'b0;
			U_un <= 32'b0;
			V_un <= 32'b0;
			
			//check start
			//if(enable) begin
				upsample_state <= I0;
			//end
		end
//--------------------------Beginning of each row --------------------------//
		I0: begin
			//read v0v2
			SRAM_address <= uv_counter + V_offset;
			SRAM_we_n <= 1'b1;
			isfirst = 1'b0;
			
			upsample_state <= I1;
		end
		I1: begin
			//read u0u2
			SRAM_address <= uv_counter + U_offset;
			
			upsample_state <= I2;
		end
		I2: begin
			//read Y1Y0
			SRAM_address <= y_counter;
			uv_counter <= uv_counter + 18'b1;
			y_counter <= y_counter + 18'd1;
		
			upsample_state <= I3;
		end
		I3: begin
			//read V4V6
			SRAM_address <= uv_counter + V_offset;
			
			
			//put V0V2
			V[0] <= SRAM_read_data[15:8]; //V0
			V[1] <= SRAM_read_data[15:8];
			V[2] <= SRAM_read_data[15:8];
			V[3] <= SRAM_read_data[7:0];  //V2
			V_un <= {24'd0, SRAM_read_data[15:8]};
			
			upsample_state <= I4;
		end
		I4: begin
			//read U4U6
			SRAM_address <= uv_counter + U_offset;
			uv_counter <= uv_counter + 18'd1;
			
			//put U0U2
			U[0] <= SRAM_read_data[15:8]; //U0
			U[1] <= SRAM_read_data[15:8];
			U[2] <= SRAM_read_data[15:8];
			U[3] <= SRAM_read_data[7:0];  //U2
			U_un <= {24'd0, SRAM_read_data[15:8]};
			
			//cal rg at v
			op11 <= 32'd104595;
			op12 <= V_un - 32'd128;
			op21 <= 32'd53281;
			op22 <= V_un  - 32'd128;
			
			upsample_state <= I5;
		end
		I5: begin
			//put Y0Y1
			Y <= SRAM_read_data[15:8]; //y0
			Y_buf <= SRAM_read_data[7:0]; //y1
			
			//cal rg
			op11 <= 32'd76284;
			op12 <= {24'd0, SRAM_read_data[15:8]}  - 32'd16; //y0-16
			op21 <= 32'd25624;
			op22 <= U_un  - 32'd128;
			
			//put product
			R <= mul1;
			G <= 32'd0 - mul2; //g-53281v
			
			upsample_state <= I6;
		end
		I6: begin
			// put product
			R <= R + mul1;
			G <= G + mul1 - mul2; //g+76284y-25624u
			B <= mul1;
			
			//cal B and V[j-1]
			op11 <= 32'd132251;
			op12 <= U_un  - 32'd128; //B0
			op21 <= 32'd159;
			op22 <= V[2] + V[3];
			
			//put V4V6
			V[4] <= SRAM_read_data[15:8]; //V4
			V[5] <= SRAM_read_data[7:0]; //V6
			
			upsample_state <= I7;
		end
		I7: begin
			//put U4U6
			U[4] <= SRAM_read_data[15:8]; //U4
			U[5] <= SRAM_read_data[7:0]; //u6
			
			// put product
			B <= B + mul1;
			V_un <= mul2;
			
			// cal V[j-5] V[j-3}
			op11 <= 32'd52;
			op12 <= V[1] + V[4]; 
			op21 <= 32'd21;
			op22 <= V[0] + V[5];
			
			// initialize next write
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_out,G_out}; //R0G0
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			
			upsample_state <= L0;
		end
//--------------------------Loop normal case --------------------------//
		L0: begin
			// read y2y3
			SRAM_we_n <= 1'b1;
			SRAM_address <= y_counter; //Y2Y3
			y_counter <= y_counter + 18'd1;
		
			// put product
			V_un <= V_un - mul1 + mul2 + 32'd128;
		
			// cal
			op11 <= 32'd159;
			op12 <= U[2] + U[3];
			op21 <= 32'd52;
			op22 <= U[1] + U[4];
			
			//buf b
			B_buf <= B_out; // dont need shift, just take the 16-23 bits
			
			
			upsample_state <= L1;
		
		end
		L1: begin
			// read V8V10
			SRAM_address <= uv_counter + V_offset;
			
			//put product
			U_un <= mul1 - mul2 + 32'd128;
			V_un <= V_un >>>8; //1/128
			
			//calculate
			op11 <= 32'd76284;
			op12 <= {24'd0, Y_buf} - 32'd16;
			op21 <= 32'd21;
			op22 <= U[0] + U[5];
			
			
			upsample_state <= L2;
			
		
		end
		L2: begin
			// read U8U10
			SRAM_address <= uv_counter + U_offset;
			// dont need to read at the second time
			if(!isfirst & (y_counter - row_counter < 18'd157)) begin
				uv_counter <= uv_counter + 18'd1;
			end
			
			//put product
			R <= mul1;
			G <= mul1;
			B <= mul1;
			U_un <= U_un +mul2>>>8;
			
			// multiply 
			op11 <= 32'd104595;
			op12 <= V_un  - 32'd128;
			op21 <= 32'd25624;
			op22 <=(U_un +mul2>>>8)   - 32'd128;
			
			upsample_state <= L3;
		
		end
		L3: begin
			// put y2y3
			Y <= SRAM_read_data[15:8]; //y2
			Y_buf <= SRAM_read_data[7:0]; //y3
			
			//put pruduct
			R <= R + mul1;
			G <= G - mul2;
			
			//cal
			op11 <= 32'd53281;
			op12 <= V_un   - 32'd128;
			op21 <= 32'd132251;
			op22 <= U_un   - 32'd128;
			upsample_state <= L4;
			
			
		end
		L4: begin
			
			//put prod
			G <= G - mul1;
			B <= B + mul2;
			
			// write B0R1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter +18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_buf,R_out};
			
			//shift value in  v
			V[0] <= V[1];
			V[1] <= V[2];
			V[2] <= V[3];
			V[3] <= V[4];
			V[4] <= V[5];
			V_un <= V[3]; //prepare even calculation
			//at the second time not buf and read from buf
			// if uv reach the end of each line also read from buf
			if(!isfirst & (y_counter - row_counter < 18'd157)) begin
				V[5] <= SRAM_read_data[15:8];//V8
				V_buf <= SRAM_read_data[7:0]; //v10
			end else begin
				V[5] <= V_buf;//V10 / always the last read V
			end
			upsample_state <= L5;
			
			
		end
		L5: begin
			//cal
			op11 <= 32'd104595;
			op12 <= V_un  - 32'd128;
			op21 <= 32'd53281;
			op22 <= V_un   - 32'd128;
			
			// write G1B1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter +18'd1;
			SRAM_write_data <= {G_out,B_out};
			
			//shift value in  u
			U[0] <= U[1];
			U[1] <= U[2];
			U[2] <= U[3];
			U[3] <= U[4];
			U[4] <= U[5];
			U_un <= U[3]; //prepare even calculation
			//at the second time not buf and read from buf
			if(!isfirst & (y_counter - row_counter < 18'd157)) begin
				U[5] <= SRAM_read_data[15:8] ;//u8
				U_buf <= SRAM_read_data[7:0]; //u10
			end else begin
				U[5] <= U_buf; //u10 / always the last read U
			end
			upsample_state <= L6;
		end
		L6: begin
			SRAM_we_n <= 1'b1;
			//cal rg
			op11 <= 32'd76284;
			op12 <= {24'd0, Y}   - 32'd16; //y0-16
			op21 <= 32'd25624;
			op22 <= U_un   - 32'd128;
			
			//put product
			R <= mul1;
			G <= 32'd0 - mul2; //g-53281v
			
			upsample_state <= L7;
		end
		L7: begin
			// put product
			R <= R + mul1;
			G <= G + mul1 - mul2; //g+76284y-25624u
			B <= mul1;
			
			//cal B and V[j-1]
			op11 <= 32'd132251;
			op12 <= U_un   - 32'd128; //B0
			op21 <= 32'd159;
			op22 <= V[2] + V[3];
			
			upsample_state <= L8;
		end
		L8: begin
			// put product
			B <= B + mul1;
			V_un <= mul2;
			
			// cal V[j-5] V[j-3}
			op11 <= 32'd52;
			op12 <= V[1] + V[4]; 
			op21 <= 32'd21;
			op22 <= V[0] + V[5];
			
			// initialize next write
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {R_out,G_out}; //R0G0
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter + 18'd1;
			
			//swirch is first
			isfirst <= isfirst ^ 1'b1;
			if(y_counter - row_counter < 18'd160) begin
				upsample_state <= L0;
			end
			else begin
				row_counter = row_counter + 18'd160;
				upsample_state <= F0;//if almost reach the end of line
			end
		end
//--------------------------End of each row --------------------------//
		F0: begin
			SRAM_we_n <= 1'b1;
			// put product
			V_un <= V_un - mul1 + mul2 + 32'd128;
		
			// cal
			op11 <= 32'd159;
			op12 <= U[2] + U[3];
			op21 <= 32'd52;
			op22 <= U[1] + U[4];
			
			//buf b
			B_buf <= B_out; 
			
			
			upsample_state <= F1;
		end
		F1: begin
			//put product
			U_un <= mul1 - mul2 + 32'd128;
			V_un <= V_un>>>8;
			
			//calculate
			op11 <= 32'd76284;
			op12 <= {24'd0, Y_buf}   - 32'd16;
			op21 <= 32'd21;
			op22 <= U[0] + U[5];
			
			
			upsample_state <= F2;
		end
		F2: begin
			//put product
			R <= mul1;
			G <= mul1;
			B <= mul1;
			U_un <= U_un +mul2>>>8;
			
			// multiply 
			op11 <= 32'd104595;
			op12 <= V_un  - 32'd128;
			op21 <= 32'd25624;
			op22 <= (U_un +mul2>>>8)   - 32'd128;
			
			upsample_state <= F3;
		end
		F3: begin
			//put pruduct
			R <= R + mul1;
			G <= G - mul2;
			
			//cal
			op11 <= 32'd53281;
			op12 <= V_un   - 32'd128;
			op21 <= 32'd132251;
			op22 <= U_un   - 32'd128;
			upsample_state <= F4;
		end
		F4: begin
			//put prod
			G <= G - mul1;
			B <= B + mul2;
			
			// write B0R1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter +18'd1;
			SRAM_we_n <= 1'b0;
			SRAM_write_data <= {B_buf,R_out};
			
			upsample_state <= F5;
		end
		F5: begin
			// write G1B1
			SRAM_address <= rgb_counter;
			rgb_counter <= rgb_counter +18'd1;
			SRAM_write_data <= {G_out,B_out};
			
			if(y_counter < 18'd38400) begin
				upsample_state <= I0;
			end
			else begin
				upsample_state <= F6;
				finish <= 1'b1;
			end
		end
//-------------finisiing MS1------------
		F6: begin
			upsample_state <= IDLE;
		end
		default: upsample_state <= IDLE;
		endcase
	end
end

// assign the multiplyer
assign mul1 = op11*op12;
assign mul2 = op21*op22;

// assign the signbit clip
assign R_out = R[31] ? 8'b0 :(|R[30:24]? 8'd255:R[23:16]);
assign G_out = G[31] ? 8'b0 :(|G[30:24]? 8'd255:G[23:16]);
assign B_out = B[31] ? 8'b0 :(|B[30:24]? 8'd255:B[23:16]);
endmodule