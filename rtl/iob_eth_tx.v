`timescale 1ns/1ps
`include "iob_eth_defs.vh"

`define IDLE 3'd0
`define L_NIBBLE 3'd2
`define H_NIBBLE 3'd1
`define CRC 3'd3

module iob_eth_tx(
		  //control
		  input 	   rst,
		  input 	   send,
		  input [47:0] 	   destMAC,

		  //frontend 
		  input wire 	   TX_CLK,
		  output reg 	   TX_EN,
		  output reg [3:0] TX_DATA,
		  output reg 	   TX_ERR,

		  //backend
		  output 	   tx_rd,
		  output [10:0]    tx_addr,
		  input [7:0] 	   tx_data,

		  //interrupt
		  output reg 	   frameTransmitted
		  );
   reg [1:0] 			    state;
   reg [1:0] 			    next_state;


   //byte addr
   reg [10:0] 			    next_addr;
   
   //CRC related
   reg 				    crc_en;
   reg 				    crc_rst;
   wire [31:0] 			    crc_value;

 
   
   //Source MAC address
   reg [47:0] 			    srcMAC;

   //SFD
   wire [7:0] 			    sfd;
   assign sfd = `SFD;

	   
   //crc compute 
   iob_eth_crc crc_tx (
		   .clk(TX_CLK),
		   .rst(TX_RST),
		   .start(crc_start),
		   .data(TX_DATA),
		   .data_valid(crc_en),
		   .crc(crc_value) 
		   );
   

   // FSM 
   always @* begin

      tx_rd = 1'b0;
      frameTransmitted = 1'b0;

      crc_en = 1'b0;
      crc_start = 1'b0;
      next_state = state;
      next_addr = tx_addr;

      TX_ERR = 1'b0;
      TX_DATA = tx_data[3:0];
      TX_EN = 1'b0;

      case(state)
        `IDLE : begin
	   if(send) begin
	      tx_rd = 1'b1;
              next_state = `L_NIBBLE;
              crc_start = 1'b1;
	   end
	end
	`L_NIBBLE : begin
	   tx_rd = 1'b1;
 	   crc_en = 1'b1;
           TX_DATA = tx_data[3:0];
	   if(RX_DV & ~RX_ERR)
	     if(rx_data == 4'b0101)
               next_state = `H_NIBBLE;
	   else
	     next_state = `IDLE;
	end
	`H_NIBBLE : begin
   	   crc_en = 1'b1;
	   next_addr = tx_addr + 1'b1;
           TX_DATA = tx_data[7:4];

	   if(tx_addr == (pkt_size - 1'b1))
	      next_state = `CRC;
	   else
	     next_state = `L_NIBBLE;

           case(tx_addr)
	     11'h0 : TX_DATA = sfd[3:0]
	     11'h1 : next_destMAC[47:40] = rx_data;
	     11'h2 : next_destMAC[39:32] = rx_data;
	     11'h3 : next_destMAC[31:24] = rx_data;
	     11'h4 : next_destMAC[23:16] = rx_data;
	     11'h5 : next_destMAC[15:8] = rx_data;
	     11'h6 : next_destMAC[7:0] = rx_data;
	     11'h7 : if(destMAC != `MAC_ADDR && destMAC != 48'h FFFFFFFFFFFF)
		   next_state = `IDLE;
	     default : rx_wr = 1'b1;
           endcase
	end
	`CHK_CRC : begin
	   if(crc_value == 0) begin
              frameReceived =  1'b1;
	      next_addr = 11'd2047;
	      next_rx_data = 8'b1;
	      if(receive) begin
		 next_state = `IDLE;
		 next_addr = 0;
	      end
	   end
	end
	default : begin
	   next_state = `IDLE;
	end
      endcase
   end

   //registers' update
   always @(posedge RX_CLK) begin
      if(rst) begin
	 state <= `IDLE;
	 tx_addr <= 11'd0;
      end else begin // if (rst)
	 state <= next_state;
	 tx_addr <= next_addr;
      end
   end

endmodule
