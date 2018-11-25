`timescale 1ns / 1ps

module iob_eth_alt_t2p_mem #(
		      parameter DATA_W=32, 
		      parameter ADDR_W=11
		      ) 
   (		    
    input [(DATA_W-1):0] 	  data_a, data_b,
    input [(ADDR_W-1):0] 	  addr_a, addr_b,
    input 			  we_a, we_b, clk,
    output reg [(DATA_W-1):0] q_a, q_b
		    );
   
   // Declare the RAM 
   reg [DATA_W-1:0] 			       ram[2**ADDR_W-1:0];

   always @ (posedge clk)
     begin // Port A
	if (we_a)
	  begin
	     ram[addr_a] <= data_a;
	     q_a <= data_a;
	  end
	else
	  q_a <= ram[addr_a];
     end
   always @ (posedge clk)
     begin // Port b
	if (we_b)
	  begin
	     ram[addr_b] <= data_b;
	     q_b <= data_b;
	  end
	else
	  q_b <= ram[addr_b];
     end

 endmodule
