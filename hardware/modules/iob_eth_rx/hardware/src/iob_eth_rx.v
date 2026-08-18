// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0

`timescale 1ns / 1ps

`include "iob_eth_conf.vh"

module iob_eth_rx (
   `include "iob_eth_rx_io.vs"
);

   // Register MII inputs

   wire rx_dv;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) rx_dv_reg (
       .clk_i (rx_clk_i),
       .cke_i (1'b1),
       .arst_i(arst_i),
       .data_i(rx_dv_i),
       .data_o(rx_dv)
   );

   wire [3:0] rx_data;
   iob_reg_ca #(
      .DATA_W (4),
      .RST_VAL(0)
   ) rx_data_reg (
       .clk_i (rx_clk_i),
       .cke_i (1'b1),
       .arst_i(arst_i),
       .data_i(rx_data_i),
       .data_o(rx_data)
   );


   // state
   reg  [ 2:0] pc;
   reg  [47:0] dest_mac_addr;
   // addr_o counts bytes accepted into the data FIFO (see state 2/4); it is
   // stored in the frame info word so the Data Transfer block pops exactly
   // the number of bytes actually written.
   reg  [10:0] addr_o;

   // data
   wire [ 7:0] data_int;

   wire [31:0] crc_sum;

   wire        crc_err;

   //
   // RECEIVER PROGRAM
   //
   // FSM states:
   //   0 - wait for start-of-frame delimiter (SFD) and rx_dv; CRC held in reset
   //   1 - one-cycle gap while addr_o is cleared for the frame byte count
   //   2 - capture one destination-MAC byte (2 MII nibbles per byte)
   //   3 - loop until all 6 destination-MAC bytes have been accepted
   //   4 - write one payload byte
   //   5 - wait for end of frame (rx_dv deassertion)
   //   6 - frame complete: push {crc_err, length} info, return to state 0
   //
   // The FSM never parks on data-FIFO back-pressure: writes are skipped when
   // w_full_i is high, only accepted bytes are counted and CRC'd, and the
   // stored length matches the accepted count. A stalled Data Transfer block
   // therefore costs whole dropped frames (CRC error) but never wedges the
   // receive path, because the DT drains exactly the accepted bytes.
   always @(posedge rx_clk_i, posedge arst_i)

      if (arst_i) begin
         pc            <= 0;
         addr_o        <= 0;
         dest_mac_addr <= 0;
         wr_o          <= 0;
         info_wen_o    <= 0;
      end else begin

         pc         <= pc + 1'b1;
         wr_o       <= 0;
         info_wen_o <= 0;

         case (pc)

            // Wait for start-of-frame delimiter
            0: if (data_int != `IOB_ETH_SFD || !rx_dv) pc <= pc;

            1: addr_o <= 0;

            // Capture one destination-MAC byte. The byte is written to the
            // data FIFO only when it has room; addr_o counts accepted bytes.
            2: begin
               dest_mac_addr <= {dest_mac_addr[39:0], data_int};
               if (!w_full_i) begin
                  wr_o   <= 1;
                  addr_o <= addr_o + 1'b1;
               end
            end

            // Loop while the destination-MAC bytes are still being captured
            3:
            if (addr_o != `IOB_ETH_MAC_ADDR_LEN) begin
               pc <= pc - 1'b1;
            end

            // Write one payload byte, gated on data-FIFO room as in state 2
            4:
            if (!w_full_i) begin
               wr_o   <= 1;
               addr_o <= addr_o + 1'b1;
            end

            // Wait for end of frame
            5:
            if (rx_dv) begin
               pc <= pc - 1'b1;
            end

            // Frame complete: push the info word and return to the SFD wait
            // state. Never blocks on the data FIFO being drained; if the info
            // FIFO is momentarily full, hold here until it accepts the push
            // (the info FIFO is 8 entries deep, so this is a few cycles).
            6:
            if (!info_w_full_i) begin
               info_wen_o   <= 1;
               info_wdata_o <= {crc_err, addr_o[10:0]};
               addr_o       <= 0;
               pc           <= 0;
            end else begin
               pc <= pc;
            end

            default: pc <= 0;

         endcase
      end

   // capture RX_DATA
   assign data_int = {rx_data, data_o[7:4]};
   always @(posedge rx_clk_i, posedge arst_i)
      if (arst_i) data_o <= 0;
      else if (rx_dv) data_o <= data_int;

   //
   // CRC MODULE
   //
   // data_en_i is gated by wr_o, which is asserted only when a byte is
   // accepted into the data FIFO, so the CRC runs over exactly the stored
   // byte sequence. Any byte dropped due to FIFO back-pressure therefore
   // produces a CRC error and the whole frame is discarded by the driver.
   //
   iob_eth_crc crc_rx (
       .clk_i (rx_clk_i),
       .arst_i(arst_i),

       .start_i(pc == 0),

       .data_i   (data_o),
       .data_en_i(wr_o),
       .crc_o    (crc_sum)
   );

   assign crc_err = crc_sum != 32'hc704dd7b;

endmodule
