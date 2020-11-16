`timescale 1ns/1ps
`include "iob_eth_defs.vh"

/*

 Ethernet Core

*/

module iob_eth #(
                   parameter ETH_MAC_ADDR = `ETH_MAC_ADDR
                ) (
		
		// CPU side
		input                   clk,
		input                   rst,
		input                   valid,
		output reg		ready,
		input                   wstrb,
		input [`ETH_ADDR_W-1:0] addr,
		output reg [31:0]       data_out,
		input [31:0]            data_in,

		// PHY side
		output reg              ETH_PHY_RESETN,

                // PLL
                input                   PLL_LOCKED,

		// RX
		input                   RX_CLK,
		input [3:0]             RX_DATA,
		input                   RX_DV,

		//TX
		input                   TX_CLK,
		output                  TX_EN,
		output [3:0]            TX_DATA

		);

   //registers
   //dummy
   reg [31:0]                           dummy_reg;
   reg                                  dummy_reg_en;
   //tx_nbytes
   reg [10:0]                           tx_nbytes_reg;
   reg                                  tx_nbytes_reg_en;
   //rx_nbytes
   reg [10:0]                           rx_nbytes_reg;
   reg                                  rx_nbytes_reg_en;

   //control
   reg                                  send_en;
   reg                                  send;

   reg                                  rcv_ack_en;
   reg                                  rcv_ack;
   
   //tx signals
   reg                                  tx_wr;
   reg [1:0]                            tx_ready;
   reg [1:0]                            tx_clk_pll_locked;
   wire                                 tx_ready_int;
   
   //rx signals
   reg [1:0]                            rx_data_rcvd;
   wire                                 rx_data_rcvd_int;
   wire [7:0]                           rx_rd_data;
   reg [10:0]                           rx_wr_addr_cpu[1:0];
   reg [31:0]                           crc_value_cpu[1:0];
                      
   // phy reset timer
   reg [19:0]                            phy_rst_cnt;
   reg                                   phy_clk_detected;
   reg                                   phy_dv_detected;
   reg [1:0]                             phy_clk_detected_sync;
   reg [1:0]                             phy_dv_detected_sync;

   reg                                   rst_soft_en;
   reg                                   rst_soft;
   wire                                  rst_int;

   //ETH CLOCK DOMAIN
   wire [10:0]                          tx_rd_addr;
   wire [7:0]                           tx_rd_data;

   wire [10:0]                          rx_wr_addr;
   wire [7:0]                           rx_wr_data;
   wire                                 rx_wr;
   wire [31:0]                          crc_value;

   
   assign rst_int = rst_soft | rst;
   
   //SYNCHRONIZERS 
   always @ (posedge clk, posedge rst_int)
      if(rst_int) begin
         tx_ready <= 0;
         tx_clk_pll_locked <= 0;
         rx_data_rcvd <= 0;
         rx_wr_addr_cpu[0] <= 0;
         rx_wr_addr_cpu[1] <= 0;         
         crc_value_cpu[0] <= 0;
         crc_value_cpu[1] <= 0;         
         phy_clk_detected_sync <= 0;
         phy_dv_detected_sync <= 0;
      end else begin
         tx_clk_pll_locked <= {tx_clk_pll_locked[0], PLL_LOCKED};
         tx_ready <= {tx_ready[0], tx_ready_int & ETH_PHY_RESETN & PLL_LOCKED};
         rx_data_rcvd <= {rx_data_rcvd[0], rx_data_rcvd_int & ETH_PHY_RESETN};
         rx_wr_addr_cpu[0] <= rx_wr_addr;
         rx_wr_addr_cpu[1] <= rx_wr_addr_cpu[0];         
         crc_value_cpu[0] <= crc_value;
         crc_value_cpu[1] <= crc_value_cpu[0];         
         phy_clk_detected_sync <= {phy_clk_detected_sync[0], phy_clk_detected};
         phy_dv_detected_sync <= {phy_dv_detected_sync[0], phy_dv_detected};
      end 

   // cpu interface ready signal
   always @(posedge clk, posedge rst)
      if(rst)
         ready <= 1'b0;
      else 
         ready <= valid;

   //
   // ADDRESS DECODER
   //

   //write 
   always @* begin

      //defaults
      rst_soft_en = 0;
      send_en = 0;
      rcv_ack_en = 0;
      dummy_reg_en = 0;
      tx_nbytes_reg_en = 0;
      rx_nbytes_reg_en = 0;
      tx_wr = 1'b0;

      if(valid & wstrb)
        case (addr)
	  `ETH_SEND: send_en = 1'b1;
	  `ETH_RCVACK: rcv_ack_en = 1'b1;
          `ETH_DUMMY: dummy_reg_en = 1'b1;
          `ETH_TX_NBYTES: tx_nbytes_reg_en = 1'b1;
          `ETH_RX_NBYTES: rx_nbytes_reg_en = 1'b1;
          `ETH_SOFTRST: rst_soft_en  = 1'b1;
          default: tx_wr = addr[11] & 1'b1; //ETH_DATA
        endcase
   end


   //read 
   always @* begin
      case (addr)
	`ETH_STATUS: data_out = {16'b0, tx_clk_pll_locked[1], rx_wr_addr_cpu[1], phy_clk_detected_sync[1], phy_dv_detected_sync[1], rx_data_rcvd[1], tx_ready[1]};
        `ETH_DUMMY: data_out = dummy_reg;
        `ETH_CRC: data_out = crc_value_cpu[1];
        default: data_out = {24'd0, rx_rd_data}; //ETH_DATA
      endcase
   end

   //
   // REGISTERS
   //

   //soft reset self-clearing register
   always @ (posedge clk, posedge rst)
     if (rst)
       rst_soft <= 1'b1;
     else if (rst_soft_en && !rst_soft)
       rst_soft <= 1'b1;
     else
       rst_soft <= 1'b0;

   //tx send self-clearing register
   always @ (posedge clk, posedge rst_int)
     if (rst_int)
       send <= 1'b0;
     else if (send_en && !send)
       send <= 1'b1;
     else
       send <= 1'b0;

   //rx rcv ack self-clearing register
   always @ (posedge clk, posedge rst_int)
     if (rst_int)
       rcv_ack <= 1'b0;
     else if (rcv_ack_en && !rcv_ack)
       rcv_ack <= 1'b1;
     else
       rcv_ack <= 1'b0;

   always @ (posedge clk, posedge rst_int)
      if (rst_int) begin 
        tx_nbytes_reg <= 11'd46;
        rx_nbytes_reg <= 11'd46;
        dummy_reg <= 0;
      end else if(dummy_reg_en)
        dummy_reg <= data_in;
      else if(tx_nbytes_reg_en)
        tx_nbytes_reg <= data_in[10:0];
      else if(rx_nbytes_reg_en)
        rx_nbytes_reg <= data_in[10:0];
  
   
   //
   // TX and RX BUFFERS
   //

   iob_eth_alt_s2p_mem  #(
			  .DATA_W(8),
			  .ADDR_W(`ETH_ADDR_W-1)
                          )
   tx_buffer
     (
      // Back-End (written by host)
      .clk_a(clk),
      .addr_a(addr[10:0]),
      .data_a(data_in[7:0]),
      .we_a(tx_wr),

      // Front-End (read by core)
      .clk_b(TX_CLK),
      .addr_b(tx_rd_addr),
      .data_b(tx_rd_data)
      );

   iob_eth_alt_s2p_mem  #(
			  .DATA_W(8),
			  .ADDR_W(`ETH_ADDR_W-1)
                          )
   rx_buffer
     (
      // Front-End (written by core)
      .clk_a(RX_CLK),
      .addr_a(rx_wr_addr),
      .data_a(rx_wr_data),
      .we_a(rx_wr),

      // Back-End (read by host)
      .clk_b(clk),
      .addr_b(addr[10:0]),
      .data_b(rx_rd_data)
      );


   //
   //TRANSMITTER
   //

   iob_eth_tx tx (
                  //cpu side
		  .rst			(rst_int),
                  .nbytes               (tx_nbytes_reg),
                  .send                 (send),
		  .ready                (tx_ready_int),
                  //mii side 
		  .addr	       	        (tx_rd_addr),
		  .data	       	        (tx_rd_data),
		  .TX_CLK		(TX_CLK),
		  .TX_EN		(TX_EN),
		  .TX_DATA		(TX_DATA)
		  );


   //
   //RECEIVER
   //

   iob_eth_rx #(
                 .ETH_MAC_ADDR(ETH_MAC_ADDR)
               )

		rx (
                  //cpu side
		  .rst			(rst_int),
                  .nbytes               (rx_nbytes_reg),
		  .data_rcvd	        (rx_data_rcvd_int),
                  .rcv_ack              (rcv_ack),
                  //mii side
		  .wr                   (rx_wr),
		  .addr		        (rx_wr_addr),
		  .data		        (rx_wr_data),
                  .RX_CLK		(RX_CLK),
		  .RX_DATA		(RX_DATA),
		  .RX_DV		(RX_DV),
                  .crc_value            (crc_value)
		  );


   //
   //  PHY RESET
   //
   
   always @ (posedge clk, posedge rst_int)
     if(rst_int) begin
        phy_rst_cnt <= 0;
	ETH_PHY_RESETN <= 0;
     end else 
`ifdef SIM //Faster for simulation
     if(phy_rst_cnt != 20'h000FF)
`else
     if(phy_rst_cnt != 20'hFFFFF)
`endif
        phy_rst_cnt <= phy_rst_cnt+1'b1;
     else
       ETH_PHY_RESETN <= 1;

   reg [1:0] rx_rst;
   always @ (posedge RX_CLK, negedge ETH_PHY_RESETN)
     if(!ETH_PHY_RESETN)
       rx_rst <= 2'b11;
     else
       rx_rst <= {rx_rst[0], 1'b0};
   
   always @ (posedge RX_CLK, posedge rx_rst[1])
     if(rx_rst[1]) begin
       phy_clk_detected <= 1'b0;
       phy_dv_detected <= 1'b0;
     end else begin 
        phy_clk_detected <= 1'b1;
        if(RX_DV)
          phy_dv_detected <= 1'b1;
     end
   
endmodule
