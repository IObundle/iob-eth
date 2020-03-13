`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_tx(
                  //CPU clk domain
		  input             rst,
                  input [10:0]      nbytes,
                  input             send,

		  output reg        ready,

		  //TX_CLK domain
		  output reg [10:0] addr,
		  input [7:0]       data,
		  input wire        TX_CLK,
		  output reg        TX_EN,
		  output reg [3:0]  TX_DATA
		  );

   function [7:0] reverse_byte;
      input [7:0]                   word;
      integer                       i;

      begin
         for (i=0; i < 8; i=i+1)
           reverse_byte[i]=word[7 - i];
      end
   endfunction
   
  //tx reset
   reg [1:0]			    tx_rst;
   
   //state
   reg [3:0] 			    pc;
   
   //crc
   reg                              crc_en;
   wire [31:0]                      crc_value;
   wire [31:0]                      crc_out;
   
   reg [10:0]                       nbytes_sync[1:0];

   reg [1:0]                        send_sync;


   //SYNCHRONIZERS   

   //reset sync
   always @ (posedge TX_CLK, posedge rst)
     if(rst)
	tx_rst <= 2'b11;
     else
	tx_rst <= {tx_rst[0], 1'b0};
  
   //send sync
   always @ (posedge TX_CLK, posedge send)
     if(send)
        send_sync <= 2'b11;
     else
        send_sync <= {send_sync[0], 1'b0};

   //nbytes sync
   always @ (posedge TX_CLK, posedge tx_rst[1])
     if(tx_rst[1]) begin
        nbytes_sync[0] <= 0;
        nbytes_sync[1] <= 0;
     end else begin
        nbytes_sync[1] <= nbytes_sync[0];
        nbytes_sync[0] <= nbytes;
     end

   
   //
   // TRANSMITTER PROGRAM
   //
   always @(posedge TX_CLK, posedge tx_rst[1])
      if(tx_rst[1]) begin
         pc <= 0;
         crc_en <= 0;
         addr <= 0;
         ready <= 1;   
         TX_EN <= 0;   
      end else begin

         pc <= pc + 1'b1;
         addr <= addr + pc[0];
         crc_en <= 0;
         
         case(pc)

           0: if(send_sync[1])
              ready <= 0;
           else
             pc <= pc;

           1: begin
              TX_EN <= 1;
              TX_DATA <= data[3:0];
           end

           2: begin
              TX_DATA <= data[7:4];
              if(addr != 16)
                pc <= pc-1'b1;
              else
                crc_en <= 1;
           end
           
           3: TX_DATA <= data[3:0];

           4: begin 
              TX_DATA <= data[7:4];
              if(addr <= (29 + nbytes_sync[1])) begin
                 crc_en <= 1;
                 pc <= pc-1'b1;
              end
           end
           
           5: TX_DATA <= crc_out[27:24];
           
           6: TX_DATA <= crc_out[31:28];

           7: TX_DATA <= crc_out[19:16];
           
           8: TX_DATA <= crc_out[23:20];
           
           9: TX_DATA <= crc_out[11:8];
           
           10: TX_DATA <= crc_out[15:12];
           
           11: TX_DATA <= crc_out[3:0];
           
           12: TX_DATA <= crc_out[7:4];
           
           13: begin    
              TX_EN <= 0;
              pc <= 0;
              ready <= 1;
              addr <= 0;
           end
           
         endcase
      end // else: !if(tx_rst[1])
        
   //
   // CRC MODULE
   //
   
   iob_eth_crc crc_tx (
		       .rst(tx_rst[1]),
		       .clk(TX_CLK),
                       .start(send_sync[1]),
		       .data_in(data),
		       .data_en(crc_en),
		       .crc_out(crc_value) 
		       );

   assign crc_out = ~{reverse_byte(crc_value[31:24]),
                      reverse_byte(crc_value[23:16]),
                      reverse_byte(crc_value[15:8]),
                      reverse_byte(crc_value[7:0])};
   
   
endmodule
