`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input         rst,

		   //phy side
		  input         RX_CLK,
		  input         RX_DV,
		  input [3:0]   RX_DATA,

		   //cpu_side
		  output [10:0] addr,
		  output [7:0]  data,
		  output reg    wr,

		  input [47:0]  mac_addr,

		  //status
		  output reg    ready
		  );

   //rx reset
   reg 						   rx_rstn, rx_rstn_1;

   //state
   reg [3:0] 					   pc;
   reg [10:0]                                      byte_cnt;
   reg [47:0]                                      dest_mac_addr;

   //rx nibble
   reg [3:0]                                       rx_nibble;
   
   //crc
   wire [31:0] 					   crc_value;

 
   assign data = {RX_DATA, rx_nibble};
   

   //
   // RECEIVER STATE MACHINE
   //
   always @(negedge RX_CLK, negedge rx_rstn)
      if(!rx_rstn) begin
         pc <= 0;
         byte_cnt <= 0;
         wr <=0;
      end else if (RX_DV) begin
         pc <= pc+1;
         wr <= pc[0];
         byte_cnt <= byte_cnt+pc[0];
         
         case(pc)
	   0 : if(data != 8'hD5)
             pc <= pc;

           1:;

           2: dest_mac_addr <= {data, dest_mac_addr >> 8};

           3: if(byte_cnt != 6)
             pc <= pc-1;
           else
             byte_cnt <= 0;
           
           4: if(dest_mac_addr != mac_addr)
             pc <= 0;
           
           5: if(byte_cnt != 8)
             pc <= pc-1;
           else
             byte_cnt <= 0;

           6:;

           7: if(byte_cnt != `ETH_SIZE)
             pc <= pc - 1;
           else begin
              byte_cnt <= 0;
              wr <= 0;
           end
           
           8: if(crc_value)
             pc <= 0;
           else begin
              ready <= 1;
              pc <= pc;
           end
           
           default:;
           
         endcase
      end 

   // capture nibble
   always @(negedge RX_CLK, negedge rx_rstn)
     if(!rx_rstn)
       rx_nibble <= 0;
     else if(RX_DV)
       rx_nibble <= RX_DATA;
   
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
		      .data_en(wr_en),
		      .crc_out(crc_value)
		      );

endmodule
