`timescale 1ns/1ps
`include "iob_eth_defs.vh"

/*
 
 Ethernet Core 
 
*/


module iob_eth (
		// CPU side
		input                   clk,
		input                   rst,
		input                   sel,
		input                   we,
		input [`ETH_ADDR_W-1:0] addr,
		output reg [31:0]       data_out,
		input [31:0]            data_in,



		// MII side
		output                  GTX_CLK,
		output reg              ETH_RESETN,
 
		// RX
		input                   RX_CLK,
		input [3:0]             RX_DATA,
		input                   RX_DV,

		//TX
		input                   TX_CLK,
		output                  TX_EN,
		output [3:0]            TX_DATA,

		// interrupt bit
		output                  interrupt
		);

   // interrupt
   reg 					      interrupt_en;
   reg 					      interrupt_en_en;
   
   // mac addresses
   reg [`ETH_MAC_ADDR_W-1:0]                  mac_addr;
   reg [`ETH_MAC_ADDR_W-1:0]                  dest_mac_addr;
   wire [`ETH_MAC_ADDR_W-1:0]                 src_mac_addr;
   reg 					      mac_addr_lo_en;
   reg 					      mac_addr_hi_en;
   reg 					      dest_mac_addr_lo_en;
   reg 					      dest_mac_addr_hi_en;

   //tx signals
   wire [`ETH_BUF_ADDR_W-1:0]                 tx_rd_addr; 
   wire [`ETH_DATA_W-1:0]                     tx_rd_data; 
   reg                                        tx_wr;
   reg                                        tx_send;
   wire                                       tx_ready;
   reg [2*`ETH_DATA_W-1:0]                    tx_nbytes;
   reg                                        tx_nbytes_en;
   
   //rx signals
   wire [`ETH_BUF_ADDR_W-1:0]                 rx_wr_addr;
   wire [`ETH_DATA_W-1:0]                     rx_wr_data; 
   wire                                       rx_wr;
   wire                                       rx_ready;
   reg                                        rx_ready_clr;
   wire [2*`ETH_DATA_W-1:0]                   rx_nbytes;
   

   // tx/rx buffers
   wire [`ETH_DATA_W-1:0]                     rx_rd_data; 
   
   // phy reset timer
   reg [3:0]                                  phy_rst_cnt;
   
   
   //
   // ASSIGNMENTS
   //
   
   assign GTX_CLK = 1'b0; //this will force 10/100 negotiation
   assign interrupt = interrupt_en & (tx_ready | rx_ready);
  
   
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

      // rx
      rx_ready_clr = 1'b0;

      case (addr)
	`ETH_INTRRPT_EN: interrupt_en_en = sel&we;
	`ETH_STATUS: data_out = { {30{1'b0}}, rx_ready, tx_ready};
	`ETH_CONTROL: tx_send = sel&we&data_in[0];
	`ETH_TX_NBYTES: tx_nbytes_en = sel&we;
	`ETH_MAC_ADDR_LO: mac_addr_lo_en = sel&we;
	`ETH_MAC_ADDR_HI: mac_addr_hi_en = sel&we;
	`ETH_DEST_MAC_ADDR_LO: begin 
           dest_mac_addr_lo_en = sel&we;
           data_out = dest_mac_addr[23:0];
        end
	`ETH_DEST_MAC_ADDR_HI: begin 
           dest_mac_addr_hi_en = sel&we;
           data_out = dest_mac_addr[47:24];
        end
	`ETH_SRC_MAC_ADDR_LO: data_out = src_mac_addr[23:0];
	`ETH_SRC_MAC_ADDR_HI: data_out = src_mac_addr[47:24];
	`ETH_RX_NBYTES: data_out = {{`ETH_DATA_W{1'b0}}, rx_nbytes};	   
	default: begin
           if (addr >= `ETH_TX_DATA && addr < `ETH_TX_DATA + 2**`ETH_BUF_ADDR_W)
	  tx_wr = sel&we;
	   if (addr >= `ETH_RX_DATA && addr < `ETH_RX_DATA + 2**`ETH_BUF_ADDR_W) begin
	      rx_ready_clr= sel&~we;
	      data_out = {{2*`ETH_DATA_W{1'b0}},rx_rd_data};
	   end
        end
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
       tx_nbytes <= data_in[2*`ETH_DATA_W-1:0];


   //
   // TX and RX BUFFERS
   //
   
`ifdef ETH_ALT_MEM_TYPE

   iob_eth_alt_s2p_mem  #(
			  .DATA_W(`ETH_DATA_W),
			  .ADDR_W(`ETH_BUF_ADDR_W)) 
   tx_buffer
     (
      // Back-End (written by host)
      .clk_a(clk),
      .addr_a(addr[`ETH_BUF_ADDR_W-1:0]),
      .data_a(data_in[`ETH_DATA_W-1:0]),
      .we_a(tx_wr),

      // Front-End (read by core)
      .clk_b(TX_CLK),
      .addr_b(tx_rd_addr),
      .q_b(tx_rd_data)
      );
 
   iob_eth_alt_s2p_mem  #(
			  .DATA_W(`ETH_DATA_W),
			  .ADDR_W(`ETH_BUF_ADDR_W)) 
   rx_buffer
     (
      // Front-End (written by core)
      .clk_a(RX_CLK),
      .addr_a(rx_wr_addr),
      .data_a(rx_wr_data),
      .we_a(rx_wr),

      // Back-End (read by host)
      .clk_b(clk),
      .addr_b(addr[`ETH_BUF_ADDR_W-1:0]),
      .q_b(rx_rd_data)
      );

`endif

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
		  .dest_mac_addr        (dest_mac_addr),
		   
		  //status
		  .ready                (tx_ready)
		  );
 
  

   //
   //RECEIVER
   //

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
		  .nbytes               (rx_nbytes),
		  .src_mac_addr         (src_mac_addr),
		  .mac_addr             (mac_addr),

		  .ready	        (rx_ready)
		  );

  

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
