`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx #(
                     parameter ETH_MAC_ADDR = `ETH_MAC_ADDR
                  ) (

                  //async reset 
		  input             rst,

                  //system clock domain
                  input [10:0]      nbytes,
                  input             rcv_ack,
		  output reg        data_rcvd,

		  //RX_CLK domain
		  output reg [10:0] addr,
		  output reg [7:0]  data,
		  output reg        wr,
                  output [31:0]     crc_value,
                  
		  input             RX_CLK,
		  input             RX_DV,
		  input [3:0]       RX_DATA
		  );

   //rx reset
   reg [1:0]                        rx_rst;

   //state
   reg [2:0]                        pc;
   reg [47:0]                       dest_mac_addr;
   
   //data
   wire [7:0]                       data_int;

   //receive ack
   reg [1:0]                        rcv_ack_sync;

   reg [10:0]                       nbytes_eth[1:0];
   
   
   //SYNCHRONIZERS   

   //reset sync
   always @ (posedge RX_CLK, posedge rst)
     if(rst)
       rx_rst <= 2'b11;
     else
       rx_rst <= {rx_rst[0], 1'b0};

   //receive ack preset 
   always @(posedge RX_CLK, posedge rcv_ack)
     if(rcv_ack)
       rcv_ack_sync <= 2'b11;
     else
       rcv_ack_sync <= {rcv_ack_sync[0], 1'b0};

   //number of bytes to receive
   always @(posedge RX_CLK) begin
      nbytes_eth[0] <= nbytes;
      nbytes_eth[1] <= nbytes_eth[0];
   end


   //
   // RECEIVER PROGRAM
   //
   always @(posedge RX_CLK, posedge rx_rst[1])

      if(rx_rst[1]) begin
         pc <= 0;
         addr <= 0;
         dest_mac_addr <= 0;
         wr <= 0;
         data_rcvd <= 0;
      end else begin
 
         pc <= pc+1'b1;
         addr <= addr + pc[0];
         wr <= 0;

         case(pc)
           
           0 : if(data_int != 8'hD5)
              pc <= pc;
           
           1: addr <= 0;

           2: begin
              dest_mac_addr <= {dest_mac_addr[39:0], data_int};
              wr <= 1;
           end
           
           3: if(addr != 5) 
             pc <= pc-1'b1;
           else if (dest_mac_addr != ETH_MAC_ADDR) begin
              pc <= 0;
           end
           
           4: wr <= 1;
           
           5: if(addr != (17+nbytes_eth[1])) begin
              pc <= pc - 1'b1;
           end
           
           6: begin
              pc <= pc;
              data_rcvd <= 1;
              if(rcv_ack_sync[1]) begin
                 pc <= 0;
                 addr <= 0;
                 data_rcvd <= 0;
              end
           end
           
           default: ;
           
         endcase
      end

   
   //capture RX_DATA
   assign data_int = {RX_DATA, data[7:4]};
   always @(posedge RX_CLK, posedge rx_rst[1])
     if(rx_rst[1])
       data <= 0;
     else if (RX_DV)
       data <= data_int;

   //
   // CRC MODULE
   //
  iob_eth_crc crc_rx (
		      .rst(rx_rst[1]),
		      .clk(RX_CLK),
		      .start(pc == 0),
		      .data_in(data),
		      .data_en(wr),
		      .crc_out(crc_value)
		      );

endmodule
