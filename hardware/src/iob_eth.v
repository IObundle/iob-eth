`timescale 1ns / 1ps

`include "iob_utils.vh"
`include "iob_eth.vh"
`include "iob_eth_swreg_def.vh"

/*
 Ethernet Core
*/

module iob_eth # (
     `include "iob_eth_params.vs"
   ) (
     `include "iob_eth_io.vs"
   );

   //Dummy iob_ready_nxt_o and iob_rvalid_nxt_o to be used in swreg (unused ports)
   wire iob_ready_nxt_o;
   wire iob_rvalid_nxt_o;

   //TODO: Update below

    //BLOCK Register File & Configuration control and status register file.
    `include "iob_eth_swreg_gen.vs"

   //BLOCK Register File & Configuration control and status register file.
   `include "iob_eth_swreg_gen.vs"

   //
   // SWRegs
   //

   wire ETH_SEND;
   iob_reg #(
      .DATA_W(1)
   ) eth_send (
      .clk     (clk),
      .arst    (rst),
      .rst     (rst),
      .en      (ETH_SEND_en),
      .data_in (ETH_SEND_wdata[0]),
      .data_out(ETH_SEND)
   );

   wire ETH_RCVACK;
   iob_reg #(
      .DATA_W(1)
   ) eth_rcvack (
      .clk     (clk),
      .arst    (rst),
      .rst     (rst),
      .en      (ETH_RCVACK_en),
      .data_in (ETH_RCVACK_wdata[0]),
      .data_out(ETH_RCVACK)
   );

   wire ETH_SOFTRST;
   iob_reg #(
      .DATA_W(1)
   ) eth_softrst (
      .clk     (clk),
      .arst    (rst),
      .rst     (rst),
      .en      (ETH_SOFTRST_en),
      .data_in (ETH_SOFTRST_wdata[0]),
      .data_out(ETH_SOFTRST)
   );

   iob_reg #(
      .DATA_W(32)
   ) eth_dummy_w (
      .clk     (clk),
      .arst    (rst),
      .rst     (rst),
      .en      (ETH_DUMMY_W_en),
      .data_in (ETH_DUMMY_W_wdata),
      .data_out(ETH_DUMMY_R_rdata)
   );

   wire [11-1:0] ETH_TX_NBYTES;
   iob_reg #(
      .DATA_W (11),
      .RST_VAL(11'd46)
   ) eth_tx_nbytes (
      .clk     (clk),
      .arst    (rst),
      .rst     (rst),
      .en      (ETH_TX_NBYTES_en),
      .data_in (ETH_TX_NBYTES_wdata[10:0]),
      .data_out(ETH_TX_NBYTES)
   );

   //
   // WIRES and REGISTERS
   //
   wire [1-1:0] rst_int;

   // ETH CLOCK DOMAIN
   reg [1-1:0] phy_clk_detected;
   reg [1-1:0] phy_dv_detected;
   wire [`ETH_CRC_W-1:0] crc_value;
   wire [1-1:0] tx_ready_int;
   wire [1-1:0] tx_ready_int_pll;
   wire [1-1:0] tx_ready_int_reg;
   wire [1-1:0] rx_data_rcvd_int;
   wire [1-1:0] rx_data_rcvd_int_phy;
   wire [1-1:0] rx_data_rcvd_int_reg;

   wire [11-1:0] tx_rd_addr;
   reg [8-1:0] tx_rd_data;

   wire [11-1:0] rx_wr_addr;
   wire [8-1:0] rx_wr_data;
   wire [1-1:0] rx_wr;

   // Ethernet Status
   wire [1-1:0] pll_locked_sync;
   wire [1-1:0] phy_clk_detected_sync;
   wire [1-1:0] phy_dv_detected_sync;
   wire [1-1:0] rx_data_rcvd_sync;
   wire [1-1:0] tx_ready_sync;

   assign ETH_STATUS_rdata = {
      16'b0,
      pll_locked_sync,
      ETH_RCV_SIZE_rdata[10:0],
      phy_clk_detected_sync,
      phy_dv_detected_sync,
      rx_data_rcvd_sync,
      tx_ready_sync
   };

   // Ethernet CRC

   // Ethernet RCV_SIZE
   assign ETH_RCV_SIZE_rdata[15:11] = 5'b0;  // bit unused by core

   // Ethernet Send

   // Ethernet Rcv Ack

   //
   // REGISTERS
   //

   // soft reset self-clearing register
   reg [1-1:0] rst_soft;
   always @(posedge clk, posedge rst)
      if (rst) rst_soft <= 1'b1;
      else if (ETH_SOFTRST && !rst_soft) rst_soft <= 1'b1;
      else rst_soft <= 1'b0;

   assign rst_int              = rst_soft | rst;

   assign rx_data_rcvd_int_phy = rx_data_rcvd_int & ETH_PHY_RESETN;
   iob_reg #(
      .DATA_W(1)
   ) rx_data_rcvd_int_register (
      .clk     (RX_CLK),
      .arst    (rst),
      .rst     (rst),
      .en      (1'b1),
      .data_in (rx_data_rcvd_int_phy),
      .data_out(rx_data_rcvd_int_reg)
   );

   assign tx_ready_int_pll = tx_ready_int & ETH_PHY_RESETN & PLL_LOCKED;
   iob_reg #(
      .DATA_W(1)
   ) tx_ready_int_register (
      .clk     (RX_CLK),
      .arst    (rst),
      .rst     (rst),
      .en      (1'b1),
      .data_in (tx_ready_int_pll),
      .data_out(tx_ready_int_reg)
   );

   //
   // SYNCHRONIZERS
   //

   // RX_CLK to clk

   iob_sync #(
      .DATA_W(1),
      .RST_VAL(1'b0)
   ) iob_sync_pll (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(PLL_LOCKED),
      .signal_o(pll_locked_sync)
   );
   iob_sync #(
      .DATA_W(11),
      .RST_VAL(1'b0)
   ) iob_sync_rx_wr_addr (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(rx_wr_addr),
      .signal_o(ETH_RCV_SIZE_rdata[10:0])
   );
   iob_sync #(
      .DATA_W(1),
      .RST_VAL(1'b0)
   ) iob_sync_phy_clk_detected (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(phy_clk_detected),
      .signal_o(phy_clk_detected_sync)
   );
   iob_sync #(
      .DATA_W(1),
      .RST_VAL(1'b0)
   ) iob_sync_phy_dv_detected (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(phy_dv_detected),
      .signal_o(phy_dv_detected_sync)
   );
   iob_sync #(
      .DATA_W(1),
      .RST_VAL(1'b0)
   ) iob_sync_rx_data_rcvd (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(rx_data_rcvd_int_reg),
      .signal_o(rx_data_rcvd_sync)
   );
   iob_sync #(
      .DATA_W(1),
      .RST_VAL(1'b0)
   ) iob_sync_tx_ready (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(tx_ready_int_reg),
      .signal_o(tx_ready_sync)
   );
   iob_sync #(
      .DATA_W(`ETH_CRC_W),
      .RST_VAL(1'b0)
   ) iob_sync_eth_crc (
      .clk     (clk),
      .rst     (rst_int),
      .signal_i(crc_value),
      .signal_o(ETH_CRC_rdata)
   );

   // clk to RX_CLK
   wire [1-1:0] send;
   iob_f2s_1bit_sync (
      .clk_i   (TX_CLK),
      .cke_i   (cke),
      .value_i (ETH_SEND),
      .value_o (send)
   );)
   wire [1-1:0] rcv_ack;
   iob_f2s_1bit_sync (
      .clk_i   (RX_CLK),
      .cke_i   (cke),
      .value_i (ETH_RCVACK),
      .value_o (rcv_ack)
   );

   //
   // TX and RX BUFFERS
   //
   wire [32-1:0] tx_rd_data_int;

   // TX Buffer Logic
   // TX Front-End
   assign iob_eth_tx_buffer_enA   = |ETH_DATA_WR_wstrb;
   assign iob_eth_tx_buffer_weA   = ETH_DATA_WR_wstrb;
   assign iob_eth_tx_buffer_addrA = ETH_DATA_WR_addr;
   assign iob_eth_tx_buffer_dinA  = ETH_DATA_WR_wdata;

   // TX Back-End
   assign iob_eth_tx_buffer_addrB = tx_rd_addr[10:2];
   assign tx_rd_data_int          = iob_eth_tx_buffer_doutB;

   wire [2-1:0] tx_rd_addr_reg;
   iob_reg #(
      .DATA_W(2)
   ) tx_rd_addr_r (
      .clk_i (TX_CLK),
      .arst_i(1'b0),
      .cke_i (1'b1),
      .data_i(tx_rd_addr[1:0]),
      .data_o(tx_rd_addr_reg)
   );
   // choose byte from 4 bytes word
   always @* begin
      case (tx_rd_addr_reg)
         0:       tx_rd_data = tx_rd_data_int[0+:8];
         1:       tx_rd_data = tx_rd_data_int[8+:8];
         2:       tx_rd_data = tx_rd_data_int[16+:8];
         default: tx_rd_data = tx_rd_data_int[24+:8];
      endcase
   end

   wire [4-1:0] rx_wr_wstrb_int;
   wire [32-1:0] rx_wr_data_int;

   // RX Buffer Logic
   // RX Front-End
   assign iob_eth_rx_buffer_enA   = rx_wr;
   assign iob_eth_rx_buffer_weA   = rx_wr_wstrb_int;
   assign iob_eth_rx_buffer_addrA = rx_wr_addr[10:2];
   assign iob_eth_rx_buffer_dinA  = rx_wr_data_int;

   // RX Back-End
   assign iob_eth_rx_buffer_enB   = ETH_DATA_RD_ren;
   assign iob_eth_rx_buffer_addrB = ETH_DATA_RD_addr;
   assign ETH_DATA_RD_rdata       = iob_eth_rx_buffer_doutB;

   assign rx_wr_data_int = rx_wr_data << (8 * rx_wr_addr[1:0])
   assign rx_wr_wstrb_int = rx_wr << rx_wr_addr[1:0]

   //
   // TRANSMITTER
   //

   iob_eth_tx tx (
      // cpu side
      .rst   (rst_int),
      .nbytes(ETH_TX_NBYTES),
      .ready (tx_ready_int),

      // mii side
      .send   (send),
      .addr   (tx_rd_addr),
      .data   (tx_rd_data),
      .TX_CLK (TX_CLK),
      .TX_EN  (TX_EN),
      .TX_DATA(TX_DATA)
   );


   //
   // RECEIVER
   //

   iob_eth_rx #(
      .ETH_MAC_ADDR(ETH_MAC_ADDR)
   ) rx (
      // cpu side
      .rst      (rst_int),
      .data_rcvd(rx_data_rcvd_int),

      // mii side
      .rcv_ack  (rcv_ack),
      .wr       (rx_wr),
      .addr     (rx_wr_addr),
      .data     (rx_wr_data),
      .RX_CLK   (RX_CLK),
      .RX_DATA  (RX_DATA),
      .RX_DV    (RX_DV),
      .crc_value(crc_value)
   );


   //
   //  PHY RESET
   //
  wire [20-1:0] phy_rst_cnt;

   always @(posedge clk, posedge rst_int)
      if (rst_int) begin
         phy_rst_cnt    <= 0;
         ETH_PHY_RESETN <= 0;
      end else if (phy_rst_cnt != PHY_RST_CNT) phy_rst_cnt <= phy_rst_cnt + 1'b1;
      else ETH_PHY_RESETN <= 1;

   reg [1:0] rx_rst;
   always @(posedge RX_CLK, negedge ETH_PHY_RESETN)
      if (!ETH_PHY_RESETN) rx_rst <= 2'b11;
      else rx_rst <= {rx_rst[0], 1'b0};

   always @(posedge RX_CLK, posedge rx_rst[1])
      if (rx_rst[1]) begin
         phy_clk_detected <= 1'b0;
         phy_dv_detected  <= 1'b0;
      end else begin
         phy_clk_detected <= 1'b1;
         if (RX_DV) phy_dv_detected <= 1'b1;
      end

endmodule
