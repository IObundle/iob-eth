`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input             rst,
                  input [10:0]      nbytes,
                  input             receive,

                  //TODO: add sync
		  output reg        ready,

		  //RX_CLK domain
		  output reg [10:0] addr,
		  output [7:0]      data,
		  output reg        wr,

		  input [47:0]      mac_addr,

		  input             RX_CLK,
		  input             RX_DV,
		  input [3:0]       RX_DATA
		  );

   //rx reset
   reg 						   rx_rstn, rx_rstn_1;

   //state
   reg [2:0] 					   pc;
   reg [47:0]                                      dest_mac_addr;
   reg                                             rcvd;
   
   //data
   reg [3:0]                                       rx_nibble, rx_nibble_reg;
   reg [1:0]                                       rx_dv;

   //crc
   wire [31:0] 					   crc_value;


   //received data byte
   assign data = {rx_nibble, rx_nibble_reg};
   

   //
   // RECEIVER STATE MACHINE
   //
   always @(negedge RX_CLK, negedge rx_rstn)

      if(!rx_rstn) begin

         pc <= 0;
         addr <= 0;
         rcvd <= 0;
         dest_mac_addr  <= 0;
         wr <= 0;
         

      end else if (rx_dv[1]) begin
 
         pc <= pc+1;
         addr <= addr + pc[0];
         wr <= 0;
         
         case(pc)
           
	   0 : if(data != 8'hD5)
             pc <= pc;
    
           1: begin
              wr <= 1;
              addr <= 0;
           end

           2: dest_mac_addr <= {dest_mac_addr[40:0], data};
          
           3: begin
              wr <= 1;
              if(addr != 5) 
                pc <= pc-1;
           end
           
           4: if(dest_mac_addr != mac_addr) begin
              pc <= 0;
              addr <= 0;
           end
           
           5: if(addr != (17+nbytes)) begin
              wr <= 1;
              pc <= pc - 1;
           end else begin
              wr <= 0;
              pc <= 0;
              addr <= 0;
              rcvd <= 1;
           end
 
           default: ;
           
         endcase
      end // if (rx_dv[1])
   
   //check FCS and manage ready
   always @(negedge RX_CLK, negedge rx_rstn)
      if(!rx_rstn)
        ready <= 0;
      else if(!ready && rcvd && crc_value == 32'hC704DD7B)
        ready <=1;
      else if(ready && receive)
        ready <= 0;
      
   // capture nibble
   always @(negedge RX_CLK, negedge rx_rstn)
     if(~rx_rstn) begin
        rx_nibble <= 0;
        rx_nibble_reg <= 0;
        rx_dv <= 2'b0;
     end else if(RX_DV) begin
        rx_nibble_reg <= rx_nibble;
        rx_nibble <= RX_DATA;
        rx_dv <= {rx_dv[0], RX_DV};
     end else
        rx_dv <= {rx_dv[0], 1'b0};
   
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
		      .clk(~RX_CLK),
		      .start(pc == 0),
		      .data_in(data),
		      .data_en(wr),
		      .crc_out(crc_value)
		      );

endmodule
