`timescale 1ns/1ps

/*
 
 Simple Ethernet Core 
 
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

   // interrupt
   reg 					      interrupt_en;
   reg 					      interrupt_en_en;
   
   // mac addresses
   reg [`ETH_MAC_ADDR_W-1:0] 		      mac_addr;
   reg [`ETH_MAC_ADDR_W-1:0] 		      dest_mac_addr;
   reg 					      mac_addr_lo_en;
   reg 					      mac_addr_hi_en;
   reg 					      dest_mac_addr_lo_en;
   reg 					      dest_mac_addr_hi_en;

   //tx signals
   wire [`ETH_BUF_ADDR_W-1:0] 		     tx_rd_addr; 
   wire [`ETH_DATA_W-1:0] 		     tx_rd_data; 
   reg 					     tx_wr;
   reg 					     tx_send;
   wire 				     tx_ready;
   reg 					     tx_ready_clr;
   reg [`ETH_ADDR_W-3:0] 		     tx_nbytes;
   reg 					     tx_nbytes_en;
 
  //rx signals
   wire [`ETH_BUF_ADDR_W-1:0] 		     rx_wr_addr;
   wire [`ETH_DATA_W-1:0] 		     rx_wr_data; 
   wire 				     rx_wr;
   wire 				     rx_ready;
   reg 					     rx_ready_clr;
   wire [`ETH_ADDR_W-3:0] 		     rx_nbytes;
  

   // memory buffer
   wire [`ETH_ADDR_W-2:0] 		     be_addr;
   wire [`ETH_DATA_W-1:0] 		     rx_rd_data; 

   // phy reset timer
   reg [3:0] 				     phy_rst_cnt;
   
   
   //
   // ASSIGNMENTS
   //
   
   assign GTX_CLK = 1'b0; //this will force 10/100 negotiation
   assign interrupt = interrupt_en & (tx_ready | rx_ready);
  
   assign be_addr = TX_EN? tx_rd_addr: rx_wr_addr; // back-end memory address is controlled by either tx or rx
   
 
   
   //
   // ADDRESS DECODER
   //
   always @* begin

      //defaults

      // core outputs
      data_out = `ETH_DATA_W'd0;
      interrupt_en_en = 1'b0;

      // mac addresses
      mac_addr_lo_en = 1'b0;
      mac_addr_hi_en = 1'b0;
      dest_mac_addr_lo_en = 1'b0;
      dest_mac_addr_hi_en = 1'b0;

      // tx 
      tx_wr = 1'b0;
      tx_send = 1'b0;
      tx_nbytes_en = 1'b0;
      tx_ready_clr = 1'b0;

      // rx
      rx_ready_clr = 1'b0;

      case (addr)
	`ETH_INTRRPT_EN: interrupt_en_en = sel&we;
	`ETH_STATUS: data_out = { {`ETH_DATA_W-2{1'b0}}, rx_ready, tx_ready};
	`ETH_CONTROL: tx_send = data_in[0];
	`ETH_TX_DATA: begin
	   tx_ready_clr= sel&~we;
	   tx_wr = 1'b1;
	end
	`ETH_TX_NBYTES: tx_nbytes_en = 1'b1;
	`ETH_MAC_ADDR_LO: mac_addr_lo_en = 1'b1;
	`ETH_MAC_ADDR_HI: mac_addr_hi_en = 1'b1;
	`ETH_DEST_MAC_ADDR_LO: dest_mac_addr_lo_en = 1'b1;
	`ETH_DEST_MAC_ADDR_HI: dest_mac_addr_hi_en = 1'b1;
	`ETH_RX_DATA: begin
	   rx_ready_clr= sel&~we;
	   data_out = rx_rd_data;
	end
	`ETH_RX_NBYTES: data_out = rx_nbytes;
	   
	default:;
      endcase
   end // always @ *
   


   //
   // REGISTERS
   //
   
   // register interrupt enable
   always @ (posedge clk)
     if(rst)
       interrupt_en <= 1'b0;
     else if(interrupt_en_en)
       interrupt_en <= data_in[0];

   // register mac addresses
   
   always @ (posedge clk)
     if(rst) begin
	mac_addr <= `ETH_MAC_ADDR;
	dest_mac_addr <= `ETH_MAC_ADDR;
     end else if(dest_mac_addr_lo_en)
       dest_mac_addr[23:0]<= data_in[23:0];
     else if(dest_mac_addr_hi_en)
       dest_mac_addr[47:24]<= data_in[23:0];
     else if(mac_addr_lo_en)
       mac_addr[23:0]<= data_in[23:0];
     else if(mac_addr_hi_en)
       mac_addr[47:24]<= data_in[23:0];

   // register tx number of bytes
   always @ (posedge clk)
     if(tx_nbytes_en)
       tx_nbytes <= data_in[10:0];


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
      .data_a(data_in[`ETH_DATA_W-1:0]),
      .we_a(tx_wr),
      .q_a(rx_rd_data),

      // Back-End

      .addr_b(be_addr),
      .data_b(rx_wr_data),
      .we_b(rx_wr),
      .q_b(tx_rd_data)
      );

`endif

   //
   //TRANSMITTER
   //
   
 
    iob_eth_tx tx (
		   .rst			(rst | tx_ready_clr),

		   //frontend
		   .TX_CLK		(TX_CLK),
		   .TX_EN		(TX_EN),
		   .TX_DATA		(TX_DATA),
		   
		   //backend
		   .addr	       	(tx_rd_addr),
		   .data	       	(tx_rd_data),
		   .nbytes              (tx_nbytes),
		   .send	        (tx_send),
		   .src_mac_addr        (mac_addr),
		   .dest_mac_addr       (dest_mac_addr),
		   
		   //status
		  .ready                (tx_ready)
		  );
 
  

   //
   //RECEIVER
   //
   /*
   iob_eth_rx rx (
		  .rst			(rst | rx_ready_clr),

		  //frontend
		  .RX_CLK		(RX_CLK),
		  .RX_DATA		(RX_DATA[3:0]),
		  .RX_DV		(RX_DV),

		  //backend 
		  .wr                   (rx_wr),
		  .addr		        (rx_wr_addr[10:0]),
		  .data		        (rx_wr_data[7:0]),
		  .ready	        (rx_ready),
		  .nbytes               (rx_nbytes),
		  .mac_addr             (mac_addr)
		  );
*/
   

   //
   //  PHY RESET
   //
   
   always @ (posedge RX_CLK)
     if(rst) begin
        phy_rst_cnt <= 4'd0;
	ETH_RESETN <= 1'b0;
     end else begin
	if((phy_rst_cnt != 4'd15))
	  phy_rst_cnt <= phy_rst_cnt+1'b1;
	ETH_RESETN <= (phy_rst_cnt == 4'd15);
     end

endmodule
