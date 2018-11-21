`timescale 1ns/1ps
`include "iob_eth_defs.vh"

`define IDLE 3'd0
`define L_NIBBLE 3'd2
`define H_NIBBLE 3'd1
`define CRC 3'd3


module iob_eth_rx(

		   input 	     rst,
		   input 	     receive,
		  
		   // frontend 
		   input 	     RX_CLK,
		   input [3:0] 	     RX_DATA,
		   input 	     RX_DV,
		   output reg 	     RX_ERR,

		   // memory buffer interface
		   output reg 	     rx_wr,
		   output reg [10:0] rx_addr,
		   output reg [7:0]  rx_data,

		   //interrupt
		   output reg 	     frameReceived
		   );

   reg [1:0] 			    state;
   reg [1:0] 			    next_state;

   //rx data byte
   reg [7:0] 			    next_rx_data;

   //byte addr
   reg [10:0] 			    next_addr;

   //Destination MAC address
   reg [47:0] 			    destMAC, next_destMAC;
   
   //CRC related
   reg 				    crc_en;
   reg 				    crc_rst;
   wire [31:0] 			    crc_value;   
	   
   //crc compute 
   iob_eth_crc crc_rx (
		   .clk(RX_CLK),
		   .rst(rst),
		   .newFrame(crc_rst),
		   .inNibble(RX_DATA),
		   .inNibbleValid(crc_en),
		   .crcValid(/* open */),
		   .crcValue(crc_value) 
		   );
   

   // FSM 
   always @* begin

      rx_wr = 1'b1;
      frameReceived = 1'b0;
      next_rx_data = rx_data;
      next_destMAC = destMAC;
      crc_en = 1'b0;
      crc_rst = 1'b0;
      next_state = state;
      next_addr = rx_addr;
       
      case(state)
        `IDLE : begin
	   rx_wr = 1'b0;
           next_rx_data[3:0] = RX_DATA;
	   if(RX_DV & ~RX_ERR)
             next_state = `L_NIBBLE;
           crc_rst = 1'b1;
	end
	`L_NIBBLE : begin
	   rx_wr = 1'b0;
 	   crc_en = 1'b1;
           next_rx_data[7:4] = RX_DATA;
	   if(RX_DV & ~RX_ERR)
             next_state = `H_NIBBLE;
	   else
	     next_state = `IDLE;
	end
	`H_NIBBLE : begin
   	   crc_en = 1'b1;
           next_rx_data[3:0] = RX_DATA;
	   next_addr = rx_addr + 1'b1;

	   if(RX_DV & ~RX_ERR)
	     next_state = `L_NIBBLE;
	   else if (~RX_DV & ~RX_ERR)
	     next_state = `CHK_CRC;
	   else 
	     next_state = `IDLE;

           case(rx_addr)
	     11'h0 : if(rx_data == `SFD)
	       crc_en = 1'b1;
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
   always @(posedge RX_CLK)begin
      if(rst) begin
	 state <= `IDLE;
	 rx_addr <= 11'd0;
	 destMAC <= 48'd0;
	 rx_data <= 8'd0;
      end else begin // if (rst)
	 state <= next_state;
	 rx_addr <= next_addr;
	 destMAC <= next_destMAC;
	 rx_data <= next_rx_data;
      end
   end

endmodule
