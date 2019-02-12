`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_tx(
		  //control
		  input                        rst,

		  //frontend 
		  input wire                   TX_CLK,
		  output                       TX_EN,
		  output reg [3:0]             TX_DATA,

		  //backend
		  output [`ETH_BUF_ADDR_W-1:0] addr,
		  input [`ETH_DATA_W-1:0]      data,
		  input [2*`ETH_DATA_W-1:0]    nbytes,
		  input                        send,
		  input [`ETH_MAC_ADDR_W-1:0]  src_mac_addr,
		  input [`ETH_MAC_ADDR_W-1:0]  dest_mac_addr,

		  //status
		  output                       ready
		  );

   //tx reset
   reg 				    tx_rst, tx_rst_1;
   
   //state
   reg [1:0] 			    state;
   reg [1:0] 			    state_nxt;
   reg [2*`ETH_DATA_W-1:0] 	    byte_counter;
   wire 			    frame_sent;
   

   //tx data
   reg [`ETH_DATA_W-1:0] 	    tx_data;

   //send bit syncrononizer
   reg 				    tx_send, tx_send_1;
   
   //crc
   wire 			    crc_en;
   wire [`ETH_CRC_W-1:0] 	    crc_value;
   

   //
   // ASSIGNMENTS
   //

   assign ready = ~TX_EN;
   assign TX_EN = (state != `ETH_IDLE);
   assign addr = byte_counter[`ETH_BUF_ADDR_W-1:0] - `ETH_BUF_ADDR_W'd21;
   assign crc_en = (byte_counter >= 8 && byte_counter <= (nbytes + 25));
   assign frame_sent = (byte_counter == (nbytes + 25));
   
   //
   // TRANSMIT FRAME
   //

   
   always @*
     if(byte_counter <= `ETH_BUF_ADDR_W'd6)
       tx_data = `ETH_PREAMBLE;
     else if(byte_counter == `ETH_BUF_ADDR_W'd7)
       tx_data = `ETH_SFD;
     else if(byte_counter == `ETH_BUF_ADDR_W'd8)
       tx_data = dest_mac_addr[7 : 0];
     else if(byte_counter == `ETH_BUF_ADDR_W'd9)
       tx_data = dest_mac_addr[15 : 8];
     else if(byte_counter == `ETH_BUF_ADDR_W'd10)
       tx_data = dest_mac_addr[23 : 16];
     else if(byte_counter == `ETH_BUF_ADDR_W'd11)
       tx_data = dest_mac_addr[31 : 24];
     else if(byte_counter == `ETH_BUF_ADDR_W'd12)
       tx_data = dest_mac_addr[39 : 32];
     else if(byte_counter == `ETH_BUF_ADDR_W'd13)
       tx_data = dest_mac_addr[47 : 40];
     else if(byte_counter == `ETH_BUF_ADDR_W'd14)
       tx_data = src_mac_addr[7 : 0];
     else if(byte_counter == `ETH_BUF_ADDR_W'd15)
       tx_data = src_mac_addr[15 : 8];
     else if(byte_counter == `ETH_BUF_ADDR_W'd16)
       tx_data = src_mac_addr[23 : 16];
     else if(byte_counter == `ETH_BUF_ADDR_W'd17)
       tx_data = src_mac_addr[31 : 24];
     else if(byte_counter == `ETH_BUF_ADDR_W'd18)
       tx_data = src_mac_addr[39 : 32];
     else if(byte_counter == `ETH_BUF_ADDR_W'd19)
       tx_data = src_mac_addr[47 : 40];
     else if(byte_counter == `ETH_BUF_ADDR_W'd20)
       tx_data = nbytes[7:0];
     else if(byte_counter == `ETH_BUF_ADDR_W'd21)
       tx_data = nbytes[15:8];
     else if(byte_counter < (nbytes + 22))
       tx_data = data;
     else if (byte_counter == (nbytes + `ETH_BUF_ADDR_W'd23))
       tx_data = crc_value[7 : 0];
     else if (byte_counter == (nbytes + `ETH_BUF_ADDR_W'd24))
       tx_data = crc_value[15 : 8];
     else if (byte_counter == (nbytes + `ETH_BUF_ADDR_W'd25))
       tx_data = crc_value[23 : 16];
     else if (byte_counter == (nbytes + `ETH_BUF_ADDR_W'd26))
       tx_data = crc_value[31 : 25];
     else
       tx_data = `ETH_DATA_W'd0;
      
   //
   // TRANSMITTER STATE MACHINE
   //
   always @* begin 
      state_nxt = state;
      TX_DATA = 4'd0;
      case(state)
        `ETH_IDLE : 
	  if(tx_send)
            state_nxt = `ETH_L_NIBBLE;
        `ETH_L_NIBBLE : begin
           TX_DATA = tx_data[3:0];
          state_nxt = `ETH_H_NIBBLE;
        end
        `ETH_H_NIBBLE : begin
           TX_DATA = tx_data[7:4];
	   state_nxt = `ETH_L_NIBBLE;
	   if(frame_sent)
	     state_nxt = `ETH_IDLE;
        end
        default: TX_DATA = 4'd0;
      endcase
   end // always @ *
   
   
   //update state 
   always @(posedge TX_CLK, posedge tx_rst)
     if(tx_rst) begin
	state <= `ETH_IDLE;
	byte_counter <= {2*`ETH_DATA_W{1'b0}};
     end else begin
	state <= state_nxt;
	if(state == `ETH_H_NIBBLE) begin
	   byte_counter <= byte_counter + 1'b1;
	   if(frame_sent)
	     byte_counter <= {2*`ETH_DATA_W{1'b0}};
	end
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

  //sync send 
   always @ (posedge TX_CLK, posedge send)
     if(send) begin 
	tx_send <= 1'b1;
	tx_send_1 <= 1'b1;
     end else begin
	tx_send_1 <= 1'b0;
	tx_send <= tx_send_1;    
     end

   //
   // CRC MODULE
   //
   
   iob_eth_crc crc_tx (
		       .clk(TX_CLK),
		       .rst(tx_rst),
		       .start(tx_send),
		       .data(TX_DATA),
		       .data_valid(crc_en),
		       .crc(crc_value) 
		       );

endmodule
