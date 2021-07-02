`timescale 1ns/1ps

`include "iob_eth_defs.vh"

// A 32 bit made by joining 4x8 byte memories.
// It implements a wstrb
module eth_mem (
	    input clk_a,
	    input [8:0]  addr_a,
      input [31:0] data_a,
      input [3:0]  wstrb,
      input we_a,

      input clk_b, 
      input [8:0]   addr_b,
      output [31:0] data_b
	);

wire [7:0] data_b_part[3:0];

generate
	genvar i;

    for(i = 0; i < 4; i = i +1)
    begin
      iob_eth_alt_s2p_mem #(
                           .DATA_W(8),
                           .ADDR_W((`ETH_ADDR_W-1)-2)
                           )
      buffer
      (
          .clk_a(clk_a),
          .addr_a(addr_a),
          .data_a(data_a[8*i +: 8]),
          .we_a(we_a & wstrb[i]),

          .clk_b(clk_b),
          .addr_b(addr_b),
          .data_b(data_b_part[i])
      );

    assign data_b[i*8 +: 8] = data_b_part[i];
    end

endgenerate

endmodule