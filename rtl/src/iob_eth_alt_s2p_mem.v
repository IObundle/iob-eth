`timescale 1ns / 1ps

module iob_eth_alt_s2p_mem #(
		      parameter DATA_W=32, 
		      parameter ADDR_W=11
		      ) 
   (		    
    input [(DATA_W-1):0]      data_a,
    input [(ADDR_W-1):0]      addr_a, addr_b,
    input                     we_a, 
    input                     clk_a, clk_b,
    output reg [(DATA_W-1):0] q_b
		    );
   
   // Declare the RAM 
   reg [DATA_W-1:0] 			       ram[2**ADDR_W-1:0];
   reg [ADDR_W-1:0]                            addr_b_reg;
   
   // Port A (write)
   always @ (posedge clk_a)
     if (we_a)
       ram[addr_a] <= data_a;

   // Port b (read)
   always @ (posedge clk_b)
     begin
	q_b <= ram[addr_b_reg];
        addr_b_reg <= addr_b;
     end

 endmodule
