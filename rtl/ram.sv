
module ram
#(
	parameter int DWIDTH = 16,
	parameter int SIZE = 32,
	parameter int ADDR_WIDTH = $clog2( SIZE )
)(
	input  logic clk,

	input  logic wr_en,
	input  logic [ ADDR_WIDTH-1:0 ] wr_addr,
	input  logic [ DWIDTH-1:0 ] wr_data,

	input  logic rd_en,
	input  logic [ ADDR_WIDTH-1:0 ] rd_addr,
	output logic [ DWIDTH-1:0 ] rd_data
);

	logic [ DWIDTH-1:0 ] mem [ 0:SIZE-1 ];

	logic [ ADDR_WIDTH-1:0 ] rd_addr_r;

	always_ff @ ( posedge clk )
	begin
		if ( wr_en )
		begin
			mem[ wr_addr ] <= wr_data;
		end

		if ( rd_en )
		begin
			rd_addr_r <= rd_addr;
		end
	end

	assign rd_data = mem[ rd_addr_r ];

endmodule: ram

