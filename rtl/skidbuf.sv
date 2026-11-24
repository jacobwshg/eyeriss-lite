
module skidbuf
#(
	parameter DWIDTH = 16
)(
	input  logic clk,
	input  logic rst,

	// Upstream ( producer )
	input  logic i_up_valid,
	input  logic [ DWIDTH-1:0 ] din,
	output logic o_ready,

	// Downstream ( consumer )
	input  logic i_dn_ready,
	output logic [ DWIDTH-1:0 ] dout,
	output logic o_valid
);

	typedef enum logic [ 2:0 ]
	{
		S_EMPTY, S_HALF_FULL, S_FULL
	} fsm_state_t;

	fsm_state_t
		//fsm_state,
		fsm_state_r;

	logic [ DWIDTH-1:0 ] main_r, skid_r;
	logic valid, ready;

	always_ff @ ( posedge clk )
	if ( rst )
	begin
		fsm_state_r <= S_EMPTY;
		main_r <= 'h0;
		skid_r <= 'h0;
	end
	else
	begin
		case ( fsm_state_r )
			S_EMPTY:
			begin
				if ( i_up_valid )
				begin
					main_r <= din;
					fsm_state_r <= S_HALF_FULL;	
				end
			end

			S_HALF_FULL:
			begin
				if ( i_up_valid && i_dn_ready )
				begin
					main_r <= din;
				end
				else if ( i_up_valid && !i_dn_ready )
				begin
					skid_r <= din;
					fsm_state_r <= S_FULL;
				end
				else if ( i_dn_ready && !i_up_valid )
				begin
					fsm_state_r <= S_EMPTY;
				end
			end

			S_FULL:
			begin
				if ( i_dn_ready )
				begin
					main_r <= skid_r;
					fsm_state_r <= S_HALF_FULL;
				end
			end

			default:
			begin
				fsm_state_r <= S_EMPTY;
			end
		endcase
	end

	assign dout = main_r;
	assign o_ready = ( fsm_state_r !== S_FULL );
	assign o_valid = ( fsm_state_r !== S_EMPTY );

endmodule: skidbuf

