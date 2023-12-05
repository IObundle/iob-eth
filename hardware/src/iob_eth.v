`timescale 1ns / 1ps

`include "iob_utils.vh"
`include "iob_eth_conf.vh"
`include "iob_eth_swreg_def.vh"

/*
 Ethernet Core
*/

module iob_eth # (
     `include "iob_eth_params.vs"
   ) (
     `include "iob_eth_io.vs"
   );

   `include "iob_wire.vs"

   assign iob_avalid = iob_avalid_i;
   assign iob_addr = iob_addr_i;
   assign iob_wdata = iob_wdata_i;
   assign iob_wstrb = iob_wstrb_i;
   assign iob_rvalid_o = iob_rvalid;
   assign iob_rdata_o = iob_rdata;
   assign iob_ready_o = iob_ready;

   //Dummy iob_ready_nxt and iob_rvalid_nxt to be used in swreg (unused ports)
   wire iob_ready_nxt;
   wire iob_rvalid_nxt;

   //BLOCK Register File & Configuration control and status register file.
   `include "iob_eth_swreg_inst.vs"

   wire [AXI_ADDR_W-1:0] internal_axi_awaddr_o;
   wire [AXI_ADDR_W-1:0] internal_axi_araddr_o;

   assign axi_awaddr_o = internal_axi_awaddr_o + MEM_ADDR_OFFSET;
   assign axi_araddr_o = internal_axi_araddr_o + MEM_ADDR_OFFSET;

   // ETH CLOCK DOMAIN
   wire  tx_ready;
   wire  rx_data_rcvd;
   wire [11-1:0] tx_nbytes;

   wire                         iob_eth_tx_buffer_enA;
   wire [`IOB_ETH_BUFFER_W-1:0] iob_eth_tx_buffer_addrA;
   wire [8-1:0]                iob_eth_tx_buffer_dinA;
   wire [`IOB_ETH_BUFFER_W-1:0] iob_eth_tx_buffer_addrB;
   wire [8-1:0]                iob_eth_tx_buffer_doutB;

   wire                         iob_eth_rx_buffer_enA;
   wire [`IOB_ETH_BUFFER_W-1:0] iob_eth_rx_buffer_addrA;
   wire [8-1:0]                iob_eth_rx_buffer_dinA;
   wire                         iob_eth_rx_buffer_enB;
   wire [`IOB_ETH_BUFFER_W-1:0] iob_eth_rx_buffer_addrB;
   wire [8-1:0]                iob_eth_rx_buffer_doutB;


   assign MIISTATUS_rd = {
      29'b0,
      1'b0, // NVALID
      1'b0, // BUSY
      1'b0 // LINKFAIL
   };

   assign MTxErr = 1'b0; //TODO

   //
   // SYNCHRONIZERS
   //
   
   // clk to MRxClk (f2s)
   wire  eth_send;
   wire  send;
   iob_sync #(
      .DATA_W(1)
   ) send_f2s_sync (
      .clk_i   (MTxClk),
      .arst_i   (arst_i),
      .signal_i (send),
      .signal_o (eth_send)
   );

   wire  rcv_ack;
   wire  eth_rcv_ack;
   iob_sync #(
      .DATA_W(1)
   ) rcv_f2s_sync (
      .clk_i   (MRxClk),
      .arst_i   (arst_i),
      .signal_i (rcv_ack),
      .signal_o (eth_rcv_ack)
   );

   // clk to MTxClk (f2s)
   wire  eth_crc_en;
   wire  crc_en;
   iob_sync #(
      .DATA_W(1)
   ) crc_en_f2s_sync (
      .clk_i   (MTxClk),
      .arst_i   (arst_i),
      .signal_i (crc_en),
      .signal_o (eth_crc_en)
   );

   // MRxClk to clk (s2f)

   wire  eth_crc_err;
   wire  crc_err;
   iob_sync #(
      .DATA_W(1)
   ) crc_err_sync (
      .clk_i   (clk_i),
      .arst_i   (arst_i),
      .signal_i (eth_crc_err),
      .signal_o (crc_err)
   );

   wire [`IOB_ETH_BUFFER_W-1:0] rx_nbytes;
   iob_sync #(
      .DATA_W(`IOB_ETH_BUFFER_W)
   ) rx_nbytes_sync (
      .clk_i   (clk_i),
      .arst_i   (arst_i),
      .signal_i (iob_eth_rx_buffer_addrA),
      .signal_o (rx_nbytes)
   );

   // MTxclk to clk (s2f)

   //
   // TRANSMITTER
   //

   iob_eth_tx tx (
      // cpu side
      .rst   (arst_i),
      .nbytes(tx_nbytes),
      .ready (tx_ready), //TODO: Should this have synchronizer?

      // mii side
      .send   (eth_send),
      .addr   (iob_eth_tx_buffer_addrB),
      .data   (iob_eth_tx_buffer_doutB),
      .TX_CLK (MTxClk),
      .TX_EN  (MTxEn),
      .TX_DATA(MTxD),
      .crc_en (eth_crc_en)
   );


   //
   // RECEIVER
   //

   iob_eth_rx rx (
      // cpu side
      .rst      (arst_i),
      .data_rcvd(rx_data_rcvd), //TODO: Should this have synchronizer?

      // mii side
      .rcv_ack  (eth_rcv_ack),
      .wr       (iob_eth_rx_buffer_enA),
      .addr     (iob_eth_rx_buffer_addrA),
      .data     (iob_eth_rx_buffer_dinA),
      .RX_CLK   (MRxClk),
      .RX_DATA  (MRxD),
      .RX_DV    (MRxDv),
      .crc_err  (eth_crc_err)
   );

   // BUFFER memories
   iob_ram_tdp_be #(
                       .DATA_W(8),
                       // Note: the tx buffer also includes PREAMBLE+SFD,
                       // maybe we should increase this size to acount for
                       // this.
                       .ADDR_W(`IOB_ETH_BUFFER_W)
                       )
   tx_buffer
   (
    // Front-End (written by host)
      .clkA_i(clk_i),
      .enA_i(iob_eth_tx_buffer_enA),
      .weA_i(iob_eth_tx_buffer_enA),
      .addrA_i(iob_eth_tx_buffer_addrA),
      .dA_i(iob_eth_tx_buffer_dinA),
      .dA_o(),

    // Back-End (read by core)
      .clkB_i(MTxClk),
      .enB_i(1'b1),
      .weB_i(1'b0),
      .addrB_i(iob_eth_tx_buffer_addrB),
      .dB_i(8'b0),
      .dB_o(iob_eth_tx_buffer_doutB)
   );

   iob_ram_tdp_be #(
                       .DATA_W(8),
                       .ADDR_W(`IOB_ETH_BUFFER_W)
                       )
   rx_buffer
   (
     // Front-End (written by core)
     .clkA_i(MRxClk),
     .enA_i(iob_eth_rx_buffer_enA),
     .weA_i(iob_eth_rx_buffer_enA),
     .addrA_i(iob_eth_rx_buffer_addrA),
     .dA_i(iob_eth_rx_buffer_dinA),
     .dA_o(),

     // Back-End (read by host)
     .clkB_i(clk_i),
     .enB_i(iob_eth_rx_buffer_enB),
     .weB_i(1'b0),
     .addrB_i(iob_eth_rx_buffer_addrB),
     .dB_i(8'b0),
     .dB_o(iob_eth_rx_buffer_doutB)
   );

   // DMA buffer descriptor wires
   wire dma_bd_en;
   wire [7:0] dma_bd_addr;
   wire dma_bd_wen;
   wire [31:0] dma_bd_i;
   wire [31:0] dma_bd_o;
   wire rx_irq;
   wire tx_irq;
   assign inta_o = rx_irq | tx_irq;

   // DMA module
   iob_eth_dma #(
      .AXI_ADDR_W(AXI_ADDR_W),
      .AXI_DATA_W(AXI_DATA_W),
      .AXI_LEN_W (AXI_LEN_W),
      .AXI_ID_W  (AXI_ID_W),
      //.BURST_W   (BURST_W),
      .BUFFER_W  (`IOB_ETH_BUFFER_W),
      .BD_ADDR_W (BD_NUM_LOG2+1)
   ) dma_inst (
      // Control interface
      .rx_en_i(MODER_wr[0]),
      .tx_en_i(MODER_wr[1]),
      .tx_bd_num_i(TX_BD_NUM_wr[BD_NUM_LOG2:0]),

      // Buffer descriptors
      .bd_en_o(dma_bd_en),
      .bd_addr_o(dma_bd_addr),
      .bd_wen_o(dma_bd_wen),
      .bd_i(dma_bd_i),
      .bd_o(dma_bd_o),

      // TX Front-End
      .eth_data_wr_wen_o(iob_eth_tx_buffer_enA), // |ETH_DATA_WR_wstrb
      .eth_data_wr_addr_o(iob_eth_tx_buffer_addrA),
      .eth_data_wr_wdata_o(iob_eth_tx_buffer_dinA),
      .tx_ready_i(tx_ready),
      .crc_en_o(crc_en),
      .tx_nbytes_o(tx_nbytes),
      .send_o(send),

      // RX Back-End
      .eth_data_rd_ren_o(iob_eth_rx_buffer_enB),
      .eth_data_rd_addr_o(iob_eth_rx_buffer_addrB),
      .eth_data_rd_rdata_i(iob_eth_rx_buffer_doutB),
      .rx_data_rcvd_i(rx_data_rcvd),
      .crc_err_i(crc_err),
      .rx_nbytes_i(rx_nbytes),
      .rcv_ack_o(rcv_ack),

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

      // No-DMA interface TODO
      .tx_bd_cnt_o(),
      .tx_word_cnt_o(),
      .tx_frame_word_wen_i(1'b0),
      .tx_frame_word_wdata_i(8'b0),
      .rx_bd_cnt_o(),
      .rx_word_cnt_o(),
      .rx_frame_word_ren_i(1'b0),
      .rx_frame_word_rdata_o(),

      // Interrupts
      .tx_irq_o(tx_irq),
      .rx_irq_o(rx_irq),

      // General signals interface
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i)
   );

   wire [31:0] buffer_addr = (iob_addr_i-`IOB_ETH_BD_ADDR)>>2;

   assign BD_wready_wr = 1'b1;
   assign BD_rready_rd = 1'b1;

   // Buffer descriptors memory
   iob_ram_dp #(
      .DATA_W(32),
      .ADDR_W(BD_NUM_LOG2+1),
      .MEM_NO_READ_ON_WRITE(1)
   ) bd_ram (
      .clk_i(clk_i),

      // Port A - SWregs
      .addrA_i(buffer_addr[BD_NUM_LOG2:0]),
      .enA_i(BD_wen_wr || BD_ren_rd),
      .weA_i(BD_wen_wr),
      .dA_i(iob_wdata_i),
      .dA_o(BD_rdata_rd),

      // Port B - DMA module
      .addrB_i(dma_bd_addr),
      .enB_i(dma_bd_en),
      .weB_i(dma_bd_wen),
      .dB_i(dma_bd_o),
      .dB_o(dma_bd_i)
   );

endmodule
