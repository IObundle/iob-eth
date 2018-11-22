`timescale 1ns/1ps

/*
 High-speed Ethernet transmission over crossover cable
 */

/*
 Memory map
 
 0-2045 Rx addr space 
 2046 Rx control:  receive = non-zero
 2047 Rx status reg: received = non-zero
 2048-4094 Tx addr space 
 2046 Tx control:  send = non-zero
 2047 Tx status reg: sent = non-zero
 */

module iob_eth (
		// frontend media interface
		// RX
		input [3:0] 	 RX_DATA,
		input 		 RX_DV,
		input 		 RX_CLK,
		output reg 	 RX_ERR,
		//TX
		input wire 	 TX_CLK,
		output reg 	 TX_EN,
		output reg [3:0] TX_DATA,
		output reg 	 TX_ERR,

		   // backend interface
		input 		 rst,
		input 		 rd_en,
		input 		 wr_en,
		input [10:0] 	 addr,
		output reg [7:0] data_out,
		input [7:0] 	 data_in,

		   // interrupt bits
		output 		 frameReceived,
		output 		 frameTransmitted
		);


   //rx and tx submodules
   wire [10:0] 			    rx_addr, tx_addr;
   wire [7:0] 			    rx_data, tx_data;
   wire 			    tx_rd, rx_wr;

   // dual-port memory buffer
   reg [7:0] 			    mem[0:4095]; 
   wire [11:0] 			    rxp_addr, txp_addr;
   wire 			    rxp_en, txp_en;
   

   // rx port mux
   assign rxp_en = rd_en | rx_wr;
   assign rxp_addr = {1'b0, rd_en? addr : rx_addr};
   
   
   // tx port mux
   assign txp_en = wr_en | tx_rd;
   assign txp_addr = {1'b1, wr_en? addr : tx_addr};


   // send and receive commands
   wire 			    send, receive;
   assign send = (addr == 12'd2047) & data_in[7];
   assign receive = (addr == 12'd2048) & data_in[6];
   

   //two-port memory buffer 
   //rx port 
   always @ (posedge clk) begin
      if(rxp_en) begin
	 data_out <= mem[rxp_addr];
	 if(rx_wr)
	   mem[rxp_addr] <= rx_data;
      end
   end
   //tx port
   always @ (posedge clk) begin
      if (txp_en) begin
         tx_data <= mem[txp_addr];
	 if(wr_en)
	   mem[txp_addr] <= data_in;  
      end
   end

   //receiver submodule
   iob_eth_rx rx (
		  //control
		  .rst			(rst),
		  .receive              (receive),

		  //frontend
		  .RX_CLK		(RX_CLK),
		  .RX_DATA		(RX_DATA[3:0]),
		  .RX_DV		(RX_DV),
		  .RX_ERR		(RX_ERR),

		  //backend 
		  .rx_wr                (rx_wr),
		  .rx_addr		(rx_addr[10:0]),
		  .rx_data		(rx_data[7:0]),

		  //interrupt
		  .frameReceived	(frameReceived)
		  );
   
   //transmitter submodule
  iob_eth_tx tx (
		  //control
		 .rst			(rst),
		 .send	                (send),
		  
		 //frontend
		 .TX_EN		        (TX_EN),
		 .TX_DATA		(TX_DATA[3:0]),
		 .TX_ERR		(TX_ERR),
		 .TX_CLK		(TX_CLK),
		 
		 //backend
		 .tx_rd                 (tx_rd),
		 .tx_addr	       	(tx_addr[10:0]),
		 .tx_data	       	(tx_data[7:0]),
		  
		 //interrupt
		 .frameTransmitted	(frameTransmitted)
		 );

   
endmodule
