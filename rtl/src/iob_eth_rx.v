`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input             rst,
                  input [10:0]      nbytes,
                  input             receive,
		  output reg        ready,

		  //RX_CLK domain
		  output reg [10:0] addr,
		  output reg [7:0]  data,
		  output reg        wr,
		  input             RX_CLK,
		  input             RX_DV,
		  input [3:0]       RX_DATA
		  );

   //rx reset
   reg [1:0]                        rx_rst;

   //state
   reg [2:0]                        pc;
   reg [47:0]                       dest_mac_addr;
   reg                              rcvd;
   
   //data
   reg                              RX_DV_reg;
   wire [7:0]                       data_int;
   
   //crc
   wire [31:0]                      crc_value;


   //
   // RECEIVER STATE MACHINE
   //
   always @(posedge RX_CLK, posedge rx_rst[1])

      if(rx_rst[1]) begin

         pc <= 0;
         addr <= 0;
         rcvd <= 0;
         dest_mac_addr  <= 0;
         wr <= 0;
         

      end else if (RX_DV_reg) begin
 
         pc <= pc+1'b1;
         addr <= addr + pc[0];
         wr <= 0;
         
         case(pc)
           
           //debug
           0 : if(data_int != 8'hD5) begin 
	   //0 : if(addr < nbytes) begin
              pc <= pc;
           end else                  
              wr <= 1;
           
           1:;

           2: begin
              dest_mac_addr <= {dest_mac_addr[39:0], data_int};
              wr <= 1;
           end
           
           3: begin
              if(addr != 6) 
                pc <= pc-1'b1;
           end
           
           4: if(dest_mac_addr == `ETH_MAC_ADDR) begin
              pc <= pc;
              wr <= 1;
              addr <= 0;
              //debug
              rcvd <= 1;
              
           end
           
           5: if(addr != (17+nbytes)) begin
              wr <= 1;
              pc <= pc - 1'b1;
           end else begin
              wr <= 0;
//              pc <= 0;
              pc <= pc;
//              addr <= 0;
              addr <= addr;
              rcvd <= 1;
           end
 
           default: ;
           
         endcase
      end
   
   //check FCS and manage ready
   always @(posedge RX_CLK, posedge rx_rst[1])
      if(rx_rst[1])
        ready <= 0;
      else if(!ready && rcvd)// && crc_value == 32'hC704DD7B)
        ready <=1;
      else if(ready && receive)
        ready <= 0;

   //capture RX_DV      
   always @(posedge RX_CLK, posedge rx_rst[1])
     if(rx_rst[1])
       RX_DV_reg <= 0;
     else
       RX_DV_reg <= RX_DV;
   
   // capture RX_DATA
   assign data_int = {RX_DATA, data[7:4]};
   always @(posedge RX_CLK, posedge rx_rst[1])
     if(rx_rst[1])
       data <= 0;
     else
       data <= data_int;
   
   //reset sync
   always @ (posedge RX_CLK, posedge rst)
     if(rst)
       rx_rst <= 2'b11;
     else
       rx_rst <= {rx_rst[0], 1'b0};


   //
   // CRC MODULE
   //
  iob_eth_crc crc_rx (
		      .rst(rx_rst),
		      .clk(RX_CLK),
		      .start(pc == 0),
		      .data_in(data),
		      .data_en(wr),
		      .crc_out(crc_value)
		      );

endmodule
