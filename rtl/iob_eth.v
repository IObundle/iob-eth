`timescale 1ns/1ps

/*
 
 Ethernet transmission over crossover cable
 
*/


module iob_eth (
		output 			      GTX_CLK,
		output reg 		      ETH_RESETN,
 
		// frontend mii
		// RX
		input 			      RX_CLK,
		input [3:0] 		      RX_DATA,
		input 			      RX_DV,

		//TX
		input 			      TX_CLK,
		output reg 		      TX_EN,
		output reg [3:0] 	      TX_DATA,

		// backend interface
		input 			      clk,
		input 			      rst,
		input 			      sel,
		input 			      we,
		input [`ETH_ADDR_W-1:0]       addr,
		output reg [`ETH_DATA_W-1:0]  data_out,
		input [`ETH_MAC_ADDR_W/2-1:0] data_in,

		// interrupt bit
		output 			      interrupt
		);


   //rx signals
   wire [`ETH_ADDR_W-3:0] 		     rx_wr_addr;
   wire [`ETH_DATA_W-1:0] 		     rx_wr_data; 
   wire 				     rx_wr;
   wire 				     rx_ready;
   reg 					     rx_ready_1;
   reg 					     rx_ready_2;
   wire 				     rx_ready_clr;
   wire [`ETH_ADDR_W-3:0] 		     rx_nbytes;
   wire 				     rx_nbytes_1;
   wire 				     rx_nbytes_2;

   //tx signals
   reg 					     tx_wr;
   wire 				     tx_send;
   wire 				     tx_ready;
   reg 					     tx_ready_1;
   reg [`ETH_ADDR_W-3:0] 		     tx_nbytes;
   

   // memory buffer backend address
   wire [`ETH_ADDR_W-2:0] 		     be_addr;


   assign GTX_CLK = 1'b0;
   
   
   //
   // ADDRESS DECODER
   //
   always @* begin
      data_out = `ETH_DATA_W'd0;
      interrupt_en_en = 1'b0;

      tx_wr = 1'b0;
      tx_send = 1'b0;
      tx_nbytes_en = 1'b0;
      tx_ready_clr = 1'b0;
      mac_addr_lo_en = 1'b0;
      mac_addr_hi_en = 1'b0;
      dest_mac_addr_lo_en = 1'b0;
      dest_mac_addr_hi_en = 1'b0;
      
      rx_ready_clr = 1'b0;

      case (address)
	`ETH_INTRRPT_EN: interrupt_en_en = sel&we;
	`ETH_STATUS: data_out = { {`ETH_DATA_W-2{1'b0}}, rx_ready_2, tx_ready_4};
	`ETH_CONTROL: tx_send = data_in[0];
	`ETH_TX_DATA: tx_wr = 1'b1;
	`ETH_TX_NBYTES: tx_nbytes_en = 1'b1;
	`ETH_MAC_ADDR_LO:_mac_addr_lo_en = 1'b1;
	`ETH_MAC_ADDR_HI: mac_addr_hi_en = 1'b1;
	`ETH_DEST_MAC_ADDR_LO: dest_mac_addr_lo_en = 1'b1;
	`ETH_DEST_MAC_ADDR_HI: dest_mac_addr_hi_en = 1'b1;
	`ETH_RX_DATA: begin 
	   rx_ready_clr= sel&~we;
	   data_out = data_from_rx_buf;
	end
	`ETH_RX_NBYTES: data_out = rx_nbytes_2;
	   
	default:;
      endcase
   end

   //interrupt
   always @ (posedge clk)
     if(interrupt_en_en)
       interrupt_en <= data_in[0];

   assign interrupt = interrupt_en & (tx_interrupt | rx_interrupt);

   // register mac addresses
   always @ (posedge clk)
     if(dest_mac_addr_lo_en)
        dest_mac_addr[23:0]<= data_in[23:0];
     else if(dest_mac_addr_hi_en)
        dest_mac_addr[47:24]<= data_in[23:0];
     else if(mac_addr_lo_en)
        mac_addr[23:0]<= data_in[23:0];
     else if(tx_dest_mac_addr_hi_en)
        mac_addr[47:24]<= data_in[23:0];


   //
   // MEMORY BUFFER
   //
   
`ifdef ETH_ALT_MEM_TYPE

   iob_eth_alt_t2p_mem  #(
		   .DATA_W(`ETH_DATA_W),
		   .ADDR_W(`ETH_ADDR_W-1)) 
   alt_mem
     (
      .clk(clk),

      // Front-End
      
      .addr_a(addr[`ETH_ADDR_W-2:0]),
      .data_a(data_in),
      .we_a(tx_wr),
      .q_a(data_from_rx_buf),

      // Back-End

      .addr_b(be_addr),
      .data_b(rx_wr_data),
      .we_b(rx_wr),
      .q_b(tx_rd_data)
      );

`endif

   assign be_addr = TX_EN? tx_rd_addr: rx_wr_addr;
   
   
   //
   //RECEIVER
   //
   
   iob_eth_rx rx (
		  .rst			(rx_rst),

		  //frontend
		  .RX_CLK		(RX_CLK),
		  .RX_DATA		(RX_DATA[3:0]),
		  .RX_DV		(RX_DV),
		  .RX_ERR		(RX_ERR),

		  //backend 
		  .wr                   (rx_wr),
		  .addr		        (rx_wr_addr[10:0]),
		  .data		        (rx_wr_data[7:0]),
		  .ready	        (rx_ready_int),
		  .nbytes               (n_bytes),
		  .mac_addr             (mac_addr)
		  );


  // tx ready and interrupt
   always @ (posedge clk)
     if(rst) begin
	rx_ready_1 <= 1'b0;
	rx_ready_2 <= 1'b0;
	rx_ready <= 1'b0;
	rx_interrupt <= 1'b0;
	rx_interrupt <= 1'b0;
     end else begin
	rx_ready_1 <= rx_ready_int;
	rx_ready_2 <= rx_ready_1;
	rx_ready <= rx_ready_2;
	if(~rx_ready & rx_ready_2)
	  rx_interrupt <= 1'b1;
	else if(rx_interrupt_clr)
	  rx_interrupt <= 1'b0;
     end
   
   //
   //TRANSMITTER
   //
   iob_eth_tx tx (
		  .rst			(rst),

		  //frontend
		  .TX_CLK		(TX_CLK),
		  .TX_EN		(TX_EN),
		  .TX_DATA		(TX_DATA),
		  
		  //backend
		  .addr	       	        (tx_rd_addr),
		  .data	       	        (tx_rd_data),
		  .nbytes               (tx_nbytes),
		  .send	                (tx_send),
		  .src_mac_addr         (mac_addr),
		  .dest_mac_addr        (dest_mac_addr)
		  );

   // tx number of bytes
   always @ (posedge clk)
     if(tx_nbytes_en)
       tx_nbytes <= data_in[10:0];

   // tx ready and interrupt
   always @ (posedge clk)
     if(rst) begin
	tx_ready_1 <= 1'b0;
	tx_ready_2 <= 1'b0;
	tx_ready <= 1'b0;
	tx_interrupt <= 1'b0;
	rx_interrupt <= 1'b0;
     end else begin
	tx_ready_1 <= ~TX_EN;
	tx_ready_2 <= tx_ready_1;
	tx_ready <= tx_ready_2;
	if(~tx_ready & tx_ready_2)
	  tx_interrupt <= 1'b1;
	else if(tx_interrupt_clr)
	  tx_interrupt <= 1'b0;
     end
   

   
   // phy reset
   
      always @ (posedge RX_CLK)
	if(rst) begin
           eth_rst_cnt <= 4'd0;
	   ETH_RESETN <= 1'b0;
	end else begin
	   eth_rst_cnt <= (eth_rst_cnt != 4'd15)? eth_rst_cnt+1'b1: eth_rst_cnt;
	   ETH_RESETN <= (eth_rst_cnt == 4'd15);
	end

endmodule
