`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input 			   rst,
		  
		   //frontend 
		  input 			   RX_CLK,
		  input 			   RX_DV,
		  input [3:0] 			   RX_DATA,

		   //backend
		  output [`ETH_BUF_ADDR_W-1:0] 	   addr,
		  output reg [`ETH_DATA_W-1:0] 	   data,
		  output reg 			   we,
		  output reg [`ETH_BUF_ADDR_W-1:0] nbytes,
		  output reg [`ETH_MAC_ADDR_W-1:0] src_mac_addr,
		  input [`ETH_MAC_ADDR_W-1:0] 	   mac_addr,

		  //status
		  output reg 			   ready
		  );

   //rx reset
   reg 						   rx_rst, rx_rst_1;

   //state
   reg [1:0] 					   state;
   reg [1:0] 					   state_nxt;
   reg 						   rst_state;
   reg [`ETH_BUF_ADDR_W-1:0] 			   byte_counter;

   //mac addresses
   reg [`ETH_MAC_ADDR_W-1:0] 			   dest_mac_addr, dest_mac_addr_nxt;
   reg [`ETH_MAC_ADDR_W-1:0] 			   src_mac_addr_nxt;
   
   //payload size
   reg [`ETH_BUF_ADDR_W-1:0] 			   nbytes_nxt;
   
   //rx data
   reg [`ETH_DATA_W-1:0] 			   rx_data, rx_data_nxt;
   
   //CRC
   wire 					   crc_en;
   reg 						   crc_start;
   wire [31:0] 					   crc_value;   
   
   //SFD
   reg [`ETH_DATA_W-1:0] 			   sfd, sfd_nxt;

   //PREAMBLE
   wire [`ETH_DATA_W-1:0] 			   preamble;		    

   //crc compute 
   iob_eth_crc crc_rx (
		       .clk(~RX_CLK),
		       .rst(rst),
		       .start(crc_start),
		       .data(RX_DATA),
		       .data_valid(crc_en),
		       .crc(crc_value) 
		       );

   assign preamble = `ETH_PREAMBLE;

   assign addr = byte_counter - `ETH_BUF_ADDR_W'd15;
   assign crc_en = (byte_counter >= 1 && byte_counter <= (`ETH_BUF_ADDR_W'd14 + nbytes + `ETH_CRC_W/4));

   //select data to send according to byte counter
   always @* begin

      //defaults
      dest_mac_addr_nxt = dest_mac_addr;
      src_mac_addr_nxt = src_mac_addr;
      nbytes_nxt = nbytes;
      data = `ETH_DATA_W'd0;
      we = 1'b0;
      
      //receive destination address
      if(byte_counter == `ETH_BUF_ADDR_W'd0)
	sfd_nxt = rx_data;
      else if(byte_counter == `ETH_BUF_ADDR_W'd1)
	dest_mac_addr_nxt = {dest_mac_addr[`ETH_MAC_ADDR_W-1:`ETH_DATA_W], rx_data};
      
      else if(byte_counter == `ETH_BUF_ADDR_W'd2)
	dest_mac_addr_nxt = {dest_mac_addr[`ETH_MAC_ADDR_W-1:2*`ETH_DATA_W], rx_data, dest_mac_addr[`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd3)
	dest_mac_addr_nxt = {dest_mac_addr[`ETH_MAC_ADDR_W-1:3*`ETH_DATA_W], rx_data, dest_mac_addr[2*`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd4)
	dest_mac_addr_nxt = {dest_mac_addr[`ETH_MAC_ADDR_W-1:4*`ETH_DATA_W], rx_data, dest_mac_addr[3*`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd5)
	dest_mac_addr_nxt = {dest_mac_addr[`ETH_MAC_ADDR_W-1:5*`ETH_DATA_W], rx_data, dest_mac_addr[4*`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd6)
	dest_mac_addr_nxt = {rx_data, dest_mac_addr[5*`ETH_DATA_W-1:0]};

      //receive source address

      else if(byte_counter == `ETH_BUF_ADDR_W'd7)
	src_mac_addr_nxt = {src_mac_addr[`ETH_MAC_ADDR_W-1:`ETH_DATA_W], rx_data};
      
      else if(byte_counter == `ETH_BUF_ADDR_W'd8)
	src_mac_addr_nxt = {src_mac_addr[`ETH_MAC_ADDR_W-1:2*`ETH_DATA_W], rx_data, src_mac_addr[`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd9)
	src_mac_addr_nxt = {src_mac_addr[`ETH_MAC_ADDR_W-1:3*`ETH_DATA_W], rx_data, src_mac_addr[2*`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd10)
	src_mac_addr_nxt = {src_mac_addr[`ETH_MAC_ADDR_W-1:4*`ETH_DATA_W], rx_data, src_mac_addr[3*`ETH_DATA_W-1:0]};

      else if(byte_counter == `ETH_BUF_ADDR_W'd11)
	src_mac_addr_nxt = {src_mac_addr[`ETH_MAC_ADDR_W-1:5*`ETH_DATA_W], rx_data, src_mac_addr[4*`ETH_DATA_W-1:0]};
      
      else if(byte_counter == `ETH_BUF_ADDR_W'd12)
	src_mac_addr_nxt = {rx_data, src_mac_addr[5*`ETH_DATA_W-1:0]};

      //receive payload size
      else if(byte_counter == `ETH_BUF_ADDR_W'd13)
	nbytes_nxt = {nbytes[2*`ETH_DATA_W-1:`ETH_DATA_W], rx_data};
      
      else if(byte_counter == `ETH_BUF_ADDR_W'd14)
	nbytes_nxt = {rx_data, nbytes[`ETH_DATA_W-1:0]};
      
      //receive data

      else if(byte_counter < (`ETH_BUF_ADDR_W'd15 + nbytes)) begin
	 data = rx_data;
	 we = 1'b1;
      end
   end // always @ *
   
   // check received data
   always @ * begin
      rst_state = 1'b0;
      if(RX_DV == 1'b1 && state == `ETH_H_NIBBLE)
	if(byte_counter == `ETH_BUF_ADDR_W'd0)
	  if(rx_data != `ETH_SFD) 
	    rst_state = 1'b0;
	else if(byte_counter == `ETH_BUF_ADDR_W'd6)
	  if(dest_mac_addr != mac_addr) 
	    rst_state = 1'b0;
	else if(byte_counter == `ETH_BUF_ADDR_W'd6) begin
	   if(dest_mac_addr != mac_addr) 
	     rst_state = 1'b0;
	end 
   end
      
   // ready flag (crc check)
   always @ (posedge RX_CLK)
     if(rx_rst)
       ready <= 1'b0;
     else if(byte_counter == (`ETH_BUF_ADDR_W'd14 + nbytes + `ETH_CRC_W/4) && state == `ETH_H_NIBBLE)
       if(crc_value == `ETH_CRC_W'd0)
	 ready <= 1'b1;
   
   // rx fsm
   always @* begin 
      state_nxt = state;
      case(state)
	`ETH_IDLE : 
	  if(RX_DV)
            state_nxt = `ETH_L_NIBBLE;
	`ETH_L_NIBBLE : 
	  if(RX_DV) begin
	     state_nxt = `ETH_H_NIBBLE;
	     rx_data_nxt = {rx_data, RX_DATA};
	     if(rst_state)
	       state_nxt = `ETH_IDLE;	     
	  end
	`ETH_H_NIBBLE : 
	  if(RX_DV) begin
	     state_nxt = `ETH_L_NIBBLE;
	     rx_data_nxt = {RX_DATA, rx_data};
	     if(rst_state)
	       state_nxt = `ETH_IDLE;
       end
	default:;
      endcase
   end // always @ *
   
   // update registers
   always @(posedge RX_CLK)begin
      if(rx_rst) begin
	 state <= `ETH_IDLE;
	 byte_counter <= `ETH_BUF_ADDR_W'd0;
	 sfd <= `ETH_DATA_W'd0;
	 dest_mac_addr <= `ETH_MAC_ADDR_W'd0;
	 src_mac_addr <= `ETH_MAC_ADDR_W'd0;
	 nbytes <= `ETH_BUF_ADDR_W'd0;
      end else begin // if (rst)
	 state <= state_nxt;
	 if(state == `ETH_H_NIBBLE)
	   byte_counter <= byte_counter + 1'b1;
	 else if(rst_state)
	   byte_counter <= `ETH_BUF_ADDR_W'd0;;
	 sfd <= sfd_nxt;
	 dest_mac_addr <= dest_mac_addr_nxt;
	 src_mac_addr <= src_mac_addr_nxt;
	 nbytes <= nbytes_nxt;
      end
   end

   // capture data on negative edge
   always @(negedge RX_CLK)
     rx_data <= rx_data_nxt;
   
   //reset sync
   always @ (posedge rst, posedge RX_CLK)
     if(rst) begin
	rx_rst <= 1'b1;
	rx_rst_1 <= 1'b1;
     end else begin
	rx_rst <= rx_rst_1;
	rx_rst_1 <= 1'b0;
     end
   
endmodule
