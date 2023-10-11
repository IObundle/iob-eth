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

   //BLOCK Register File & Configuration control and status register file.
   `include "iob_eth_swreg_inst.vs"

   wire [AXI_ADDR_W-1:0] internal_axi_awaddr_o;
   wire [AXI_ADDR_W-1:0] internal_axi_araddr_o;

   assign axi_awaddr_o = internal_axi_awaddr_o + MEM_ADDR_OFFSET;
   assign axi_araddr_o = internal_axi_araddr_o + MEM_ADDR_OFFSET;

   //
   // SWRegs
   //
   // wire ETH_SEND;
   // wire ETH_RCVACK;
   // wire ETH_SOFTRST;
   // wire [11-1:0] ETH_TX_NBYTES;

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

   assign MIISTATUS = {
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
      .clk     (MRxClk),
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
      .clk     (MRxClk),
      .arst    (rst),
      .rst     (rst),
      .en      (1'b1),
      .data_in (tx_ready_int_pll),
      .data_out(tx_ready_int_reg)
   );

   //
   // SYNCHRONIZERS
   //

   // MRxClk to clk

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

   // clk to MRxClk
   wire [1-1:0] send;
   iob_f2s_1bit_sync (
      .clk_i   (MTxClk),
      .cke_i   (cke),
      .value_i (ETH_SEND),
      .value_o (send)
   );)
   wire [1-1:0] rcv_ack;
   iob_f2s_1bit_sync (
      .clk_i   (MRxClk),
      .cke_i   (cke),
      .value_i (ETH_RCVACK),
      .value_o (rcv_ack)
   );

   //
   // TX and RX BUFFERS
   //
   wire [32-1:0] tx_rd_data_int;

   // TX Buffer Logic
   // TX Back-End
   assign iob_eth_tx_buffer_addrB = tx_rd_addr[10:2];
   assign tx_rd_data_int          = iob_eth_tx_buffer_doutB;

   wire [2-1:0] tx_rd_addr_reg;
   iob_reg #(
      .DATA_W(2)
   ) tx_rd_addr_r (
      .clk_i (MTxClk),
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
      .TX_CLK (MTxClk),
      .TX_EN  (MTxEn),
      .TX_DATA(MTxD)
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
      .RX_CLK   (MRxClk),
      .RX_DATA  (MRxD),
      .RX_DV    (MRxDv),
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
   always @(posedge MRxClk, negedge ETH_PHY_RESETN)
      if (!ETH_PHY_RESETN) rx_rst <= 2'b11;
      else rx_rst <= {rx_rst[0], 1'b0};

   always @(posedge MRxClk, posedge rx_rst[1])
      if (rx_rst[1]) begin
         phy_clk_detected <= 1'b0;
         phy_dv_detected  <= 1'b0;
      end else begin
         phy_clk_detected <= 1'b1;
         if (MRxDv) phy_dv_detected <= 1'b1;
      end

   // BUFFER memories
   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_WR_ADDR_W)
                       )
   tx_buffer
   (
    // Front-End (written by host)
      .clkA(clk),
      .enA(iob_eth_tx_buffer_enA),
      .weA(iob_eth_tx_buffer_weA),
      .addrA(iob_eth_tx_buffer_addrA),
      .dinA(iob_eth_tx_buffer_dinA),
      .doutA(),

    // Back-End (read by core)
      .clkB(MTxClk),
      .enB(1'b1),
      .weB(4'b0),
      .addrB(iob_eth_tx_buffer_addrB),
      .dinB(32'b0),
      .doutB(iob_eth_tx_buffer_doutB)
   );

   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_RD_ADDR_W)
                       )
   rx_buffer
   (
     // Front-End (written by core)
     .clkA(MRxClk),

     .enA(iob_eth_rx_buffer_enA),
     .weA(iob_eth_rx_buffer_weA),
     .addrA(iob_eth_rx_buffer_addrA),
     .dinA(iob_eth_rx_buffer_dinA),
     .doutA(),

     // Back-End (read by host)
     .clkB(clk),
     .enB(iob_eth_rx_buffer_enB),
     .weB(4'b0),
     .addrB(iob_eth_rx_buffer_addrB),
     .dinB(32'b0),
     .doutB(iob_eth_rx_buffer_doutB)
   );

   // DMA buffer descriptor wires
   wire dma_bd_en;
   wire [7:0] dma_bd_addr;
   wire dma_bd_wen;
   wire [31:0] dma_bd_i;
   wire [31:0] dma_bd_o;

   // DMA module
  iob_eth_dma #(
    .AXI_ADDR_W(AXI_ADDR_W),
    .AXI_DATA_W(AXI_DATA_W),
    .AXI_LEN_W (AXI_LEN_W),
    .AXI_ID_W  (AXI_ID_W),
    //.BURST_W   (BURST_W),
    //.BUFFER_W  (BUFFER_W)
    .BD_ADDR_W (BD_NUM_LOG2+1)
  ) dma_inst (
   // Control interface
   .rx_en_i(MODER[0]),
   .tx_en_i(MODER[1]),
   .tx_bd_num_i(TX_BD_NUM[BD_NUM_LOG2:0]),

   // Buffer descriptors
   .bd_en_o(dma_bd_en),
   .bd_addr_o(dma_bd_addr),
   .bd_wen_o(dma_bd_wen),
   .bd_i(dma_bd_i),
   .bd_o(dma_bd_o),

   // TX Front-End
   .eth_data_wr_wen_o(iob_eth_tx_buffer_enA), // |ETH_DATA_WR_wstrb
   .eth_data_wr_wstrb_o(iob_eth_tx_buffer_weA),
   .eth_data_wr_addr_o(iob_eth_tx_buffer_addrA),
   .eth_data_wr_wdata_o(iob_eth_tx_buffer_dinA),

   // RX Back-End
   .eth_data_rd_ren_o(iob_eth_rx_buffer_enB),
   .eth_data_rd_addr_o(iob_eth_rx_buffer_addrB),
   .eth_data_rd_rdata_i(iob_eth_rx_buffer_doutB),

    // AXI master interface
    // Can't use generated include, because of `internal_axi_*addr_o` signals.
    //include "axi_m_m_portmap.vs"
    .axi_awid_o(axi_awid_o), //Address write channel ID.
    .axi_awaddr_o(internal_axi_awaddr_o), //Address write channel address.
    .axi_awlen_o(axi_awlen_o), //Address write channel burst length.
    .axi_awsize_o(axi_awsize_o), //Address write channel burst size. This signal indicates the size of each transfer in the burst.
    .axi_awburst_o(axi_awburst_o), //Address write channel burst type.
    .axi_awlock_o(axi_awlock_o), //Address write channel lock type.
    .axi_awcache_o(axi_awcache_o), //Address write channel memory type. Set to 0000 if master output; ignored if slave input.
    .axi_awprot_o(axi_awprot_o), //Address write channel protection type. Set to 000 if master output; ignored if slave input.
    .axi_awqos_o(axi_awqos_o), //Address write channel quality of service.
    .axi_awvalid_o(axi_awvalid_o), //Address write channel valid.
    .axi_awready_i(axi_awready_i), //Address write channel ready.
    .axi_wdata_o(axi_wdata_o), //Write channel data.
    .axi_wstrb_o(axi_wstrb_o), //Write channel write strobe.
    .axi_wlast_o(axi_wlast_o), //Write channel last word flag.
    .axi_wvalid_o(axi_wvalid_o), //Write channel valid.
    .axi_wready_i(axi_wready_i), //Write channel ready.
    .axi_bid_i(axi_bid_i), //Write response channel ID.
    .axi_bresp_i(axi_bresp_i), //Write response channel response.
    .axi_bvalid_i(axi_bvalid_i), //Write response channel valid.
    .axi_bready_o(axi_bready_o), //Write response channel ready.
    .axi_arid_o(axi_arid_o), //Address read channel ID.
    .axi_araddr_o(internal_axi_araddr_o), //Address read channel address.
    .axi_arlen_o(axi_arlen_o), //Address read channel burst length.
    .axi_arsize_o(axi_arsize_o), //Address read channel burst size. This signal indicates the size of each transfer in the burst.
    .axi_arburst_o(axi_arburst_o), //Address read channel burst type.
    .axi_arlock_o(axi_arlock_o), //Address read channel lock type.
    .axi_arcache_o(axi_arcache_o), //Address read channel memory type. Set to 0000 if master output; ignored if slave input.
    .axi_arprot_o(axi_arprot_o), //Address read channel protection type. Set to 000 if master output; ignored if slave input.
    .axi_arqos_o(axi_arqos_o), //Address read channel quality of service.
    .axi_arvalid_o(axi_arvalid_o), //Address read channel valid.
    .axi_arready_i(axi_arready_i), //Address read channel ready.
    .axi_rid_i(axi_rid_i), //Read channel ID.
    .axi_rdata_i(axi_rdata_i), //Read channel data.
    .axi_rresp_i(axi_rresp_i), //Read channel response.
    .axi_rlast_i(axi_rlast_i), //Read channel last word.
    .axi_rvalid_i(axi_rvalid_i), //Read channel valid.
    .axi_rready_o(axi_rready_o), //Read channel ready.

    // General signals interface
    .clk_i (clk),
    .cke_i (cke),
    .arst_i(rst)
  );

  // Buffer descriptors memory
   iob_ram_dp #(
      .DATA_W(32),
      .ADDR_W(BD_NUM_LOG2+1),
      .MEM_NO_READ_ON_WRITE(1),
   ) bd_ram (
      .clk_i(clk),

      // Port A - SWregs
      .addrA_i((iob_addr_i-IOB_ETH_BD_ADDR)>>2),
      .enA_i(BD_addressed),
      .weA_i(BD_wen_o),
      .dA_i(iob_wdata_i),
      .dA_o(BD_i),

      // Port B - DMA module
      .addrB_i(dma_bd_addr),
      .enB_i(dma_bd_en),
      .weB_i(dma_bd_wen),
      .dB_i(dma_bd_o),
      .dB_o(dma_bd_i)
   );

endmodule
