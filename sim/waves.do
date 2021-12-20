# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {Top-level signals}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave UUT/top_state
add wave -uns UUT/UART_timer
add wave -uns UUT/switch_RAM
add wave -bin UUT/IDCT_oneblock_finish
add wave -bin UUT/decode_oneblock_finish

add wave -divider -height 10 {SRAM signals}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -bin UUT/SRAM_we_n
add wave -hex UUT/SRAM_read_data

add wave -divider -height 10 {Top Level Ram}
add wave -hex UUT/address_a
add wave -hex UUT/address_b
add wave -bin UUT/write_enable_a
add wave -bin UUT/write_enable_b
add wave -hex UUT/write_data_a
add wave -hex UUT/write_data_b
add wave -hex UUT/read_data_a
add wave -hex UUT/read_data_b

# wave for ms3
add wave -divider -height 10 {M3}
add wave -hex UUT/decode_block/block_col
add wave -hex UUT/decode_block/block_row
add wave -hex UUT/decode_block/decode_state
add wave -hex UUT/decode_block/zero_counter
add wave -hex UUT/decode_block/inblock_address
add wave -hex UUT/decode_block/decode_dir
add wave -hex UUT/decode_block/Q_index
add wave -hex UUT/decode_block/counter
add wave -hex UUT/decode_block/pointer
add wave -hex UUT/decode_block/decode_buf
add wave -hex UUT/decode_block/read_data_buf
add wave -hex UUT/decode_block/SRAM_address_buf
add wave -hex UUT/decode_block/W_address_buf


# wave for ms2
add wave -divider -height 10 {M2}
add wave -hex UUT/IDCT_block/SRAM_write_data
add wave -hex UUT/IDCT_block/block_col
add wave -hex UUT/IDCT_block/block_row
add wave -hex UUT/IDCT_block/IDCT_state
add wave -hex UUT/IDCT_block/inblock_address
add wave -hex UUT/IDCT_block/counter8
add wave -hex UUT/IDCT_block/isodd
add wave -hex UUT/IDCT_block/isfirst
add wave -hex UUT/IDCT_block/bufeven
add wave -hex UUT/IDCT_block/isfirstwrite
add wave -hex UUT/IDCT_block/address_0a
add wave -hex UUT/IDCT_block/address_0b
add wave -hex UUT/IDCT_block/write_data_0a
add wave -hex UUT/IDCT_block/write_data_b
add wave -hex UUT/IDCT_block/T
add wave -hex UUT/IDCT_block/address_1a
add wave -hex UUT/IDCT_block/address_1b
add wave -hex UUT/IDCT_block/address_2a
add wave -hex UUT/IDCT_block/address_2b
add wave -hex UUT/IDCT_block/write_enable_0a
add wave -hex UUT/IDCT_block/write_enable_b
add wave -hex UUT/IDCT_block/read_data_a_extra
add wave -hex UUT/IDCT_block/read_data_b_extra
add wave -hex UUT/IDCT_block/read_data_a
add wave -hex UUT/IDCT_block/read_data_b
add wave -hex UUT/IDCT_block/S_read_data_b_extra
add wave -hex UUT/IDCT_block/S_address_0b


# wave for ms1
add wave -divider -height 10 {M1}
add wave -hex UUT/unsampling_block/upsample_state
#add wave -hex UUT/unsampling_block/mul1
#add wave -hex UUT/unsampling_block/mul2
#add wave -hex UUT/unsampling_block/op11
#add wave -hex UUT/unsampling_block/op12
#add wave -hex UUT/unsampling_block/op21
#add wave -hex UUT/unsampling_block/op22
add wave -hex UUT/unsampling_block/R
add wave -hex UUT/unsampling_block/G
add wave -hex UUT/unsampling_block/B
add wave -hex UUT/unsampling_block/Y
add wave -hex UUT/unsampling_block/U
add wave -hex UUT/unsampling_block/V
add wave -hex UUT/unsampling_block/U_un
add wave -hex UUT/unsampling_block/V_un
add wave -hex UUT/unsampling_block/Y_buf
add wave -hex UUT/unsampling_block/U_buf
add wave -hex UUT/unsampling_block/V_buf
add wave -hex UUT/unsampling_block/isfirst


add wave -divider -height 10 {VGA signals}
add wave -bin UUT/VGA_unit/VGA_HSYNC_O
add wave -bin UUT/VGA_unit/VGA_VSYNC_O
add wave -uns UUT/VGA_unit/pixel_X_pos
add wave -uns UUT/VGA_unit/pixel_Y_pos
add wave -hex UUT/VGA_unit/VGA_red
add wave -hex UUT/VGA_unit/VGA_green
add wave -hex UUT/VGA_unit/VGA_blue

