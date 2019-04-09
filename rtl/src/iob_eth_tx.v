`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_tx(
                  //CPU clk domain
		  input             rst,
                  input [10:0]      nbytes,

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
   reg [3:0] 			    pc;
   
   //crc
   reg                              crc_en;
   wire [31:0]                      crc_value;

   reg [10:0]                       nbytes_sync, nbytes_sync1;
   
   //
   // TRANSMITTER PROGRAM
   //
   always @(posedge TX_CLK, posedge tx_rst)
      if(tx_rst) begin
         pc <= 0;
         crc_en <= 0;
         addr <= 0;
         ready <= 0;      
      end else begin

         pc <= pc + 1;
         addr = addr + pc[0];

         case(pc)

           0: begin
              TX_EN <= 1;
              TX_DATA <= 4'd5;
           end
           
           1: if(addr != 7)
             pc <= pc-1;
           else 
             addr <= 0;
           
           2:;

           3: TX_DATA <= 4'hD;

           4:;

           5: if(addr != (13+nbytes_sync))
             pc <= pc-1;
           else begin
              TX_EN <= 0;
              pc <= pc;
              ready <= 1;
              addr <= addr;
           end   
         endcase
      end
  
  
   //sync reset
   always @ (posedge TX_CLK, posedge rst)
     if(rst) begin
	tx_rst <= 1'b1;
	tx_rst_1 <= 1'b1;
     end else begin
	tx_rst <= tx_rst_1;
	tx_rst_1 <= 1'b0;
     end

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
		       .data_in(tx_data),
		       .data_en(crc_en),
		       .crc_out(crc_value) 
		       );

endmodule
