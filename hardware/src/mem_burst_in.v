`timescale 1ns/1ps

// After asserting run, it outputs a burst of data coming from a memory block with a one cycle read latency (data <= block[addr])
// It uses the simple valid & ready mechanism to synchronize the burst transfer.
module mem_burst_in #(
		parameter DATA_W = 32,
		parameter ADDR_W = 9
	)
	(
		// Burst configuration
		input [ADDR_W-1:0] start_addr,

		// After asserting start, start_addr is sampled
		input start,

		// Simple interface for data_in (ready = 1)
		input [DATA_W-1:0] data_in,
		input valid,

		// Connect to memory unit
		output reg [DATA_W-1:0] data,
		output reg [ADDR_W-1:0] addr,
		output reg write,

		// System connection
		input clk,
		input rst
	);

reg increment_addr;

always @(posedge clk,posedge rst)
begin
	if(rst) begin
		addr <= 0;
		data <= 0;
		write <= 0;
		increment_addr <= 0;
	end else begin
		write <= 0;
		increment_addr <= 0;

		if(start)
			addr <= start_addr;

		if(increment_addr)
			addr <= addr + 1;

		if(valid) begin
			data <= data_in;
			increment_addr <= 1'b1;
			write <= 1;
		end
	end
end

endmodule