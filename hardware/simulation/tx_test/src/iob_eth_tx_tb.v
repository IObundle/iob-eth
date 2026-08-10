// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0
//
// Standalone testbench for iob_eth_tx.
//
// Harness mirrors iob_eth.v: a TX data FIFO (iob_fifo_async + iob_ram_at2p)
// written in the system clock domain and read in the MII TX clock domain,
// plus a reference iob_eth_crc used as an oracle to validate the FCS bytes.
//
// Checks:
//   - preamble/SFD bytes 55 55 55 55 55 55 55 D5 are transmitted first
//   - payload bytes are transmitted in order, low nibble first
//   - the 4 appended FCS bytes make CRC(payload+FCS) == 0xC704DD7B,
//     exactly the residue the receiver (iob_eth_rx) accepts
//   - tx_en_o timing and ready_o handshake
//   - the TX data FIFO is fully drained (no over/under-fetch)
//   - a second frame reuses the transmitter correctly

`timescale 1ns / 1ps

module iob_eth_tx_tb;

   localparam PAYLOAD_LEN = 16;
   localparam FRAME_LEN   = 8 + PAYLOAD_LEN + 4;  // preamble+SFD + payload + FCS

   // ---------- Clocks ----------
   reg clk = 0;          // system clock (FIFO write side), 100 MHz
   reg mii_tx_clk = 0;   // MII TX clock (DUT + FIFO read side), 25 MHz
   always #5 clk = ~clk;
   always #20 mii_tx_clk = ~mii_tx_clk;

   // ---------- Reset ----------
   reg arst = 1;
   initial #45 arst = 0;

   // ---------- DUT ----------
   wire       tx_pop_en;
   wire [7:0] tx_fifo_r_data;
   reg        send = 0;
   wire       tx_ready_o;
   reg  [10:0] nbytes = 0;
   reg        crc_en = 0;
   wire       tx_en_o;
   wire [3:0] tx_data_o;

   iob_eth_tx dut (
      .arst_i   (arst),
      .pop_en_o (tx_pop_en),
      .data_i   (tx_fifo_r_data),
      .send_i   (send),
      .ready_o  (tx_ready_o),
      .nbytes_i (nbytes),
      .crc_en_i (crc_en),
      .tx_clk_i (mii_tx_clk),
      .tx_en_o  (tx_en_o),
      .tx_data_o(tx_data_o)
   );

   // ---------- TX data FIFO + backing RAM ----------
   reg        tx_fifo_w_en   = 0;
   reg  [7:0] tx_fifo_w_data = 0;
   wire       tx_fifo_w_full;
   wire       tx_fifo_r_empty;
   wire [11:0] tx_fifo_w_level;
   wire [11:0] tx_fifo_r_level;

   wire        tx_fifo_ext_mem_w_clk;
   wire        tx_fifo_ext_mem_w_en;
   wire [10:0] tx_fifo_ext_mem_w_addr;
   wire [7:0]  tx_fifo_ext_mem_w_data;
   wire        tx_fifo_ext_mem_r_clk;
   wire        tx_fifo_ext_mem_r_en;
   wire [10:0] tx_fifo_ext_mem_r_addr;
   wire [7:0]  tx_fifo_ext_mem_r_data;

   iob_fifo_async #(
      .W_DATA_W(8),
      .R_DATA_W(8),
      .ADDR_W(11)
   ) tx_data_fifo (
      .w_clk_i             (clk),
      .w_cke_i             (1'b1),
      .w_arst_i            (arst),
      .w_rst_i             (1'b0),
      .r_clk_i             (mii_tx_clk),
      .r_cke_i             (1'b1),
      .r_arst_i            (arst),
      .r_rst_i             (1'b0),
      .w_en_i              (tx_fifo_w_en),
      .w_data_i            (tx_fifo_w_data),
      .w_full_o            (tx_fifo_w_full),
      .w_empty_o           (),
      .w_level_o           (tx_fifo_w_level),
      .r_en_i              (tx_pop_en),
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
      .ADDR_W(11),
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

   // ---------- Reference CRC oracle ----------
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

   // ---------- MII nibble capture ----------
   reg [3:0]  mii_nibbles [0:255];
   integer    mii_ncap = 0;

   always @(posedge mii_tx_clk or posedge arst) begin
      if (arst) mii_ncap <= 0;
      else if (tx_en_o) begin
         mii_nibbles[mii_ncap] <= tx_data_o;
         mii_ncap              <= mii_ncap + 1;
      end
   end

   // ---------- Shared arrays for tasks (iverilog lacks unpacked array ports) ----------
   reg  [7:0] task_payload [0:255];
   integer    task_plen;
   reg  [7:0] feed_bytes [0:255];
   integer    feed_cnt;

   // ---------- FIFO push task ----------
   task push_byte;
      input [7:0] b;
      begin
         @(negedge clk);
         while (tx_fifo_w_full) @(negedge clk);
         tx_fifo_w_en   <= 1'b1;
         tx_fifo_w_data <= b;
         @(posedge clk);
         @(negedge clk);
         tx_fifo_w_en <= 1'b0;
      end
   endtask

   // ---------- Reference CRC feed task (uses feed_bytes[0:feed_cnt-1]) ----------
   task feed_crc;
      integer i;
      begin
         // Pulse start_i one cycle before the first byte (loads 0xffffffff)
         @(negedge clk);
         ref_start <= 1;
         ref_en    <= 0;
         @(posedge clk);
         @(negedge clk);
         ref_start <= 0;
         for (i = 0; i < feed_cnt; i = i + 1) begin
            ref_en   <= 1;
            ref_data <= feed_bytes[i];
            @(posedge clk);
         end
         @(negedge clk);
         ref_en   <= 0;
         ref_data <= 0;
      end
   endtask

   // ---------- Frame transmit task (uses task_payload[0:task_plen-1]) ----------
   task transmit_frame;
      integer i;
      begin
         // Push preamble and SFD
         for (i = 0; i < 7; i = i + 1) push_byte(8'h55);
         push_byte(8'hD5);
         for (i = 0; i < task_plen; i = i + 1) push_byte(task_payload[i]);

         // Wait for the empty flag to sync to the read domain
         wait (tx_fifo_r_empty == 1'b0);
         repeat (5) @(negedge mii_tx_clk);

         // Request transmission (hold send until the TX latches it)
         send   = 1;
         nbytes = 8 + task_plen;
         crc_en = 1;
         wait (tx_ready_o == 1'b0);
         send = 0;

         // Wait for frame completion
         wait (tx_ready_o == 1'b1);
         crc_en = 0;
         repeat (2) @(posedge mii_tx_clk);
      end
   endtask

   // ---------- Frame check task (uses task_payload[0:task_plen-1]) ----------
   integer frame_pass;
   integer i;

   task check_frame;
      integer nbytes_exp;
      integer nerr;
      reg [7:0] exp_byte;
      reg [7:0] got_byte;
      reg [7:0] fcs_bytes [0:3];
      begin
         nerr = 0;
         nbytes_exp = 8 + task_plen + 4;

         // Nibble count must be 2 per byte
         if (mii_ncap != 2 * nbytes_exp) begin
            $display("FAIL[%0t]: nibble count %0d, expected %0d", $time, mii_ncap, 2 * nbytes_exp);
            nerr = nerr + 1;
         end

         // Preamble and SFD
         for (i = 0; i < 7; i = i + 1) begin
            exp_byte = 8'h55;
            got_byte = {mii_nibbles[2*i+1], mii_nibbles[2*i]};
            if (got_byte !== exp_byte) begin
               $display("FAIL[%0t]: preamble byte %0d = %02h, expected %02h", $time, i, got_byte, exp_byte);
               nerr = nerr + 1;
            end
         end
         got_byte = {mii_nibbles[15], mii_nibbles[14]};
         if (got_byte !== 8'hD5) begin
            $display("FAIL[%0t]: SFD byte = %02h, expected D5", $time, got_byte);
            nerr = nerr + 1;
         end

         // Payload
         for (i = 0; i < task_plen; i = i + 1) begin
            got_byte = {mii_nibbles[2*(8+i)+1], mii_nibbles[2*(8+i)]};
            if (got_byte !== task_payload[i]) begin
               $display("FAIL[%0t]: payload byte %0d = %02h, expected %02h", $time, i, got_byte, task_payload[i]);
               nerr = nerr + 1;
            end
         end

         // FCS bytes (4)
         for (i = 0; i < 4; i = i + 1) begin
            fcs_bytes[i] = {mii_nibbles[2*(8+task_plen+i)+1], mii_nibbles[2*(8+task_plen+i)]};
         end

         // CRC residue check: CRC(payload + FCS) must be the receiver's magic residue
         feed_cnt = task_plen + 4;
         for (i = 0; i < task_plen; i = i + 1) feed_bytes[i] = task_payload[i];
         for (i = 0; i < 4; i = i + 1) feed_bytes[task_plen + i] = fcs_bytes[i];
         feed_crc;
         if (ref_crc !== 32'hc704dd7b) begin
            $display("FAIL[%0t]: CRC residue = %08h, expected c704dd7b", $time, ref_crc);
            nerr = nerr + 1;
         end else begin
            $display("PASS[%0t]: CRC residue check (FCS bytes = %02h%02h%02h%02h)", $time,
                     fcs_bytes[0], fcs_bytes[1], fcs_bytes[2], fcs_bytes[3]);
         end

         if (nerr == 0) $display("PASS[%0t]: frame OK (%0d payload bytes)", $time, task_plen);
         else begin
            $display("FAIL[%0t]: frame has %0d error(s)", $time, nerr);
            frame_pass = 0;
         end
      end
   endtask

   // ---------- Main sequence ----------
   initial begin
      frame_pass = 1;

      wait (!arst);
      repeat (10) @(posedge clk);

      $display("=== TX TB: frame 1 (16 payload bytes) ===");
      task_plen = PAYLOAD_LEN;
      for (i = 0; i < PAYLOAD_LEN; i = i + 1) task_payload[i] = i[7:0];
      mii_ncap <= 0;
      transmit_frame;
      check_frame;

      // FIFO must be fully drained by the transmitter
      if (tx_fifo_r_empty !== 1'b1) begin
         $display("FAIL[%0t]: TX FIFO not empty after frame 1", $time);
         frame_pass = 0;
      end else begin
         $display("PASS[%0t]: TX FIFO drained after frame 1", $time);
      end

      $display("=== TX TB: frame 2 (4 payload bytes, reuse) ===");
      task_plen = 4;
      task_payload[0] = 8'hDE; task_payload[1] = 8'hAD; task_payload[2] = 8'hBE; task_payload[3] = 8'hEF;
      mii_ncap <= 0;
      transmit_frame;
      check_frame;

      if (tx_fifo_r_empty !== 1'b1) begin
         $display("FAIL[%0t]: TX FIFO not empty after frame 2", $time);
         frame_pass = 0;
      end

      if (frame_pass) $display("=== TX TB: ALL TESTS PASSED ===");
      else $display("=== TX TB: TESTS FAILED ===");
      $finish;
   end

endmodule
