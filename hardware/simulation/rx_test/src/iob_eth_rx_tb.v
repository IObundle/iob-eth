// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0
//
// Standalone testbench for iob_eth_rx.
//
// Harness mirrors iob_eth.v: an RX data FIFO (8-bit) + RX info FIFO (12-bit),
// both iob_fifo_async + iob_ram_at2p, written in the MII RX clock domain and
// read in the system clock domain.
//
// The TB builds a standard Ethernet frame (preamble + SFD + DA + SA + type +
// payload + FCS), computes the FCS with a reference iob_eth_crc (hardware byte
// order), drives the MII bus, then reads back the data/info FIFOs and checks:
//   - the data FIFO contains exactly the frame bytes (DA..FCS), in order
//   - the info word is {crc_err, length[10:0]} with crc_err=0 and
//     length = 6+6+2+payload+4 (full wire length, FCS included)
//   - a corrupted frame yields crc_err=1
//   - the receiver parks until the data FIFO drains and re-arms for the next
//     frame

`timescale 1ns / 1ps

module iob_eth_rx_tb;

   localparam PAYLOAD_LEN = 16;
   localparam FRAME_LEN   = 6 + 6 + 2 + PAYLOAD_LEN + 4;

   // ---------- Clocks ----------
   reg clk = 0;           // system clock (FIFO read side), 100 MHz
   reg mii_rx_clk = 0;    // MII RX clock (DUT + FIFO write side), 25 MHz
   always #5 clk = ~clk;
   always #20 mii_rx_clk = ~mii_rx_clk;

   // ---------- Reset ----------
   reg arst = 1;
   initial #45 arst = 0;

   // ---------- DUT ----------
   wire       rx_wr;
   wire [7:0] rx_data_w;
   wire       rx_info_wen;
   wire [11:0] rx_info_wdata;
   wire        rx_info_w_full;
   wire        rx_w_empty;

   reg        mii_rx_dv = 0;
   reg  [3:0] mii_rx_data = 0;

   iob_eth_rx dut (
      .arst_i      (arst),
      .wr_o        (rx_wr),
      .data_o      (rx_data_w),
      .info_wen_o  (rx_info_wen),
      .info_wdata_o(rx_info_wdata),
      .info_w_full_i(rx_info_w_full),
      .w_empty_i   (rx_w_empty),
      .rx_clk_i    (mii_rx_clk),
      .rx_dv_i     (mii_rx_dv),
      .rx_data_i   (mii_rx_data)
   );

   // ---------- RX data FIFO + backing RAM ----------
   reg        rx_fifo_r_en = 0;
   wire [7:0] rx_fifo_r_data;
   wire       rx_fifo_r_empty;
   wire [11:0] rx_fifo_w_level;
   wire [11:0] rx_fifo_r_level;

   wire        rx_fifo_ext_mem_w_clk;
   wire        rx_fifo_ext_mem_w_en;
   wire [10:0] rx_fifo_ext_mem_w_addr;
   wire [7:0]  rx_fifo_ext_mem_w_data;
   wire        rx_fifo_ext_mem_r_clk;
   wire        rx_fifo_ext_mem_r_en;
   wire [10:0] rx_fifo_ext_mem_r_addr;
   wire [7:0]  rx_fifo_ext_mem_r_data;

   iob_fifo_async #(
      .W_DATA_W(8),
      .R_DATA_W(8),
      .ADDR_W(11)
   ) rx_data_fifo (
      .w_clk_i             (mii_rx_clk),
      .w_cke_i             (1'b1),
      .w_arst_i            (arst),
      .w_rst_i             (1'b0),
      .r_clk_i             (clk),
      .r_cke_i             (1'b1),
      .r_arst_i            (arst),
      .r_rst_i             (1'b0),
      .w_en_i              (rx_wr),
      .w_data_i            (rx_data_w),
      .w_full_o            (),
      .w_empty_o           (rx_w_empty),
      .w_level_o           (rx_fifo_w_level),
      .r_en_i              (rx_fifo_r_en),
      .r_data_o            (rx_fifo_r_data),
      .r_full_o            (),
      .r_empty_o           (rx_fifo_r_empty),
      .r_level_o           (rx_fifo_r_level),
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
      .ADDR_W(11),
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

   // ---------- RX info FIFO + backing RAM ----------
   reg        info_fifo_r_en = 0;
   wire [11:0] info_fifo_r_data;
   wire        info_fifo_r_empty;

   wire        info_fifo_ext_mem_w_clk;
   wire        info_fifo_ext_mem_w_en;
   wire        info_fifo_ext_mem_w_addr;
   wire [11:0] info_fifo_ext_mem_w_data;
   wire        info_fifo_ext_mem_r_clk;
   wire        info_fifo_ext_mem_r_en;
   wire        info_fifo_ext_mem_r_addr;
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
      .w_en_i              (rx_info_wen),
      .w_data_i            (rx_info_wdata),
      .w_full_o            (rx_info_w_full),
      .w_empty_o           (),
      .w_level_o           (),
      .r_en_i              (info_fifo_r_en),
      .r_data_o            (info_fifo_r_data),
      .r_full_o            (),
      .r_empty_o           (info_fifo_r_empty),
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

   // ---------- Reference CRC for FCS generation ----------
   reg        ref_start = 0;
   reg        ref_en    = 0;
   reg  [7:0] ref_data  = 0;
   wire [31:0] ref_crc;

   iob_eth_crc ref_crc_inst (
      .clk_i    (clk),
      .arst_i   (arst),
      .start_i  (ref_start),
      .data_i   (ref_data),
      .data_en_i(ref_en),
      .crc_o    (ref_crc)
   );

   // ---------- Reverse byte (for FCS) ----------
   function [7:0] rev8;
      input [7:0] w;
      integer i;
      begin
         for (i = 0; i < 8; i = i + 1) rev8[i] = w[7-i];
      end
   endfunction

   // ---------- Frame data (module-level for tasks) ----------
   reg  [7:0] frame_bytes [0:255];
   integer    frame_len;
   reg  [7:0] da [0:5];
   reg  [7:0] sa [0:5];
   reg  [7:0] ftype [0:1];
   reg  [7:0] payload [0:255];
   integer    plen;
   reg  [7:0] fcs_bytes [0:3];

   // ---------- MII drive tasks ----------
   task mii_nibble;
      input [3:0] n;
      begin
         @(negedge mii_rx_clk);
         mii_rx_data <= n;
         @(posedge mii_rx_clk);
      end
   endtask

   task mii_byte;
      input [7:0] b;
      begin
         mii_nibble(b[3:0]);
         mii_nibble(b[7:4]);
      end
   endtask

   // ---------- Reference CRC feed (start pulse then bytes) ----------
   task feed_crc_bytes;
      integer i;
      begin
         @(negedge clk);
         ref_start <= 1;
         ref_en    <= 0;
         @(posedge clk);
         @(negedge clk);
         ref_start <= 0;
         for (i = 0; i < frame_len; i = i + 1) begin
            ref_en   <= 1;
            ref_data <= frame_bytes[i];
            @(posedge clk);
         end
         @(negedge clk);
         ref_en   <= 0;
         ref_data <= 0;
      end
   endtask

   // ---------- Frame build + send ----------
   task send_frame;
      input corrupt;
      integer i;
      begin
         // Build frame: DA, SA, type, payload
         frame_len = 0;
         for (i = 0; i < 6; i = i + 1) frame_bytes[frame_len+i] = da[i];
         frame_len = frame_len + 6;
         for (i = 0; i < 6; i = i + 1) frame_bytes[frame_len+i] = sa[i];
         frame_len = frame_len + 6;
         for (i = 0; i < 2; i = i + 1) frame_bytes[frame_len+i] = ftype[i];
         frame_len = frame_len + 2;
         for (i = 0; i < plen; i = i + 1) frame_bytes[frame_len+i] = payload[i];
         frame_len = frame_len + plen;

         // Compute FCS with the reference CRC (hardware byte order)
         feed_crc_bytes;
         fcs_bytes[0] = ~rev8(ref_crc[31:24]);
         fcs_bytes[1] = ~rev8(ref_crc[23:16]);
         fcs_bytes[2] = ~rev8(ref_crc[15:8]);
         fcs_bytes[3] = ~rev8(ref_crc[7:0]);

         // Optional corruption: flip a payload bit
         if (corrupt) frame_bytes[14] = frame_bytes[14] ^ 8'h01;

         // Drive MII: preamble, SFD, frame, FCS
         @(negedge mii_rx_clk);
         mii_rx_dv <= 1;
         for (i = 0; i < 7; i = i + 1) mii_byte(8'h55);
         mii_byte(8'hD5);
         for (i = 0; i < frame_len; i = i + 1) mii_byte(frame_bytes[i]);
         mii_byte(fcs_bytes[0]);
         mii_byte(fcs_bytes[1]);
         mii_byte(fcs_bytes[2]);
         mii_byte(fcs_bytes[3]);
         @(negedge mii_rx_clk);
         mii_rx_dv <= 0;
         repeat (8) @(negedge mii_rx_clk);
      end
   endtask

   // ---------- Read-back tasks ----------
   integer rcv_count;
   integer test_fail;

   task pop_rx_data;
      output [7:0] b;
      begin
         @(negedge clk);
         if (rx_fifo_r_empty) begin
            $display("FAIL[%0t]: pop_rx_data from empty FIFO", $time);
            test_fail = 1;
            b = 8'hXX;
         end else begin
            rx_fifo_r_en <= 1;
            @(posedge clk);
            rx_fifo_r_en <= 0;
            @(posedge clk);
            @(posedge clk);
            b = rx_fifo_r_data;
         end
      end
   endtask

   task pop_rx_info;
      output [11:0] info;
      begin
         wait (!info_fifo_r_empty);
         @(negedge clk);
         info_fifo_r_en <= 1;
         @(posedge clk);
         info_fifo_r_en <= 0;
         @(posedge clk);
         @(posedge clk);
         info = info_fifo_r_data;
      end
   endtask

   // ---------- Frame verification ----------
   // Reads back the whole data FIFO (until empty) + the info word, and checks
   // against the frame that was sent. Also drains so the RX can re-arm.
   task check_received;
      input integer expect_crc;
      integer i;
      reg [7:0] b;
      reg [11:0] info;
      begin
         pop_rx_info(info);

         // Drain data FIFO completely, recording bytes
         rcv_count = 0;
         while (!rx_fifo_r_empty) begin
            pop_rx_data(b);
            if (rcv_count < 256) frame_recv[rcv_count] = b;
            rcv_count = rcv_count + 1;
         end

         $display("INFO[%0t]: info = {crc=%0d, len=%0d}, data bytes = %0d", $time,
                  info[11], info[10:0], rcv_count);

         if (info[11] !== expect_crc[0]) begin
            $display("FAIL[%0t]: crc_err = %0d, expected %0d", $time, info[11], expect_crc[0]);
            test_fail = 1;
         end

         if (info[10:0] !== 6 + 6 + 2 + plen + 4) begin
            $display("FAIL[%0t]: length = %0d, expected %0d", $time, info[10:0], 6 + 6 + 2 + plen + 4);
            test_fail = 1;
         end

         if (rcv_count !== 6 + 6 + 2 + plen + 4) begin
            $display("FAIL[%0t]: data FIFO bytes = %0d, expected %0d", $time, rcv_count, 6 + 6 + 2 + plen + 4);
            test_fail = 1;
         end

         // Compare byte-by-byte with the sent frame (DA..payload), then FCS
         for (i = 0; i < frame_len; i = i + 1) begin
            if (frame_recv[i] !== frame_bytes[i]) begin
               $display("FAIL[%0t]: recv[%0d] = %02h, expected %02h", $time, i, frame_recv[i], frame_bytes[i]);
               test_fail = 1;
            end
         end
         for (i = 0; i < 4; i = i + 1) begin
            if (frame_recv[frame_len + i] !== fcs_bytes[i]) begin
               $display("FAIL[%0t]: FCS[%0d] = %02h, expected %02h", $time, i, frame_recv[frame_len + i], fcs_bytes[i]);
               test_fail = 1;
            end
         end

         if (test_fail == 0 && expect_crc == 0) $display("PASS[%0t]: frame received correctly", $time);
         if (test_fail == 0 && expect_crc == 1) $display("PASS[%0t]: corrupted frame flagged", $time);

         // Wait for RX to return to idle (data FIFO drained -> w_empty)
         wait (rx_w_empty == 1'b1);
         repeat (4) @(negedge mii_rx_clk);
      end
   endtask

   reg [7:0] frame_recv [0:255];

   // ---------- Main sequence ----------
   integer i;
   initial begin
      test_fail = 0;

      da[0] = 8'h00; da[1] = 8'h11; da[2] = 8'h22; da[3] = 8'h33; da[4] = 8'h44; da[5] = 8'h55;
      sa[0] = 8'h66; sa[1] = 8'h77; sa[2] = 8'h88; sa[3] = 8'h99; sa[4] = 8'hAA; sa[5] = 8'hBB;
      ftype[0] = 8'h08; ftype[1] = 8'h00;
      plen = PAYLOAD_LEN;
      for (i = 0; i < plen; i = i + 1) payload[i] = i[7:0];

      wait (!arst);
      repeat (10) @(posedge clk);

      $display("=== RX TB: valid frame (%0d payload bytes) ===", plen);
      send_frame(0);
      check_received(0);

      $display("=== RX TB: corrupted frame (payload bit flip) ===");
      send_frame(1);
      check_received(1);

      $display("=== RX TB: valid frame again (re-arm check) ===");
      send_frame(0);
      check_received(0);

      if (test_fail) $display("=== RX TB: TESTS FAILED ===");
      else $display("=== RX TB: ALL TESTS PASSED ===");
      $finish;
   end

endmodule
