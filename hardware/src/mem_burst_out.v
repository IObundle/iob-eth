`timescale 1ns/1ps

// After asserting run, it outputs a burst of data coming from a memory block with a one cycle read latency (data <= block[addr])
// It uses the simple valid & ready mechanism to synchronize the burst transfer.
module mem_burst_out #(
		parameter DATA_W = 32,
		parameter ADDR_W = 8
	)
	(
		// Burst configuration
		input [ADDR_W-1:0] start_addr,

		// After asserting start, start_addr and len are sampled and the bursting begins
		input start,

		// Connect to memory unit
		output reg [ADDR_W-1:0] addr,
		input [DATA_W-1:0]      data_in,

		// Simple interface for data_out
		output wire [DATA_W-1:0] data_out,
		output reg valid,
		input      ready,

		// System connection
		input clk,
		input rst
	);

reg init;
reg stored;
reg [DATA_W-1:0] storedData;

assign data_out = (stored ? storedData : data_in);

always @(posedge clk,posedge rst)
begin
	if(rst) begin
		valid <= 0;
		stored <= 0;
		addr <= 0;
		init <= 0;
		storedData <= 0;
	end	else begin
		if(valid) begin
			if(ready) begin
				addr <= addr + 1;

				if(stored) begin
					stored <= 1'b0;
					storedData <= 0;
				end
			end else if(!stored) begin
				stored <= 1'b1;
				storedData <= data_in;
			end
		end

		if(init) begin
			valid <= 1'b1;
			init <= 1'b0;
			addr <= addr + 1;
		end else if(start) begin
			init <= 1'b1;
			addr <= start_addr;
			valid <= 0;
			stored <= 0;
			storedData <= 0;
		end
	end
end

endmodule