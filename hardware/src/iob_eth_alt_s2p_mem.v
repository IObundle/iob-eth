`timescale 1ns / 1ps

module iob_eth_alt_s2p_mem #(
		      parameter DATA_W=32, 
		      parameter ADDR_W=11
		      ) 
   (		    
                    input                     clk_a,
                    input [(ADDR_W-1):0]      addr_a,
                    input [(DATA_W-1):0]      data_a,
                    input                     we_a, 

                    input                     clk_b,
                    input [(ADDR_W-1):0]      addr_b,
                    output reg [(DATA_W-1):0] data_b
		    );
   
   // The RAM 
   reg [DATA_W-1:0] 			       ram[2**ADDR_W-1:0];
   
   // Port A (write)
   always @ (posedge clk_a)
     if (we_a)
       ram[addr_a] <= data_a;

   // Port b (read)
   always @ (posedge clk_b)
	data_b <= ram[addr_b];


 endmodule
