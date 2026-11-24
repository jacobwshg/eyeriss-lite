
module pe_core
#(
	parameter int DWIDTH = 16,

	parameter int PSUM_COL_ID_WIDTH = 4,

	// TODO support variable product scaling
	parameter int PROD_SHAMT = 0
)(
	input  logic clk,
	input  logic rst,

	input  logic i_valid,
	input  logic [ DWIDTH-1:0 ] i_feat,
	input  logic [ DWIDTH-1:0 ] i_weight,
	input  logic [ PSUM_COL_ID_WIDTH-1:0 ] i_psum_col_id,
	/* Asserted when the product is the very initial one 
	 * to accumulate into the relevant psum */
	input  logic i_psum_acc_begin,
	/* Asserted when the product is the initial one in the 
 	 * psum window for the current ifmap/filter row */
	input  logic i_wnd_begin,
	/* Asserted when the product is the final one in the 
	 * psum window for the current row, requiring the psum 
	 * to be written back to spad */ 
	input  logic i_wnd_end,

	// from psum spad
	input  logic i_psum_spad_dout,
	// to psum spad
	output logic [ PSUM_COL_ID_WIDTH-1:0 ] o_psum_spad_rd_addr,
	output logic o_psum_rd_en,

	output logic o_valid,
	output logic [ DWIDTH-1:0 ] o_psum,
	output logic [ PSUM_COL_ID_WIDTH-1:0 ] o_psum_spad_wr_addr,
	output logic o_psum_spad_wr_en
);

	/* Stage 1: Register operands ( read from ifmap and filter spad ) */
	logic valid_1_r;
	logic [ DWIDTH-1:0 ] feat_r;
	logic [ DWIDTH-1:0 ] weight_r;
	logic [ PSUM_COL_ID_WIDTH-1:0 ] psum_col_id_1_r;
	logic psum_acc_begin_1_r;
	logic wnd_begin_1_r;
	logic wnd_end_1_r;

	/* Stage 2: Run multiply and clock psum reload addr in spad as needed */
	logic valid_2_r;
	logic [ DWIDTH*2-1:0 ] prod_1_r;
	// psum col ID will also clock into psum spad if non-initial row window begin
	logic [ PSUM_COL_ID_WIDTH-1:0 ] psum_col_id_2_r;
	logic psum_acc_begin_2_r;
	logic wnd_begin_2_r;
	logic wnd_end_2_r;

	/* Stage 3: Run multiply and register reloaded psum */
	logic valid_3_r;
	logic [ DWIDTH*2-1:0 ] prod_2_r;
	logic [ DWIDTH-1:0 ] psum_spad_dout_r;
	logic [ PSUM_COL_ID_WIDTH-1:0 ] psum_col_id_3_r;
	logic psum_acc_begin_3_r;
	logic wnd_begin_3_r;
	logic wnd_end_3_r;

	/* Stage 4: Accumulate product into psum */
	// Updated psum
	logic [ DWIDTH*2-1:0 ] prod_sh;
	logic [ DWIDTH-1:0 ] psum_new;
	logic valid_4_r;
	logic [ DWIDTH-1:0 ] psum_r;
	logic [ PSUM_COL_ID_WIDTH-1:0 ] psum_col_id_4_r;
	logic wnd_end_4_r;

	// Outputs
	assign o_valid = valid_4_r;
	assign o_psum = psum_r;
	assign o_psum_spad_wr_addr = psum_col_id_4_r;
	assign o_psum_spad_wr_en = wnd_end_4_r;

	// If non-initial row window begin, need to reload psum as of previous
	// row 
	assign o_psum_spad_rd_addr = psum_col_id_1_r;
	assign o_psum_spad_rd_en = ( wnd_begin_1_r && !psum_acc_begin_1_r );

	always_ff @ ( posedge clk )
	begin: proc_valid_pipe
		if ( rst )
		begin
			{ valid_1_r, valid_2_r, valid_3_r, valid_4_r } <=
			{ 4{ 1'b0 } };
		end
		else
		begin
			{ valid_1_r, valid_2_r, valid_3_r, valid_4_r } <=
			{ i_valid,   valid_1_r, valid_2_r, valid_3_r };
		end
	end: proc_valid_pipe

	always_ff @ ( posedge clk )
	begin: proc_operands
		feat_r   <= i_feat;
		weight_r <= i_weight;
	end: proc_operands

	always_ff @ ( posedge clk )
	begin: proc_mul
		prod_1_r <= feat_r * weight_r;
		prod_2_r <= prod_1_r; // retime
	end: proc_mul

	always_ff @ ( posedge clk )
	begin: proc_sideband

		{ psum_col_id_1_r, psum_col_id_2_r, psum_col_id_3_r, psum_col_id_4_r } <=
        { i_psum_col_id,   psum_col_id_1_r, psum_col_id_2_r, psum_col_id_3_r };

		{ psum_acc_begin_1_r, psum_acc_begin_2_r, psum_acc_begin_3_r } <=
		{ i_psum_acc_begin,   psum_acc_begin_1_r, psum_acc_begin_2_r };

		{ wnd_begin_1_r, wnd_begin_2_r, wnd_begin_3_r } <=
		{ i_wnd_begin,   wnd_begin_1_r, wnd_begin_2_r };

		{ wnd_end_1_r, wnd_end_2_r, wnd_end_3_r, wnd_end_4_r } <=
		{ i_wnd_end,   wnd_end_1_r, wnd_end_2_r, wnd_end_3_r };

	end: proc_sideband

	always_comb
	begin: proc_psum_comb
		// Normal case ( window middle or end ): feedback
		psum_new = psum_r;
		if ( psum_acc_begin_3_r )
		begin
			// Accumulation begin: reset
			psum_new = 'h0;
		end
		else if ( wnd_begin_3_r )
		begin
			// Resume from prev row: use reloaded value
			psum_new = psum_spad_dout_r;
		end

		prod_sh = prod_2_r >> PROD_SHAMT;
		psum_new += prod_sh[ DWIDTH-1:0 ];

	end: proc_psum_comb

	always_ff @ ( posedge clk )
	begin: proc_psum_reg
		if ( wnd_begin_2_r && !psum_acc_begin_2_r )
		begin
			psum_spad_dout_r <= i_psum_spad_dout;
		end
		psum_r <= psum_new;
	end: proc_psum_reg

endmodule: pe_core

