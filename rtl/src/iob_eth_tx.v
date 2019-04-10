`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_tx(
                  //CPU clk domain
		  input             rst,
                  input [10:0]      nbytes,
                  input             send,

		  //TX_CLK domain
		  output reg [10:0] addr,
		  input [7:0]       data,
		  output reg        ready,
		  input wire        TX_CLK,
		  output reg        TX_EN,
		  output reg [3:0]  TX_DATA
		  );

   //tx reset
   reg 				    tx_rst, tx_rst_1;
   
   //state
   reg [2:0] 			    pc;
   
   //crc
   reg                              crc_en;
   wire [31:0]                      crc_value;

   reg [10:0]                       nbytes_sync, nbytes_sync1;

   reg                              send_sync, send_sync1;
   
   
   //
   // TRANSMITTER PROGRAM
   //
   always @(posedge TX_CLK, posedge tx_rst)
      if(tx_rst) begin
         pc <= 0;
         crc_en <= 0;
         addr <= 0;
         ready <= 1;   
         TX_EN <= 0;   
      end else begin

         pc <= pc + 1;
         addr <= addr + pc[0];

         case(pc)

           0: if(send_sync)
              ready <= 0;
           else
             pc <= pc;

           1: begin
              TX_EN <= 1;
              TX_DATA <= data[3:0];
           end

           2: begin
              TX_DATA <= data[7:4];
              if(addr >= 8) 
                crc_en <= 1;
           end
           3: if(addr != (21 + nbytes_sync)) begin
              TX_DATA <= data[3:0];
              pc <= pc-1;
              crc_en <= 0;
           end else begin
              crc_en <= 0;
              TX_EN <= 0;
              pc <= 0;
              ready <= 1;
              addr <= 0;
           end   
         endcase
      end
  
  
   //reset sync
   always @ (posedge TX_CLK, posedge rst)
     if(rst) begin
	tx_rst <= 1'b1;
	tx_rst_1 <= 1'b1;
     end else begin
	tx_rst <= tx_rst_1;
	tx_rst_1 <= 1'b0;
     end
  
   //send sync
   always @ (posedge TX_CLK, posedge send)
     if(send) begin
        send_sync <= 1;
        send_sync1 <= 1;
     end else begin
        send_sync <= send_sync1;
        send_sync1 <= 0;
     end

   //nbytes sync
   always @ (posedge TX_CLK, posedge rst)
     if(rst) begin
        nbytes_sync <= 0;
        nbytes_sync1 <= 0;
     end else begin
        nbytes_sync <= nbytes_sync1;
        nbytes_sync1 <= nbytes;
     end

   //
   // CRC MODULE
   //
   
   iob_eth_crc crc_tx (
		       .rst(tx_rst),
		       .clk(TX_CLK),
                       .start(send),
		       .data_in(data),
		       .data_en(crc_en),
		       .crc_out(crc_value) 
		       );

endmodule
