`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_rx(
		  input                            rst,
		  
		   //frontend 
		  input                            RX_CLK,
		  input                            RX_DV,
		  input [3:0]                      RX_DATA,

		   //backend
		  output [`ETH_BUF_ADDR_W-1:0]     addr,
		  output [`ETH_DATA_W-1:0]         data,
		  output reg                       wr,
		  output reg [`ETH_MAC_ADDR_W-1:0] src_mac_addr,
		  input [`ETH_MAC_ADDR_W-1:0]      mac_addr,

		  //status
		  output reg                       ready
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
   
   //rx data
   reg [`ETH_DATA_W-1:0] 			   rx_data, rx_data_nxt;
   
   //crc
   wire 					   crc_en;
   reg 						   crc_start;
   wire [31:0] 					   crc_value;   
   
   //
   // ASSIGNMENTS
   //
   assign data = rx_data;
   assign addr = byte_counter - `ETH_BUF_ADDR_W'd15;
   assign crc_en = (byte_counter >= 0 && byte_counter <= (8'd13 +  `ETH_SIZE + `ETH_CRC_W/8));

   
   //
   // GENERATE READY FLAG
   //
   always @ (posedge RX_CLK, posedge rx_rst)
     if(rx_rst)
       ready <= 1'b0;
     else if(byte_counter == (8'd14 + `ETH_SIZE + `ETH_CRC_W/8) && state == `ETH_H_NIBBLE) begin 
	ready <= 1'b1;
`ifdef DEBUG
        if(crc_value != 0)
	  $display("CRC check failed");
`endif
     end

   
   // RECEIVE FRAME
   //
   always @* begin

      //defaults
      dest_mac_addr_nxt = dest_mac_addr;
      src_mac_addr_nxt = src_mac_addr;
      
      wr = 1'b0;
      

      //receive destination address

      if(byte_counter == `ETH_BUF_ADDR_W'd1)
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
     
 
      //receive data
      
      else if(byte_counter < (8'd15 + `ETH_SIZE)) begin
	 wr = (state == `ETH_L_NIBBLE);
      end
   end // always @ *

   //
   // CHECK RECEIVED DATA
   //
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
	end else if (byte_counter == (`ETH_BUF_ADDR_W'd14 + `ETH_SIZE + `ETH_CRC_W/4)) 
	  rst_state = 1'b0;
   end // always @ *

   //
   // RECEIVER STATE MACHINE
   //
   always @* begin 
      state_nxt = state;
      rx_data_nxt = rx_data;
      case(state)
	`ETH_IDLE : 
	  if(RX_DV)
            state_nxt = `ETH_L_NIBBLE;
	`ETH_L_NIBBLE : 
	  if(RX_DV) begin
	     state_nxt = `ETH_H_NIBBLE;
	     rx_data_nxt = {4'd0, RX_DATA};
	     if(rst_state)
	       state_nxt = `ETH_IDLE;	     
	  end
	`ETH_H_NIBBLE : 
	  if(RX_DV) begin
	     state_nxt = `ETH_L_NIBBLE;
	     rx_data_nxt = {RX_DATA, rx_data[3:0]};
	     if(rst_state)
	       state_nxt = `ETH_IDLE;
       end
	default: rx_data_nxt = rx_data;
      endcase
   end // always @ *
   
   // update registers
   always @(posedge RX_CLK, posedge rx_rst)begin
      if(rx_rst) begin
	 state <= `ETH_IDLE;
	 byte_counter <= ~`ETH_BUF_ADDR_W'd0;
	 dest_mac_addr <= `ETH_MAC_ADDR_W'd0;
	 src_mac_addr <= `ETH_MAC_ADDR_W'd0;
      end else begin // if (rst)
	 state <= state_nxt;
	 if(state == `ETH_IDLE && RX_DV || state == `ETH_H_NIBBLE)
	   byte_counter <= byte_counter+1'b1;
	 else if(rst_state)
	   byte_counter <= 0;;
	 dest_mac_addr <= dest_mac_addr_nxt;
	 src_mac_addr <= src_mac_addr_nxt;
      end
   end

   // capture data
   always @(posedge RX_CLK)
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

   
   //
   // CRC MODULE
   //
   iob_eth_crc crc_rx (
		       .clk(RX_CLK),
		       .rst(rst),
		       .start(crc_start),
		       .data(RX_DATA),
		       .data_valid(crc_en),
		       .crc(crc_value) 
		       );

endmodule
