`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input             rst,

		   //phy side
		  input             RX_CLK,
		  input             RX_DV,
		  input [3:0]       RX_DATA,

		   //cpu_side
		  output reg [10:0] addr,
		  output [7:0]      data,
		  output            wr,

		  input [47:0]      mac_addr,
                  input             receive,
        
		  //status
		  output reg        ready
		  );

   //rx reset
   reg 						   rx_rstn, rx_rstn_1;

   //state
   reg [3:0] 					   pc;
   reg [47:0]                                      dest_mac_addr;

   //rx nibble
   reg [3:0]                                       rx_nibble, rx_nibble_reg;
   
   //crc
   wire [31:0] 					   crc_value;


   //received data byte
   assign data = {rx_nibble, rx_nibble_reg};
   

   //
   // RECEIVER STATE MACHINE
   //
   always @(negedge RX_CLK, negedge rx_rstn)

      if(~rx_rstn) begin

         pc <= 0;
         addr <= 0;
         ready <= 0;
         dest_mac_addr  <= 0;

      end else if (RX_DV) begin
 
         pc <= pc+1;
         addr <= addr + pc[0];
         
         case(pc)
	   0 : if(data != 8'hD5)
              pc <= pc;
    
           1: ;
           

           2: dest_mac_addr <= {data, dest_mac_addr[47:8]};
          
           3: if(addr != 6)
             pc <= pc-1;
           
           4: if(dest_mac_addr != mac_addr) begin
              pc <= 0;
              addr <= 0;
           end
           
           5: if(addr != 14)
             pc <= pc-1;

           6:;

           7: if(addr != (14+`ETH_SIZE+4))
             pc <= pc - 1;
           else 
             addr <= 0;

           default: begin
              pc <= 0;
              addr <= 0;
              ready <= 0;
           end
         endcase 
      end else begin // if (RX_DV)
         case (pc)
           8: if(!crc_value)
               ready <= 1;
             else begin
                pc <= 0;
                addr <= 0;
             end
           9: begin
              ready <= 1;
              if(!receive)
                pc <= pc;
              else begin
                 pc <= 0;
                 addr <= 0;
                 ready <= 0;
              end
           end
           default: begin
              pc <= 0;
              addr <= 0;
              ready <= 0;
           end
         endcase // case (pc)
      end // else: !if(RX_DV)

   assign wr = (!pc && data == 8'hD5 || pc && !pc[0]);
   
   // capture nibble
   always @(negedge RX_CLK, negedge rx_rstn)
     if(~rx_rstn) begin
        rx_nibble <= 0;
        rx_nibble_reg <= 0;
     end else if(RX_DV) begin
        rx_nibble_reg <= rx_nibble;
        rx_nibble <= RX_DATA;
     end
   
   //reset sync
   always @ (posedge rst, negedge RX_CLK)
     if(rst) begin
	rx_rstn <= 1'b0;
	rx_rstn_1 <= 1'b0;
     end else begin
	rx_rstn <= rx_rstn_1;
	rx_rstn_1 <= 1'b1;
     end


   //
   // CRC MODULE
   //
  iob_eth_crc crc_rx (
		      .rst(~rx_rstn),
		      .clk(RX_CLK),
		      .start(pc == 0),
		      .data_in(data),
		      .data_en(wr),
		      .crc_out(crc_value)
		      );

endmodule
