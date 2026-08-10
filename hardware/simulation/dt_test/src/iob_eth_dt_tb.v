// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0
//
// Standalone testbench for iob_eth_dt.
//
// Harness mirrors iob_eth.v around the Data Transfer block:
//   - BD RAM (iob_ram_tdp), port B to the DT, port A to the TB (preload/check)
//   - TX data FIFO (8-bit, written by DT in system clock, read by TB)
//   - RX data FIFO (8-bit, written by TB, read by DT) + RX info FIFO (12-bit)
//   - external memory via iob_axi_ram + iob_ram_t2p_be (DMA path)
//
// The AXI read/write handshakes can be blocked (regs) to emulate the SoC
// simulation path, where the eth AXI write is tied off and TX/RX use the
// no-DMA frame_word interface.
//
// Tests:
//   1. TX no-DMA: BD ready -> CPU writes frame words -> TX FIFO gets
//      preamble+SFD+frame, crc_en/send, BD status + tx_irq
//   2. RX no-DMA: info+data FIFOs -> rx_nbytes_valid + frame words to CPU,
//      BD status (len/crc/ready) + rx_irq
//   3. TX DMA: BD + buffer pointer -> AXI read burst -> same checks
//   4. RX DMA: info+data FIFOs -> AXI write bursts to external memory,
//      memory verified, BD status + rx_irq

`timescale 1ns / 1ps

module iob_eth_dt_tb;

   // ---------- Testbench parameters ----------
   localparam AXI_ID_W   = 1;
   localparam AXI_LEN_W  = 8;
   localparam AXI_ADDR_W = 16;
   localparam AXI_DATA_W = 32;
   localparam BUFFER_W   = 11;
   localparam BD_ADDR_W  = 8;

   localparam TX_FRAME_LEN = 16;   // frame bytes written by CPU (no FCS)
   localparam RX_FRAME_LEN = 34;   // DA(6)+SA(6)+type(2)+payload(16)+FCS(4)
   localparam PRE_FRAME_LEN = 8;   // preamble(7)+SFD(1)
   localparam RX_BD_IDX = 64;      // RX BDs start at index 64 (driver convention)

   // ---------- Clocks ----------
   reg clk = 0;         // system clock (DT), 100 MHz
   reg mii_tx_clk = 0;  // MII TX clock (TX FIFO read side), 25 MHz
   reg mii_rx_clk = 0;  // MII RX clock (RX FIFO write side), 25 MHz
   always #5 clk = ~clk;
   always #20 mii_tx_clk = ~mii_tx_clk;
   always #20 mii_rx_clk = ~mii_rx_clk;

   // ---------- Reset ----------
   reg arst = 1;

   // ---------- DUT ----------
   reg       rx_en_i = 0;
   reg       tx_en_i = 0;
   reg [6:0] tx_bd_num_i = 0;

   wire       bd_en_o;
   wire [7:0] bd_addr_o;
   wire       bd_wen_o;
   wire [31:0] bd_i;
   wire [31:0] bd_o;

   wire        eth_data_wr_wen_o;
   wire [7:0]  eth_data_wr_wdata_o;
   wire        tx_w_full_i;
   reg         tx_ready_i = 1;
   wire        crc_en_o;
   wire [10:0] tx_nbytes_o;
   wire        send_o;

   wire         eth_data_rd_pop_o;
   wire [7:0]   eth_data_rd_rdata_i;
   wire         eth_rx_info_pop_o;
   wire         eth_rx_info_empty_i;
   wire [11:0]  eth_rx_info_rdata_i;
   wire         rx_nbytes_valid_o;
   wire [10:0]  rx_nbytes_o;

   // AXI master (gated toward the AXI RAM)
   wire [AXI_ADDR_W-1:0] axi_araddr_o;
   wire                  axi_arvalid_o;
   wire                  axi_arready_i;
   wire [AXI_DATA_W-1:0] axi_rdata_i;
   wire [1:0]            axi_rresp_i;
   wire                  axi_rvalid_i;
   wire                  axi_rready_o;
   wire [AXI_ID_W-1:0]   axi_arid_o;
   wire [AXI_LEN_W-1:0]  axi_arlen_o;
   wire [2:0]            axi_arsize_o;
   wire [1:0]            axi_arburst_o;
   wire [1:0]            axi_arlock_o;
   wire [3:0]            axi_arcache_o;
   wire [3:0]            axi_arqos_o;
   wire [AXI_ID_W-1:0]   axi_rid_i;
   wire                  axi_rlast_i;
   wire [AXI_ADDR_W-1:0] axi_awaddr_o;
   wire                  axi_awvalid_o;
   wire                  axi_awready_i;
   wire [AXI_DATA_W-1:0] axi_wdata_o;
   wire [3:0]            axi_wstrb_o;
   wire                  axi_wvalid_o;
   wire                  axi_wready_i;
   wire [1:0]            axi_bresp_i;
   wire                  axi_bvalid_i;
   wire                  axi_bready_o;
   wire [AXI_ID_W-1:0]   axi_awid_o;
   wire [AXI_LEN_W-1:0]  axi_awlen_o;
   wire [2:0]            axi_awsize_o;
   wire [1:0]            axi_awburst_o;
   wire [1:0]            axi_awlock_o;
   wire [3:0]            axi_awcache_o;
   wire [3:0]            axi_awqos_o;
   wire                  axi_wlast_o;
   wire [AXI_ID_W-1:0]   axi_bid_i;

   wire [6:0]  tx_bd_cnt_o;
   wire [10:0] tx_word_cnt_o;
   reg         tx_frame_word_wen_i = 0;
   reg [7:0]   tx_frame_word_wdata_i = 0;
   wire        tx_frame_word_ready_o;
   wire [6:0]  rx_bd_cnt_o;
   wire [10:0] rx_word_cnt_o;
   reg         rx_frame_word_ren_i = 0;
   wire [7:0]  rx_frame_word_rdata_o;
   wire        rx_frame_word_rvalid_o;
   wire        rx_frame_word_ready_o;
   wire        tx_irq_o;
   wire        rx_irq_o;

   iob_eth_dt #(
      .AXI_ID_W  (AXI_ID_W),
      .AXI_LEN_W (AXI_LEN_W),
      .AXI_ADDR_W(AXI_ADDR_W),
      .AXI_DATA_W(AXI_DATA_W),
      .BUFFER_W  (BUFFER_W),
      .BD_ADDR_W (BD_ADDR_W)
   ) dut (
      .clk_i                   (clk),
      .cke_i                   (1'b1),
      .arst_i                  (arst),
      .rx_en_i                 (rx_en_i),
      .tx_en_i                 (tx_en_i),
      .tx_bd_num_i             (tx_bd_num_i),
      .bd_en_o                 (bd_en_o),
      .bd_addr_o               (bd_addr_o),
      .bd_wen_o                (bd_wen_o),
      .bd_i                    (bd_i),
      .bd_o                    (bd_o),
      .eth_data_wr_wen_o       (eth_data_wr_wen_o),
      .eth_data_wr_wdata_o     (eth_data_wr_wdata_o),
      .tx_w_full_i             (tx_w_full_i),
      .tx_ready_i              (tx_ready_i),
      .crc_en_o                (crc_en_o),
      .tx_nbytes_o             (tx_nbytes_o),
      .send_o                  (send_o),
      .eth_data_rd_pop_o       (eth_data_rd_pop_o),
      .eth_data_rd_rdata_i     (eth_data_rd_rdata_i),
      .eth_rx_info_pop_o       (eth_rx_info_pop_o),
      .eth_rx_info_empty_i     (eth_rx_info_empty_i),
      .eth_rx_info_rdata_i     (eth_rx_info_rdata_i),
      .rx_nbytes_valid_o       (rx_nbytes_valid_o),
      .rx_nbytes_o             (rx_nbytes_o),
      .axi_araddr_o            (axi_araddr_o),
      .axi_arvalid_o           (axi_arvalid_o),
      .axi_arready_i           (axi_arready_i),
      .axi_rdata_i             (axi_rdata_i),
      .axi_rresp_i             (axi_rresp_i),
      .axi_rvalid_i            (axi_rvalid_i),
      .axi_rready_o            (axi_rready_o),
      .axi_arid_o              (axi_arid_o),
      .axi_arlen_o             (axi_arlen_o),
      .axi_arsize_o            (axi_arsize_o),
      .axi_arburst_o           (axi_arburst_o),
      .axi_arlock_o            (axi_arlock_o),
      .axi_arcache_o           (axi_arcache_o),
      .axi_arqos_o             (axi_arqos_o),
      .axi_rid_i               (axi_rid_i),
      .axi_rlast_i             (axi_rlast_i),
      .axi_awaddr_o            (axi_awaddr_o),
      .axi_awvalid_o           (axi_awvalid_o),
      .axi_awready_i           (axi_awready_i),
      .axi_wdata_o             (axi_wdata_o),
      .axi_wstrb_o             (axi_wstrb_o),
      .axi_wvalid_o            (axi_wvalid_o),
      .axi_wready_i            (axi_wready_i),
      .axi_bresp_i             (axi_bresp_i),
      .axi_bvalid_i            (axi_bvalid_i),
      .axi_bready_o            (axi_bready_o),
      .axi_awid_o              (axi_awid_o),
      .axi_awlen_o             (axi_awlen_o),
      .axi_awsize_o            (axi_awsize_o),
      .axi_awburst_o           (axi_awburst_o),
      .axi_awlock_o            (axi_awlock_o),
      .axi_awcache_o           (axi_awcache_o),
      .axi_awqos_o             (axi_awqos_o),
      .axi_wlast_o             (axi_wlast_o),
      .axi_bid_i               (axi_bid_i),
      .tx_bd_cnt_o             (tx_bd_cnt_o),
      .tx_word_cnt_o           (tx_word_cnt_o),
      .tx_frame_word_wen_i     (tx_frame_word_wen_i),
      .tx_frame_word_wdata_i   (tx_frame_word_wdata_i),
      .tx_frame_word_ready_o   (tx_frame_word_ready_o),
      .rx_bd_cnt_o             (rx_bd_cnt_o),
      .rx_word_cnt_o           (rx_word_cnt_o),
      .rx_frame_word_ren_i     (rx_frame_word_ren_i),
      .rx_frame_word_rdata_o   (rx_frame_word_rdata_o),
      .rx_frame_word_rvalid_o  (rx_frame_word_rvalid_o),
      .rx_frame_word_ready_o   (rx_frame_word_ready_o),
      .tx_irq_o                (tx_irq_o),
      .rx_irq_o                (rx_irq_o)
   );

   // ---------- BD RAM (port B -> DT, port A -> TB) ----------
   reg        bdA_en = 0;
   reg        bdA_we = 0;
   reg [7:0]  bdA_addr = 0;
   reg [31:0] bdA_wdata = 0;
   wire [31:0] bdA_rdata;

   iob_ram_tdp #(
      .ADDR_W              (BD_ADDR_W),
      .DATA_W              (32),
      .MEM_NO_READ_ON_WRITE(1)
   ) bd_ram (
      .clk_i  (clk),
      .enA_i  (bdA_en),
      .weA_i  (bdA_we),
      .addrA_i(bdA_addr),
      .dA_i   (bdA_wdata),
      .dA_o   (bdA_rdata),
      .enB_i  (bd_en_o),
      .weB_i  (bd_wen_o),
      .addrB_i(bd_addr_o),
      .dB_i   (bd_o),
      .dB_o   (bd_i)
   );

   // ---------- TX data FIFO (DT writes, TB reads) ----------
   reg        tx_fifo_r_en = 0;
   wire [7:0] tx_fifo_r_data;
   wire       tx_fifo_r_empty;
   wire [11:0] tx_fifo_w_level;
   wire [11:0] tx_fifo_r_level;

   wire       tx_fifo_ext_mem_w_clk;
   wire       tx_fifo_ext_mem_w_en;
   wire [10:0] tx_fifo_ext_mem_w_addr;
   wire [7:0]  tx_fifo_ext_mem_w_data;
   wire       tx_fifo_ext_mem_r_clk;
   wire       tx_fifo_ext_mem_r_en;
   wire [10:0] tx_fifo_ext_mem_r_addr;
   wire [7:0]  tx_fifo_ext_mem_r_data;

   iob_fifo_async #(
      .W_DATA_W(8),
      .R_DATA_W(8),
      .ADDR_W(BUFFER_W)
   ) tx_data_fifo (
      .w_clk_i             (clk),
      .w_cke_i             (1'b1),
      .w_arst_i            (arst),
      .w_rst_i             (1'b0),
      .r_clk_i             (mii_tx_clk),
      .r_cke_i             (1'b1),
      .r_arst_i            (arst),
      .r_rst_i             (1'b0),
      .w_en_i              (eth_data_wr_wen_o),
      .w_data_i            (eth_data_wr_wdata_o),
      .w_full_o            (tx_w_full_i),
      .w_empty_o           (),
      .w_level_o           (tx_fifo_w_level),
      .r_en_i              (tx_fifo_r_en),
      .r_data_o            (tx_fifo_r_data),
      .r_full_o            (),
      .r_empty_o           (tx_fifo_r_empty),
      .r_level_o           (tx_fifo_r_level),
      .ext_mem_w_clk_o     (tx_fifo_ext_mem_w_clk),
      .ext_mem_w_en_o      (tx_fifo_ext_mem_w_en),
      .ext_mem_w_addr_o    (tx_fifo_ext_mem_w_addr),
      .ext_mem_w_data_o    (tx_fifo_ext_mem_w_data),
      .ext_mem_r_clk_o     (tx_fifo_ext_mem_r_clk),
      .ext_mem_r_en_o      (tx_fifo_ext_mem_r_en),
      .ext_mem_r_addr_o    (tx_fifo_ext_mem_r_addr),
      .ext_mem_r_data_i    (tx_fifo_ext_mem_r_data)
   );

   iob_ram_at2p #(
      .ADDR_W(BUFFER_W),
      .DATA_W(8)
   ) tx_data_fifo_ram (
      .r_clk_i (tx_fifo_ext_mem_r_clk),
      .r_en_i  (tx_fifo_ext_mem_r_en),
      .r_addr_i(tx_fifo_ext_mem_r_addr),
      .r_data_o(tx_fifo_ext_mem_r_data),
      .w_clk_i (tx_fifo_ext_mem_w_clk),
      .w_en_i  (tx_fifo_ext_mem_w_en),
      .w_addr_i(tx_fifo_ext_mem_w_addr),
      .w_data_i(tx_fifo_ext_mem_w_data)
   );

   // ---------- RX data FIFO (TB writes, DT reads) ----------
   reg        rx_fifo_w_en = 0;
   reg [7:0]  rx_fifo_w_data = 0;
   wire       rx_fifo_w_empty;

   wire       rx_fifo_ext_mem_w_clk;
   wire       rx_fifo_ext_mem_w_en;
   wire [10:0] rx_fifo_ext_mem_w_addr;
   wire [7:0]  rx_fifo_ext_mem_w_data;
   wire       rx_fifo_ext_mem_r_clk;
   wire       rx_fifo_ext_mem_r_en;
   wire [10:0] rx_fifo_ext_mem_r_addr;
   wire [7:0]  rx_fifo_ext_mem_r_data;

   iob_fifo_async #(
      .W_DATA_W(8),
      .R_DATA_W(8),
      .ADDR_W(BUFFER_W)
   ) rx_data_fifo (
      .w_clk_i             (mii_rx_clk),
      .w_cke_i             (1'b1),
      .w_arst_i            (arst),
      .w_rst_i             (1'b0),
      .r_clk_i             (clk),
      .r_cke_i             (1'b1),
      .r_arst_i            (arst),
      .r_rst_i             (1'b0),
      .w_en_i              (rx_fifo_w_en),
      .w_data_i            (rx_fifo_w_data),
      .w_full_o            (),
      .w_empty_o           (rx_fifo_w_empty),
      .w_level_o           (),
      .r_en_i              (eth_data_rd_pop_o),
      .r_data_o            (eth_data_rd_rdata_i),
      .r_full_o            (),
      .r_empty_o           (),
      .r_level_o           (),
      .ext_mem_w_clk_o     (rx_fifo_ext_mem_w_clk),
      .ext_mem_w_en_o      (rx_fifo_ext_mem_w_en),
      .ext_mem_w_addr_o    (rx_fifo_ext_mem_w_addr),
      .ext_mem_w_data_o    (rx_fifo_ext_mem_w_data),
      .ext_mem_r_clk_o     (rx_fifo_ext_mem_r_clk),
      .ext_mem_r_en_o      (rx_fifo_ext_mem_r_en),
      .ext_mem_r_addr_o    (rx_fifo_ext_mem_r_addr),
      .ext_mem_r_data_i    (rx_fifo_ext_mem_r_data)
   );

   iob_ram_at2p #(
      .ADDR_W(BUFFER_W),
      .DATA_W(8)
   ) rx_data_fifo_ram (
      .r_clk_i (rx_fifo_ext_mem_r_clk),
      .r_en_i  (rx_fifo_ext_mem_r_en),
      .r_addr_i(rx_fifo_ext_mem_r_addr),
      .r_data_o(rx_fifo_ext_mem_r_data),
      .w_clk_i (rx_fifo_ext_mem_w_clk),
      .w_en_i  (rx_fifo_ext_mem_w_en),
      .w_addr_i(rx_fifo_ext_mem_w_addr),
      .w_data_i(rx_fifo_ext_mem_w_data)
   );

   // ---------- RX info FIFO (TB writes, DT reads) ----------
   reg        info_fifo_w_en = 0;
   reg [11:0] info_fifo_w_data = 0;

   wire       info_fifo_ext_mem_w_clk;
   wire       info_fifo_ext_mem_w_en;
   wire       info_fifo_ext_mem_w_addr;
   wire [11:0] info_fifo_ext_mem_w_data;
   wire       info_fifo_ext_mem_r_clk;
   wire       info_fifo_ext_mem_r_en;
   wire       info_fifo_ext_mem_r_addr;
   wire [11:0] info_fifo_ext_mem_r_data;

   iob_fifo_async #(
      .W_DATA_W(12),
      .R_DATA_W(12),
      .ADDR_W(1)
   ) rx_info_fifo (
      .w_clk_i             (mii_rx_clk),
      .w_cke_i             (1'b1),
      .w_arst_i            (arst),
      .w_rst_i             (1'b0),
      .r_clk_i             (clk),
      .r_cke_i             (1'b1),
      .r_arst_i            (arst),
      .r_rst_i             (1'b0),
      .w_en_i              (info_fifo_w_en),
      .w_data_i            (info_fifo_w_data),
      .w_full_o            (),
      .w_empty_o           (),
      .w_level_o           (),
      .r_en_i              (eth_rx_info_pop_o),
      .r_data_o            (eth_rx_info_rdata_i),
      .r_full_o            (),
      .r_empty_o           (eth_rx_info_empty_i),
      .r_level_o           (),
      .ext_mem_w_clk_o     (info_fifo_ext_mem_w_clk),
      .ext_mem_w_en_o      (info_fifo_ext_mem_w_en),
      .ext_mem_w_addr_o    (info_fifo_ext_mem_w_addr),
      .ext_mem_w_data_o    (info_fifo_ext_mem_w_data),
      .ext_mem_r_clk_o     (info_fifo_ext_mem_r_clk),
      .ext_mem_r_en_o      (info_fifo_ext_mem_r_en),
      .ext_mem_r_addr_o    (info_fifo_ext_mem_r_addr),
      .ext_mem_r_data_i    (info_fifo_ext_mem_r_data)
   );

   iob_ram_at2p #(
      .ADDR_W(1),
      .DATA_W(12)
   ) rx_info_fifo_ram (
      .r_clk_i (info_fifo_ext_mem_r_clk),
      .r_en_i  (info_fifo_ext_mem_r_en),
      .r_addr_i(info_fifo_ext_mem_r_addr),
      .r_data_o(info_fifo_ext_mem_r_data),
      .w_clk_i (info_fifo_ext_mem_w_clk),
      .w_en_i  (info_fifo_ext_mem_w_en),
      .w_addr_i(info_fifo_ext_mem_w_addr),
      .w_data_i(info_fifo_ext_mem_w_data)
   );

   // ---------- External memory: iob_axi_ram + iob_ram_t2p_be ----------
   wire [AXI_ADDR_W-1:0] ext_mem_r_addr;
   wire [AXI_DATA_W-1:0] ext_mem_r_data;
   wire [3:0]            ext_mem_w_strb;
   wire [AXI_ADDR_W-1:0] ext_mem_w_addr;
   wire [AXI_DATA_W-1:0] ext_mem_w_data;
   wire                  ext_mem_r_en;

   wire axi_ram_arready, axi_ram_rvalid, axi_ram_awready, axi_ram_wready, axi_ram_bvalid;
   wire [31:0] axi_ram_rdata;
   wire axi_ram_rlast;
   wire [0:0] axi_ram_rid, axi_ram_bid;

   iob_axi_ram #(
      .DATA_WIDTH     (AXI_DATA_W),
      .ADDR_WIDTH     (AXI_ADDR_W),
      .ID_WIDTH       (AXI_ID_W),
      .LEN_WIDTH      (AXI_LEN_W),
      .PIPELINE_OUTPUT(0)
   ) axi_mem (
      .clk_i           (clk),
      .rst_i           (arst),
      .axi_araddr_i    (axi_araddr_o),
      .axi_arvalid_i   (axi_arvalid_o),
      .axi_arready_o   (axi_ram_arready),
      .axi_rdata_o     (axi_ram_rdata),
      .axi_rresp_o     (),
      .axi_rvalid_o    (axi_ram_rvalid),
      .axi_rready_i    (axi_rready_o),
      .axi_arid_i      (axi_arid_o),
      .axi_arlen_i     (axi_arlen_o),
      .axi_arsize_i    (axi_arsize_o),
      .axi_arburst_i   (axi_arburst_o),
      .axi_arlock_i    (axi_arlock_o),
      .axi_arcache_i   (axi_arcache_o),
      .axi_arqos_i     (axi_arqos_o),
      .axi_rid_o       (axi_ram_rid),
      .axi_rlast_o     (axi_ram_rlast),
      .axi_awaddr_i    (axi_awaddr_o),
      .axi_awvalid_i   (axi_awvalid_o),
      .axi_awready_o   (axi_ram_awready),
      .axi_wdata_i     (axi_wdata_o),
      .axi_wstrb_i     (axi_wstrb_o),
      .axi_wvalid_i    (axi_wvalid_o),
      .axi_wready_o    (axi_ram_wready),
      .axi_bresp_o     (),
      .axi_bvalid_o    (axi_ram_bvalid),
      .axi_bready_i    (axi_bready_o),
      .axi_awid_i      (axi_awid_o),
      .axi_awlen_i     (axi_awlen_o),
      .axi_awsize_i    (axi_awsize_o),
      .axi_awburst_i   (axi_awburst_o),
      .axi_awlock_i    (axi_awlock_o),
      .axi_awcache_i   (axi_awcache_o),
      .axi_awqos_i     (axi_awqos_o),
      .axi_wlast_i     (axi_wlast_o),
      .axi_bid_o       (axi_ram_bid),
      .ext_mem_clk_o   (),
      .ext_mem_r_en_o  (ext_mem_r_en),
      .ext_mem_r_addr_o(ext_mem_r_addr),
      .ext_mem_r_data_i(ext_mem_r_data),
      .ext_mem_w_strb_o(ext_mem_w_strb),
      .ext_mem_w_addr_o(ext_mem_w_addr),
      .ext_mem_w_data_o(ext_mem_w_data)
   );

   iob_ram_t2p_be #(
      .ADDR_W(13),
      .DATA_W(32)
   ) axi_mem_backing (
      .clk_i  (clk),
      .r_en_i (ext_mem_r_en),
      .r_addr_i(ext_mem_r_addr),
      .r_data_o(ext_mem_r_data),
      .w_strb_i(ext_mem_w_strb),
      .w_addr_i(ext_mem_w_addr),
      .w_data_i(ext_mem_w_data)
   );

   // AXI handshake blocking (no-DMA tests)
   reg blk_ar_rdy = 0;
   reg blk_r_valid = 0;
   reg blk_aw_rdy = 0;
   reg blk_w_rdy = 0;
   reg blk_b_valid = 0;

   assign axi_arready_i = blk_ar_rdy ? 1'b0 : axi_ram_arready;
   assign axi_rvalid_i  = blk_r_valid  ? 1'b0 : axi_ram_rvalid;
   assign axi_rdata_i   = blk_r_valid  ? 32'b0 : axi_ram_rdata;
   assign axi_rlast_i   = blk_r_valid  ? 1'b0 : axi_ram_rlast;
   assign axi_rid_i     = axi_ram_rid;
   assign axi_awready_i = blk_aw_rdy ? 1'b0 : axi_ram_awready;
   assign axi_wready_i  = blk_w_rdy  ? 1'b0 : axi_ram_wready;
   assign axi_bvalid_i  = blk_b_valid ? 1'b0 : axi_ram_bvalid;
   assign axi_bid_i     = axi_ram_bid;
   assign axi_bresp_i   = 2'b00;
   assign axi_rresp_i   = 2'b00;

   // ---------- Reference CRC for FCS generation ----------
   reg         ref_start = 0;
   reg         ref_en = 0;
   reg [7:0]   ref_data = 0;
   wire [31:0] ref_crc;

   iob_eth_crc ref_crc_inst (
      .clk_i    (clk),
      .arst_i   (arst),
      .start_i  (ref_start),
      .data_i   (ref_data),
      .data_en_i(ref_en),
      .crc_o    (ref_crc)
   );

   function [7:0] rev8;
      input [7:0] w;
      integer i;
      begin
         for (i = 0; i < 8; i = i + 1) rev8[i] = w[7-i];
      end
   endfunction

   // ---------- Frame data (module-level for tasks) ----------
   reg [7:0] tx_frame   [0:15];
   reg [7:0] rx_frame   [0:63];
   reg [7:0] frame_bytes[0:63];
   integer   frame_len;
   reg [7:0] da       [0:5];
   reg [7:0] sa       [0:5];
   reg [7:0] ftype    [0:1];
   reg [7:0] payload  [0:15];
   reg [7:0] rx_fcs   [0:3];
   reg [7:0] tx_recv  [0:63];
   reg [7:0] rx_recv  [0:63];
   integer   test_fail;
   integer   i;

   // ---------- Captured events ----------
   reg         tx_irq_seen = 0;
   reg         rx_irq_seen = 0;
   reg         rx_nbytes_seen = 0;
   reg [10:0]  rx_nbytes_captured = 0;
   reg         crc_en_captured = 0;
   reg [10:0]  tx_nbytes_captured = 0;
   reg         send_captured = 0;

   always @(posedge clk, posedge arst) begin
      if (arst) begin
         tx_irq_seen <= 0;
         rx_irq_seen <= 0;
         rx_nbytes_seen <= 0;
         crc_en_captured <= 0;
         tx_nbytes_captured <= 0;
         send_captured <= 0;
      end else begin
         if (tx_irq_o) tx_irq_seen <= 1;
         if (rx_irq_o) rx_irq_seen <= 1;
         if (rx_nbytes_valid_o) begin
            rx_nbytes_seen <= 1;
            rx_nbytes_captured <= rx_nbytes_o;
         end
         if (send_o) begin
            send_captured <= 1;
            tx_nbytes_captured <= tx_nbytes_o;
         end
         if (crc_en_o) crc_en_captured <= 1;
      end
   end

   // ---------- Emulate TX front-end tx_ready (deassert while sending) ----------
   initial begin
      tx_ready_i = 1'b1;
      forever begin
         @(posedge send_o);
         repeat (2) @(posedge clk);
         tx_ready_i = 1'b0;
         @(negedge send_o);
         @(posedge clk);
         tx_ready_i = 1'b1;
      end
   end

   // ---------- Helpers ----------
   task bd_write;
      input [7:0] addr;
      input [31:0] data;
      begin
         @(negedge clk);
         bdA_en <= 1;
         bdA_we <= 1;
         bdA_addr <= addr;
         bdA_wdata <= data;
         @(posedge clk);
         @(negedge clk);
         bdA_en <= 0;
         bdA_we <= 0;
      end
   endtask

   task bd_read;
      input [7:0] addr;
      output [31:0] data;
      begin
         @(negedge clk);
         bdA_en <= 1;
         bdA_we <= 0;
         bdA_addr <= addr;
         @(posedge clk);
         @(posedge clk);
         data = bdA_rdata;
         @(negedge clk);
         bdA_en <= 0;
      end
   endtask

   task poke_axi_byte;
      input [15:0] a;
      input [7:0] d;
      integer col;
      begin
         col = a[1:0];
         if (col == 0) axi_mem_backing.ram_col[0].ram.mem[a[15:2]] = d;
         else if (col == 1) axi_mem_backing.ram_col[1].ram.mem[a[15:2]] = d;
         else if (col == 2) axi_mem_backing.ram_col[2].ram.mem[a[15:2]] = d;
         else axi_mem_backing.ram_col[3].ram.mem[a[15:2]] = d;
      end
   endtask

   task peek_axi_byte;
      input [15:0] a;
      output [7:0] d;
      integer col;
      begin
         col = a[1:0];
         if (col == 0) d = axi_mem_backing.ram_col[0].ram.mem[a[15:2]];
         else if (col == 1) d = axi_mem_backing.ram_col[1].ram.mem[a[15:2]];
         else if (col == 2) d = axi_mem_backing.ram_col[2].ram.mem[a[15:2]];
         else d = axi_mem_backing.ram_col[3].ram.mem[a[15:2]];
      end
   endtask

   task reset_tb;
      begin
         tx_en_i = 0;
         rx_en_i = 0;
         blk_ar_rdy = 0;
         blk_r_valid = 0;
         blk_aw_rdy = 0;
         blk_w_rdy = 0;
         blk_b_valid = 0;
         arst = 1;
         repeat (6) @(posedge clk);
         @(negedge clk);
         arst = 0;
         repeat (4) @(posedge clk);
      end
   endtask

   task feed_crc_bytes;
      integer k;
      begin
         @(negedge clk);
         ref_start <= 1;
         ref_en <= 0;
         @(posedge clk);
         @(negedge clk);
         ref_start <= 0;
         for (k = 0; k < frame_len; k = k + 1) begin
            ref_en <= 1;
            ref_data <= frame_bytes[k];
            @(posedge clk);
         end
         @(negedge clk);
         ref_en <= 0;
         ref_data <= 0;
      end
   endtask

   task push_rx_data_byte;
      input [7:0] b;
      begin
         @(negedge mii_rx_clk);
         rx_fifo_w_en <= 1;
         rx_fifo_w_data <= b;
         @(posedge mii_rx_clk);
         rx_fifo_w_en <= 0;
      end
   endtask

   task push_rx_info;
      input [11:0] info;
      begin
         @(negedge mii_rx_clk);
         info_fifo_w_en <= 1;
         info_fifo_w_data <= info;
         @(posedge mii_rx_clk);
         info_fifo_w_en <= 0;
      end
   endtask

   task write_tx_frame_word;
      input [7:0] b;
      begin
         wait (tx_frame_word_ready_o === 1'b1);
         @(negedge clk);
         tx_frame_word_wen_i <= 1;
         tx_frame_word_wdata_i <= b;
         @(posedge clk);
         @(negedge clk);
         tx_frame_word_wen_i <= 0;
      end
   endtask

   task read_rx_frame_word;
      output [7:0] b;
      begin
         wait (rx_frame_word_ready_o === 1'b1);
         @(negedge clk);
         rx_frame_word_ren_i <= 1;
         @(posedge clk);
         @(negedge clk);
         rx_frame_word_ren_i <= 0;
         wait (rx_frame_word_rvalid_o === 1'b1);
         b = rx_frame_word_rdata_o;
         @(posedge clk);
      end
   endtask

   task pop_tx_fifo;
      output [7:0] b;
      begin
         wait (!tx_fifo_r_empty);
         @(negedge mii_tx_clk);
         tx_fifo_r_en <= 1;
         @(posedge mii_tx_clk);
         @(negedge mii_tx_clk);
         tx_fifo_r_en <= 0;
         @(posedge mii_tx_clk);
         @(posedge mii_tx_clk);
         b = tx_fifo_r_data;
      end
   endtask

   // ---------- Checks ----------
   task check_tx_frame;
      integer n;
      begin
         // 7 x preamble, SFD, then the frame bytes
         for (n = 0; n < 7; n = n + 1) begin
            if (tx_recv[n] !== 8'h55) begin
               $display("FAIL[%0t]: TX pre[%0d] = %02h, expected 55", $time, n, tx_recv[n]);
               test_fail = 1;
            end
         end
         if (tx_recv[7] !== 8'hD5) begin
            $display("FAIL[%0t]: TX SFD = %02h, expected D5", $time, tx_recv[7]);
            test_fail = 1;
         end
         for (n = 0; n < TX_FRAME_LEN; n = n + 1) begin
            if (tx_recv[8 + n] !== tx_frame[n]) begin
               $display("FAIL[%0t]: TX data[%0d] = %02h, expected %02h", $time, n, tx_recv[8 + n], tx_frame[n]);
               test_fail = 1;
            end
         end
         if (test_fail == 0) $display("PASS[%0t]: TX FIFO frame bytes correct", $time);
      end
   endtask

   task check_bd;
      input [7:0] addr;
      input [31:0] exp_val;
      input [31:0] name;
      reg [31:0] val;
      begin
         bd_read(addr, val);
         if (val !== exp_val) begin
            $display("FAIL[%0t]: %s BD@%0d = %08h, expected %08h", $time, name, addr, val, exp_val);
            test_fail = 1;
         end else begin
            $display("PASS[%0t]: %s BD@%0d = %08h", $time, name, addr, val);
         end
      end
   endtask

   // ---------- Main sequence ----------
   integer n;
   reg [7:0] b;
   reg [31:0] bdval;

   initial begin
      test_fail = 0;

      // Build TX frame (16 bytes, 0x00..0x0f)
      for (i = 0; i < TX_FRAME_LEN; i = i + 1) tx_frame[i] = i[7:0];

      // Build RX frame: DA + SA + type + payload
      da[0] = 8'h00; da[1] = 8'h11; da[2] = 8'h22; da[3] = 8'h33; da[4] = 8'h44; da[5] = 8'h55;
      sa[0] = 8'h66; sa[1] = 8'h77; sa[2] = 8'h88; sa[3] = 8'h99; sa[4] = 8'hAA; sa[5] = 8'hBB;
      ftype[0] = 8'h08; ftype[1] = 8'h00;
      for (i = 0; i < 16; i = i + 1) payload[i] = i[7:0];
      frame_len = 0;
      for (i = 0; i < 6; i = i + 1) frame_bytes[frame_len + i] = da[i];
      frame_len = frame_len + 6;
      for (i = 0; i < 6; i = i + 1) frame_bytes[frame_len + i] = sa[i];
      frame_len = frame_len + 6;
      for (i = 0; i < 2; i = i + 1) frame_bytes[frame_len + i] = ftype[i];
      frame_len = frame_len + 2;
      for (i = 0; i < 16; i = i + 1) frame_bytes[frame_len + i] = payload[i];
      frame_len = frame_len + 16;

      // Compute FCS for the RX frame
      reset_tb();
      feed_crc_bytes;
      rx_fcs[0] = ~rev8(ref_crc[31:24]);
      rx_fcs[1] = ~rev8(ref_crc[23:16]);
      rx_fcs[2] = ~rev8(ref_crc[15:8]);
      rx_fcs[3] = ~rev8(ref_crc[7:0]);
      for (i = 0; i < 30; i = i + 1) rx_frame[i] = frame_bytes[i];
      rx_frame[30] = rx_fcs[0];
      rx_frame[31] = rx_fcs[1];
      rx_frame[32] = rx_fcs[2];
      rx_frame[33] = rx_fcs[3];

      // ================= Test 1: TX no-DMA =================
      $display("=== DT TB: TX no-DMA (%0d frame bytes) ===", TX_FRAME_LEN);
      reset_tb();
      // BD0: ready|int, length=16; pointer unused in no-DMA
      bd_write(8'h00, 32'h0010C000);
      bd_write(8'h01, 32'h00000000);
      blk_ar_rdy = 1; blk_r_valid = 1; blk_aw_rdy = 1; blk_w_rdy = 1; blk_b_valid = 1;
      tx_en_i = 1;
      for (i = 0; i < TX_FRAME_LEN; i = i + 1) write_tx_frame_word(tx_frame[i]);
      wait (tx_irq_seen);
      repeat (4) @(posedge clk);
      if (!send_captured) begin
         $display("FAIL[%0t]: send_o never pulsed", $time);
         test_fail = 1;
      end else $display("PASS[%0t]: send_o pulsed, nbytes=%0d", $time, tx_nbytes_captured);
      if (tx_nbytes_captured !== PRE_FRAME_LEN + TX_FRAME_LEN) begin
         $display("FAIL[%0t]: tx_nbytes = %0d, expected %0d", $time, tx_nbytes_captured, PRE_FRAME_LEN + TX_FRAME_LEN);
         test_fail = 1;
      end
      if (!crc_en_captured) begin
         $display("FAIL[%0t]: crc_en never pulsed", $time);
         test_fail = 1;
      end
      check_bd(8'h00, 32'h00104000, "TX");
      // Drain TX FIFO and verify bytes
      for (i = 0; i < PRE_FRAME_LEN + TX_FRAME_LEN; i = i + 1) pop_tx_fifo(tx_recv[i]);
      check_tx_frame;

      // ================= Test 2: RX no-DMA =================
      $display("=== DT TB: RX no-DMA (%0d wire bytes) ===", RX_FRAME_LEN);
      reset_tb();
      // RX BD@128: ready|int|wrap; pointer unused in no-DMA
      bd_write(8'h80, 32'h0000E000);
      bd_write(8'h81, 32'h00000000);
      blk_ar_rdy = 1; blk_r_valid = 1; blk_aw_rdy = 1; blk_w_rdy = 1; blk_b_valid = 1;
      push_rx_info(12'd34);
      for (i = 0; i < RX_FRAME_LEN; i = i + 1) push_rx_data_byte(rx_frame[i]);
      rx_en_i = 1;
      // rx_nbytes_valid pulse + value
      wait (rx_nbytes_seen);
      if (rx_nbytes_captured !== RX_FRAME_LEN) begin
         $display("FAIL[%0t]: rx_nbytes = %0d, expected %0d", $time, rx_nbytes_captured, RX_FRAME_LEN);
         test_fail = 1;
      end else $display("PASS[%0t]: rx_nbytes = %0d", $time, rx_nbytes_captured);
      // Read frame words
      for (i = 0; i < RX_FRAME_LEN; i = i + 1) read_rx_frame_word(rx_recv[i]);
      for (i = 0; i < RX_FRAME_LEN; i = i + 1) begin
         if (rx_recv[i] !== rx_frame[i]) begin
            $display("FAIL[%0t]: RX word[%0d] = %02h, expected %02h", $time, i, rx_recv[i], rx_frame[i]);
            test_fail = 1;
         end
      end
      if (test_fail == 0) $display("PASS[%0t]: RX no-DMA frame words correct", $time);
      wait (rx_irq_seen);
      repeat (4) @(posedge clk);
      // BD status: {len=34, 0, int|wrap, crc=0} ready cleared => 0x00226000
      check_bd(8'h80, 32'h00226000, "RX");

      // ================= Test 3: TX DMA =================
      $display("=== DT TB: TX DMA (%0d frame bytes) ===", TX_FRAME_LEN);
      reset_tb();
      // Preload payload at byte addresses 0x0010..0x001f
      for (i = 0; i < TX_FRAME_LEN; i = i + 1) poke_axi_byte(16'h0010 + i, tx_frame[i]);
      // BD0: ready|int, length=16; pointer = 0x0010
      bd_write(8'h00, 32'h0010C000);
      bd_write(8'h01, 32'h00000010);
      tx_en_i = 1;
      wait (tx_irq_seen);
      repeat (4) @(posedge clk);
      if (!send_captured) begin
         $display("FAIL[%0t]: send_o never pulsed", $time);
         test_fail = 1;
      end else $display("PASS[%0t]: send_o pulsed, nbytes=%0d", $time, tx_nbytes_captured);
      if (tx_nbytes_captured !== PRE_FRAME_LEN + TX_FRAME_LEN) begin
         $display("FAIL[%0t]: tx_nbytes = %0d, expected %0d", $time, tx_nbytes_captured, PRE_FRAME_LEN + TX_FRAME_LEN);
         test_fail = 1;
      end
      if (!crc_en_captured) begin
         $display("FAIL[%0t]: crc_en never pulsed", $time);
         test_fail = 1;
      end
      check_bd(8'h00, 32'h00104000, "TX");
      for (i = 0; i < PRE_FRAME_LEN + TX_FRAME_LEN; i = i + 1) pop_tx_fifo(tx_recv[i]);
      check_tx_frame;

      // ================= Test 4: RX DMA =================
      $display("=== DT TB: RX DMA (%0d wire bytes) ===", RX_FRAME_LEN);
      reset_tb();
      // RX BD@128: ready|int|wrap; pointer = 0x0200
      bd_write(8'h80, 32'h0000E000);
      bd_write(8'h81, 32'h00000200);
      push_rx_info(12'd34);
      for (i = 0; i < RX_FRAME_LEN; i = i + 1) push_rx_data_byte(rx_frame[i]);
      rx_en_i = 1;
      wait (rx_irq_seen);
      wait (rx_nbytes_seen);
      repeat (4) @(posedge clk);
      if (rx_nbytes_captured !== RX_FRAME_LEN) begin
         $display("FAIL[%0t]: rx_nbytes = %0d, expected %0d", $time, rx_nbytes_captured, RX_FRAME_LEN);
         test_fail = 1;
      end else $display("PASS[%0t]: rx_nbytes = %0d", $time, rx_nbytes_captured);
      // Verify external memory contents at 0x0200..
      for (i = 0; i < RX_FRAME_LEN; i = i + 1) begin
         peek_axi_byte(16'h0200 + i, b);
         if (b !== rx_frame[i]) begin
            $display("FAIL[%0t]: AXI mem[%03x] = %02h, expected %02h", $time, 16'h0200 + i, b, rx_frame[i]);
            test_fail = 1;
         end
      end
      if (test_fail == 0) $display("PASS[%0t]: RX DMA memory contents correct", $time);
      check_bd(8'h80, 32'h00226000, "RX");

      // ================= Summary =================
      if (test_fail) $display("=== DT TB: TESTS FAILED ===");
      else $display("=== DT TB: ALL TESTS PASSED ===");
      $finish;
   end

   initial begin
      $dumpfile("dt_tb.vcd");
      $dumpvars(0, iob_eth_dt_tb);
   end

endmodule
