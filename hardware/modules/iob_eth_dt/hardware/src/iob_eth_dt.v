// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0

`timescale 1ns / 1ps

`include "iob_eth_conf.vh"
`include "iob_eth_dt_conf.vh"

`define IOB_MIN(a, b) (((a) < (b)) ? (a) : (b))

module iob_eth_dt #(
   `include "iob_eth_dt_params.vs"
) (
   `include "iob_eth_dt_io.vs"
);
   localparam AXI_MAX_BURST_LEN = 16;
   localparam [BUFFER_W-1:0] PRE_FRAME_LEN = `IOB_ETH_PREAMBLE_LEN + 1;

   // ############# Transmitter #############

   reg                  rx_req;
   reg                  tx_req;
   wire [          1:0] bd_mem_arbiter_req = {rx_req, tx_req};
   wire [          1:0] bd_mem_arbiter_ack;
   wire [          1:0] bd_mem_arbiter_grant;
   wire                 bd_mem_arbiter_grant_valid;
   wire [$clog2(2)-1:0] bd_mem_arbiter_grant_encoded;
   iob_arbiter #(
      .PORTS       (2),
      // arbitration type: "PRIORITY" or "ROUND_ROBIN"
      .TYPE        ("ROUND_ROBIN"),
      // block type: "NONE", "REQUEST", "ACKNOWLEDGE"
      .BLOCK       ("NONE"),
      // LSB priority: "LOW", "HIGH"
      .LSB_PRIORITY("LOW")
   ) bd_mem_arbiter (
      .clk (clk_i),
      .arst(arst_i),
      .rst (1'b0),

      .request    (bd_mem_arbiter_req),
      .acknowledge(bd_mem_arbiter_ack),

      .grant        (bd_mem_arbiter_grant),
      .grant_valid  (bd_mem_arbiter_grant_valid),
      .grant_encoded(bd_mem_arbiter_grant_encoded)
   );

   assign bd_mem_arbiter_ack = bd_mem_arbiter_grant & {2{bd_mem_arbiter_grant_valid}};


   reg [ BD_ADDR_W-1:0] tx_bd_addr_o;
   reg [ BD_ADDR_W-1:0] rx_bd_addr_o;
   reg                  tx_bd_wen_o;
   reg                  rx_bd_wen_o;
   reg [        32-1:0] tx_bd_o;
   reg [        32-1:0] rx_bd_o;

   reg [AXI_ADDR_W-1:0] axi_araddr_o_reg;
   reg                  axi_arvalid_o_reg;
   reg                  axi_rready_o_reg;
   assign axi_araddr_o  = axi_araddr_o_reg;
   assign axi_arvalid_o = axi_arvalid_o_reg;
   assign axi_rready_o  = axi_rready_o_reg;

   reg [AXI_ADDR_W-1:0] axi_awaddr_o_reg;
   reg                  axi_awvalid_o_reg;
   reg                  axi_wvalid_o_reg;
   reg [         4-1:0] axi_wstrb_o_reg;
   reg [AXI_DATA_W-1:0] axi_wdata_o_reg;
   reg                  axi_wlast_o_reg;
   assign axi_awaddr_o      = axi_awaddr_o_reg;
   assign axi_awvalid_o     = axi_awvalid_o_reg;
   assign axi_wvalid_o      = axi_wvalid_o_reg;
   assign axi_wstrb_o       = axi_wstrb_o_reg;
   assign axi_wdata_o       = axi_wdata_o_reg;
   assign axi_wlast_o       = axi_wlast_o_reg;


   // Connect BD memory bus based on arbiter selection
   assign bd_addr_o         = bd_mem_arbiter_grant_encoded == 0 ? tx_bd_addr_o : rx_bd_addr_o;
   assign bd_wen_o          = bd_mem_arbiter_grant_encoded == 0 ? tx_bd_wen_o : rx_bd_wen_o;
   assign bd_o              = bd_mem_arbiter_grant_encoded == 0 ? tx_bd_o : rx_bd_o;

   assign bd_en_o           = 1;

   //tx program
   reg  [4-1:0] tx_state_nxt;
   wire [4-1:0] tx_state;
   iob_reg_ca #(
      .DATA_W (4),
      .RST_VAL(0)
   ) tx_state_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_state_nxt),
      .data_o(tx_state)
   );

   reg  [32-1:0] tx_buffer_byte_counter_nxt;
   wire [32-1:0] tx_buffer_byte_counter;
   iob_reg_ca #(
      .DATA_W (32),
      .RST_VAL(0)
   ) tx_buffer_byte_counter_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_buffer_byte_counter_nxt),
      .data_o(tx_buffer_byte_counter)
   );

   reg  [BD_ADDR_W-2:0] tx_bd_num_nxt;
   wire [BD_ADDR_W-2:0] tx_bd_num;
   iob_reg_ca #(
      .DATA_W (BD_ADDR_W - 1),
      .RST_VAL(0)
   ) tx_bd_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_bd_num_nxt),
      .data_o(tx_bd_num)
   );

   reg  [32-1:0] tx_buffer_descriptor_nxt;
   wire [32-1:0] tx_buffer_descriptor;
   iob_reg_ca #(
      .DATA_W (32),
      .RST_VAL(0)
   ) tx_buffer_descriptor_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_buffer_descriptor_nxt),
      .data_o(tx_buffer_descriptor)
   );

   wire [15:0] tx_buffer_diff;
   assign tx_buffer_diff = tx_buffer_descriptor[31:16] - tx_buffer_byte_counter[15:0];

   reg  [AXI_ADDR_W-1:0] tx_buffer_ptr_nxt;
   wire [AXI_ADDR_W-1:0] tx_buffer_ptr;
   iob_reg_ca #(
      .DATA_W (AXI_ADDR_W),
      .RST_VAL(0)
   ) tx_buffer_ptr_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_buffer_ptr_nxt),
      .data_o(tx_buffer_ptr)
   );

   reg  [AXI_LEN_W-1:0] axi_arlen_nxt;
   wire [AXI_LEN_W-1:0] axi_arlen;
   iob_reg_ca #(
      .DATA_W (AXI_LEN_W),
      .RST_VAL(0)
   ) axi_arlen_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(axi_arlen_nxt),
      .data_o(axi_arlen)
   );
   assign axi_arlen_o = axi_arlen_nxt;

   reg  [1-1:0] crc_en_nxt;
   wire [1-1:0] crc_en;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) crc_en_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(crc_en_nxt),
      .data_o(crc_en)
   );
   assign crc_en_o = crc_en;

   reg  [11-1:0] tx_nbytes_nxt;
   wire [11-1:0] tx_nbytes;
   iob_reg_ca #(
      .DATA_W (11),
      .RST_VAL(0)
   ) tx_nbytes_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_nbytes_nxt),
      .data_o(tx_nbytes)
   );
   assign tx_nbytes_o = tx_nbytes;

   reg  [1-1:0] send_nxt;
   wire [1-1:0] send;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) send_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(send_nxt),
      .data_o(send)
   );
   assign send_o = send;

   reg  [BUFFER_W-1:0] tx_preamble_cnt_nxt;
   wire [BUFFER_W-1:0] tx_preamble_cnt;
   iob_reg_ca #(
      .DATA_W (BUFFER_W),
      .RST_VAL(0)
   ) tx_preamble_cnt_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_preamble_cnt_nxt),
      .data_o(tx_preamble_cnt)
   );

   always @* begin
      tx_req                     = 0;
      tx_state_nxt               = tx_state + 1'b1;
      tx_bd_num_nxt              = tx_bd_num;
      tx_bd_addr_o               = 0;
      tx_bd_wen_o                = 0;
      tx_bd_o                    = 0;
      send_nxt                   = send;
      axi_arvalid_o_reg          = 0;
      axi_rready_o_reg           = 0;
      eth_data_wr_wen_o          = 0;
      eth_data_wr_wdata_o        = 0;
      tx_frame_word_ready_o      = 0;
      tx_irq_o                   = 0;
      // No-DMA interface
      tx_bd_cnt_o                = 0;
      tx_word_cnt_o              = 0;

      tx_buffer_byte_counter_nxt = tx_buffer_byte_counter;
      axi_araddr_o_reg           = 0;
      axi_arlen_nxt              = axi_arlen;
      crc_en_nxt                 = crc_en;
      tx_nbytes_nxt              = tx_nbytes;
      tx_buffer_descriptor_nxt   = tx_buffer_descriptor;
      tx_buffer_ptr_nxt          = tx_buffer_ptr;
      tx_preamble_cnt_nxt        = tx_preamble_cnt;

      if (arst_i) begin

         tx_state_nxt          = 0;  // Idle
         tx_bd_num_nxt         = 0;
         tx_bd_addr_o          = 0;
         tx_bd_wen_o           = 0;
         tx_bd_o               = 0;
         send_nxt              = 0;
         axi_arvalid_o_reg     = 0;
         axi_rready_o_reg      = 0;
         eth_data_wr_wen_o     = 0;
         tx_frame_word_ready_o = 0;
         tx_irq_o              = 0;
         // No-DMA interface
         tx_bd_cnt_o           = 0;
         tx_word_cnt_o         = 0;
         tx_preamble_cnt_nxt   = 0;

      end else begin

         case (tx_state)

            0: begin  // Request buffer descriptor
               tx_bd_addr_o = tx_bd_num << 1;
               tx_req       = 1;
               send_nxt     = 0;
               tx_irq_o     = 0;
               tx_bd_wen_o  = 0;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[0] || !bd_mem_arbiter_grant_valid) tx_state_nxt = tx_state;
            end

            1: begin  // Read buffer descriptor.
               tx_buffer_descriptor_nxt = bd_i;

               // Wait for ready bit and tx enable
               if (!tx_buffer_descriptor_nxt[15] || !tx_en_i) tx_state_nxt = tx_state - 1'b1;
            end

             2: begin  //Request buffer pointer
               tx_bd_addr_o = (tx_bd_num << 1) + {{(BD_ADDR_W - 1) {1'b0}}, {1'b1}};
               tx_req       = 1;
               tx_preamble_cnt_nxt = 0;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[0] || !bd_mem_arbiter_grant_valid) tx_state_nxt = tx_state;
            end

            3: begin  // Read buffer pointer (sample once, then advance)
               tx_buffer_ptr_nxt          = bd_i[AXI_ADDR_W-1:0];
               tx_buffer_byte_counter_nxt = 0;
            end

            4: begin  // Push preamble and SFD to TX FIFO, wait for transmitter idle
               if (tx_ready_i) begin
                  if (tx_preamble_cnt < PRE_FRAME_LEN) begin
                     // Push preamble and SFD bytes to the data FIFO
                     if (!tx_w_full_i) begin
                        eth_data_wr_wen_o = 1;
                        if (tx_preamble_cnt == `IOB_ETH_PREAMBLE_LEN) eth_data_wr_wdata_o = `IOB_ETH_SFD;
                        else eth_data_wr_wdata_o = `IOB_ETH_PREAMBLE;
                        tx_preamble_cnt_nxt = tx_preamble_cnt + 1'b1;
                     end
                     // Stay here until the full preamble is pushed
                     tx_state_nxt = tx_state;
                  end else begin
                     // Preamble complete, start frame transfer
                     tx_state_nxt = tx_state + 1'b1;
                  end
               end else begin
                  // Transmitter still busy with previous frame; wait here
                  // (buffer pointer was already captured in state 3)
                  tx_state_nxt = tx_state;
               end
            end

            5: begin  // Start frame transfer from external memory
               axi_araddr_o_reg = tx_buffer_ptr + tx_buffer_byte_counter[AXI_ADDR_W-1:0];
               if (AXI_MAX_BURST_LEN < tx_buffer_diff) begin
                  axi_arlen_nxt = AXI_MAX_BURST_LEN[AXI_LEN_W-1:0] - 1;
               end else begin
                  axi_arlen_nxt = tx_buffer_diff[AXI_LEN_W-1:0] - 1;
               end
               axi_arvalid_o_reg = 1;
               axi_rready_o_reg  = 0;
               eth_data_wr_wen_o = 0;

               // Wait for address ready
               if (!axi_arready_i) tx_state_nxt = tx_state;

               // Check if frame transfer is complete
               // Length field from BD bits [31:16] (Linux ethoc compatible format)
               if ({3'd0, tx_buffer_descriptor[28:16]} - tx_buffer_byte_counter[15:0] == 0) begin
                  axi_arvalid_o_reg = 0;

                  // Configure transmitter settings
                  crc_en_nxt = 1'b1;  // Always enable CRC (Linux ethoc driver expects this)
                  tx_nbytes_nxt = PRE_FRAME_LEN + tx_buffer_descriptor[26:16]; // payload length from BD bits [31:16]
                  send_nxt = 1;

                  // Disable ready bit
                  tx_buffer_descriptor_nxt[15] = 0;

                   // Write transmit status
                   tx_state_nxt = 7;
               end

               // No-DMA interface
               tx_bd_cnt_o           = tx_bd_num;
               tx_word_cnt_o         = tx_buffer_byte_counter[10:0];
               tx_frame_word_ready_o = ~tx_w_full_i;
               if (tx_frame_word_wen_i && !tx_w_full_i) begin
                  tx_buffer_byte_counter_nxt = tx_buffer_byte_counter + 1'b1;
                  // Send word from CPU to buffer
                  eth_data_wr_wen_o          = 1;
                  eth_data_wr_wdata_o        = tx_frame_word_wdata_i;
               end

            end

            6: begin  // Transfer frame word from memory to buffer
               tx_state_nxt      = tx_state;
               axi_rready_o_reg  = 0;
               axi_arvalid_o_reg = 0;

               if (axi_rvalid_i == 1 && !tx_w_full_i) begin
                  tx_buffer_byte_counter_nxt = tx_buffer_byte_counter + 1'b1;
                  axi_rready_o_reg = 1;
                  // Send word to buffer
                  eth_data_wr_wen_o = 1;

                  axi_araddr_o_reg = tx_buffer_ptr + tx_buffer_byte_counter[AXI_ADDR_W-1:0];
                  eth_data_wr_wdata_o = axi_rdata_i[axi_araddr_o_reg[1:0]*8+:8];

                  if (axi_rlast_i == 1) tx_state_nxt = tx_state - 1'b1;
               end

            end

            7: begin  // Wait for send_o to be read by transmitter
               tx_state_nxt          = tx_state;
               tx_frame_word_ready_o = 0;
               if (!tx_ready_i) begin
                  send_nxt     = 0;
                  tx_state_nxt = tx_state + 1'b1;
               end
            end

            8: begin  // Write transmit status
               tx_state_nxt = tx_state;

               tx_bd_addr_o = tx_bd_num << 1;
               tx_bd_wen_o  = 1;
               tx_bd_o      = tx_buffer_descriptor;
               tx_req       = 1;

               // Wait for arbiter
               if (bd_mem_arbiter_grant[0] && bd_mem_arbiter_grant_valid) begin
                  // Generate interrupt
                  tx_irq_o = tx_buffer_descriptor[14];

                  // Select next BD address based on WR bit
                  if (tx_buffer_descriptor[13] == 0) tx_bd_num_nxt = tx_bd_num + 1'b1;
                  else tx_bd_num_nxt = 0;

                  // Reset BD number if reached maximum
                  if (tx_buffer_descriptor[13] == 0 && tx_bd_num == tx_bd_num_i - 1'b1)
                     tx_bd_num_nxt = 0;

                  // Go to next buffer descriptor
                  tx_state_nxt = 0;
               end
            end

            default: ;

         endcase

      end
   end

   // AXI manager Read interface
   // Constants
   assign axi_arid_o    = 0;
   assign axi_arsize_o  = 0;  // arsize=0 to transfer 8-bit data
   assign axi_arburst_o = 1;
   assign axi_arlock_o  = 0;
   assign axi_arcache_o = 2;
   assign axi_arqos_o   = 0;
   //axi_rid_i
   //axi_rresp_i

   // ############# Receiver #############

   //rx program
   reg  [3-1:0] rx_state_nxt;
   wire [3-1:0] rx_state;
   iob_reg_ca #(
      .DATA_W (3),
      .RST_VAL(0)
   ) rx_state_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_state_nxt),
      .data_o(rx_state)
   );

   reg  [32-1:0] rx_buffer_byte_counter_nxt;
   wire [32-1:0] rx_buffer_byte_counter;
   iob_reg_ca #(
      .DATA_W (32),
      .RST_VAL(0)
   ) rx_buffer_byte_counter_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_buffer_byte_counter_nxt),
      .data_o(rx_buffer_byte_counter)
   );

   wire [11-1:0] rx_buffer_diff;
   assign rx_buffer_diff = rx_length - rx_buffer_byte_counter[10:0];

   reg  [BD_ADDR_W-2:0] rx_bd_num_nxt;
   wire [BD_ADDR_W-2:0] rx_bd_num;
   iob_reg_ca #(
      .DATA_W (BD_ADDR_W - 1),
      .RST_VAL({1'b1, {(BD_ADDR_W - 2) {1'b0}}})  // 2nd half of BD_ADDR_W range
   ) rx_bd_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_bd_num_nxt),
      .data_o(rx_bd_num)
   );

   reg  [BD_ADDR_W-2:0] tx_bd_num_prev_nxt;
   wire [BD_ADDR_W-2:0] tx_bd_num_prev;
   iob_reg_ca #(
      .DATA_W (BD_ADDR_W - 1),
      .RST_VAL(0)
   ) tx_bd_num_prev_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_bd_num_prev_nxt),
      .data_o(tx_bd_num_prev)
   );

   reg  [AXI_LEN_W-1:0] rx_burst_word_num_nxt;
   wire [AXI_LEN_W-1:0] rx_burst_word_num;
   iob_reg_ca #(
      .DATA_W (AXI_LEN_W),
      .RST_VAL(0)
   ) rx_burst_word_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_burst_word_num_nxt),
      .data_o(rx_burst_word_num)
   );

   reg  [32-1:0] rx_buffer_descriptor_nxt;
   wire [32-1:0] rx_buffer_descriptor;
   iob_reg_ca #(
      .DATA_W (32),
      .RST_VAL(0)
   ) rx_buffer_descriptor_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_buffer_descriptor_nxt),
      .data_o(rx_buffer_descriptor)
   );

   reg  [AXI_ADDR_W-1:0] rx_buffer_ptr_nxt;
   wire [AXI_ADDR_W-1:0] rx_buffer_ptr;
   iob_reg_ca #(
      .DATA_W (AXI_ADDR_W),
      .RST_VAL(0)
   ) rx_buffer_ptr_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_buffer_ptr_nxt),
      .data_o(rx_buffer_ptr)
   );

   reg  [AXI_LEN_W-1:0] axi_awlen_nxt;
   wire [AXI_LEN_W-1:0] axi_awlen;
   iob_reg_ca #(
      .DATA_W (AXI_LEN_W),
      .RST_VAL(0)
   ) axi_awlen_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(axi_awlen_nxt),
      .data_o(axi_awlen)
   );
   assign axi_awlen_o = axi_awlen_nxt;

   reg  [11-1:0] rx_length_nxt;
   wire [11-1:0] rx_length;
   iob_reg_ca #(
      .DATA_W (11),
      .RST_VAL(0)
   ) rx_length_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_length_nxt),
      .data_o(rx_length)
   );
   assign rx_nbytes_o = rx_length;

   reg  [1-1:0] rx_crc_nxt;
   wire [1-1:0] rx_crc;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) rx_crc_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_crc_nxt),
      .data_o(rx_crc)
   );

   reg  [1-1:0] rx_info_pop_pending_nxt;
   wire [1-1:0] rx_info_pop_pending;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) rx_info_pop_pending_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_info_pop_pending_nxt),
      .data_o(rx_info_pop_pending)
   );

   reg  [1-1:0] rx_nbytes_valid_nxt;
   wire [1-1:0] rx_nbytes_valid;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) rx_nbytes_valid_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_nbytes_valid_nxt),
      .data_o(rx_nbytes_valid)
   );
   assign rx_nbytes_valid_o = rx_nbytes_valid;

   reg [8-1:0] rx_frame_word_rdata_o_nxt;
   iob_reg_ca #(
      .DATA_W (8),
      .RST_VAL(0)
   ) rx_frame_word_rdata_o_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_frame_word_rdata_o_nxt),
      .data_o(rx_frame_word_rdata_o)
   );

   reg rx_frame_word_rvalid_o_nxt;
   iob_reg_ca #(
      .DATA_W (1),
      .RST_VAL(0)
   ) rx_frame_word_rvalid_o_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_frame_word_rvalid_o_nxt),
      .data_o(rx_frame_word_rvalid_o)
   );

   always @* begin
      rx_req                     = 0;
      rx_state_nxt               = rx_state + 1'b1;
      rx_bd_num_nxt              = rx_bd_num;
      tx_bd_num_prev_nxt         = tx_bd_num_prev;
      rx_bd_addr_o               = 0;
      rx_bd_wen_o                = 0;
      rx_bd_o                    = 0;
      axi_awvalid_o_reg          = 0;
      axi_wvalid_o_reg           = 0;
      axi_wlast_o_reg            = 0;
      rx_irq_o                   = 0;
      // No-DMA interface
      rx_bd_cnt_o                = 0;
      rx_word_cnt_o              = 0;
      rx_frame_word_rdata_o_nxt  = 8'b0;
      rx_frame_word_rvalid_o_nxt = 0;
      rx_frame_word_ready_o      = 0;
      eth_data_rd_pop_o          = 0;
      eth_rx_info_pop_o          = 0;

      axi_awaddr_o_reg           = 0;
      axi_wstrb_o_reg            = 0;
      axi_wdata_o_reg            = 0;
      rx_buffer_byte_counter_nxt = rx_buffer_byte_counter;
      rx_burst_word_num_nxt      = rx_burst_word_num;
      axi_awlen_nxt              = axi_awlen;
      rx_buffer_descriptor_nxt   = rx_buffer_descriptor;
      rx_buffer_ptr_nxt          = rx_buffer_ptr;
      rx_length_nxt              = rx_length;
      rx_crc_nxt                 = rx_crc;
      rx_info_pop_pending_nxt    = rx_info_pop_pending;
      rx_nbytes_valid_nxt        = rx_nbytes_valid;


      if (arst_i) begin

         rx_state_nxt               = 0;
         rx_bd_num_nxt              = tx_bd_num_i;
         rx_bd_addr_o               = 0;
         rx_bd_wen_o                = 0;
         rx_bd_o                    = 0;
         axi_awvalid_o_reg          = 0;
         axi_wvalid_o_reg           = 0;
         axi_wlast_o_reg            = 0;
         rx_irq_o                   = 0;
         // No-DMA interface
         rx_bd_cnt_o                = 0;
         rx_word_cnt_o              = 0;
         rx_frame_word_rdata_o_nxt  = 8'b0;
         rx_frame_word_rvalid_o_nxt = 0;
         rx_frame_word_ready_o      = 0;
         rx_length_nxt              = 0;
         rx_crc_nxt                 = 0;
         rx_info_pop_pending_nxt    = 0;
         rx_nbytes_valid_nxt        = 0;

      end else begin

         case (rx_state)

            0: begin  // Request buffer descriptor
               rx_bd_addr_o = rx_bd_num << 1;
               rx_req       = 1;
               rx_irq_o     = 0;
               rx_bd_wen_o  = 0;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[1] || !bd_mem_arbiter_grant_valid) rx_state_nxt = rx_state;

            end

            1: begin  // Read buffer descriptor.
               rx_buffer_descriptor_nxt = bd_i;

               // Wait for ready bit and rx enable
               if (!rx_buffer_descriptor_nxt[15] || !rx_en_i) rx_state_nxt = rx_state - 1'b1;
            end

            2: begin  //Request buffer pointer
               rx_bd_addr_o = (rx_bd_num << 1) + {{(BD_ADDR_W - 1) {1'b0}}, {1'b1}};
               rx_req       = 1;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[1] || !bd_mem_arbiter_grant_valid) rx_state_nxt = rx_state;
            end

            3: begin  // Read buffer pointer (sample once, then advance)
               rx_buffer_ptr_nxt          = bd_i[AXI_ADDR_W-1:0];
               rx_buffer_byte_counter_nxt = 0;
            end

            4: begin  // Pop frame info
               if (!rx_info_pop_pending) begin
                  if (!eth_rx_info_empty_i) begin
                     // Pop frame info from the info FIFO
                     eth_rx_info_pop_o       = 1;
                     rx_info_pop_pending_nxt = 1;
                     rx_state_nxt            = rx_state;
                  end else begin
                     // No frame info yet, wait for the frame to arrive
                     // (buffer pointer was already captured in state 3)
                     rx_state_nxt = rx_state;
                  end
               end else begin
                  // Info data is now valid (1-cycle FIFO read latency)
                  rx_length_nxt             = eth_rx_info_rdata_i[10:0];
                  rx_crc_nxt                = eth_rx_info_rdata_i[11];
                  rx_nbytes_valid_nxt       = 1;
                  // Prefetch first data byte
                  eth_data_rd_pop_o         = 1;
                  rx_info_pop_pending_nxt   = 0;
               end
            end

            5: begin  // Start frame transfer to external memory
               // TODO: If awlen > 0, ensure that awaddr does not cause
               // a transaction that may cross the AXI 4k boundary

               axi_awaddr_o_reg = rx_buffer_ptr + rx_buffer_byte_counter[AXI_ADDR_W-1:0];
               if (AXI_MAX_BURST_LEN < rx_buffer_diff) begin
                  axi_awlen_nxt = AXI_MAX_BURST_LEN[AXI_LEN_W-1:0] - 1'b1;
               end else begin
                  axi_awlen_nxt = rx_buffer_diff[AXI_LEN_W-1:0] - 1'b1;
               end
               axi_awvalid_o_reg     = 1;
               axi_wvalid_o_reg      = 0;
               axi_wlast_o_reg       = 0;
               rx_burst_word_num_nxt = 0;

               // Wait for address ready
               if (!axi_awready_i) rx_state_nxt = rx_state;

               // Check if frame transfer is complete
               if (rx_buffer_diff == 11'b0) begin
                  axi_awvalid_o_reg               = 0;

                  // Disable ready bit
                  rx_buffer_descriptor_nxt[15]    = 0;
                  // Write crc_err
                  rx_buffer_descriptor_nxt[1]     = rx_crc;
                  // Write buffer size
                  rx_buffer_descriptor_nxt[31:16] = {5'b0, rx_length};

                  // Length no longer available to software
                  rx_nbytes_valid_nxt             = 0;

                   // Write receive status
                   rx_state_nxt                    = 7;
                end

                // No-DMA interface
                rx_bd_cnt_o           = rx_bd_num;
                rx_word_cnt_o         = rx_buffer_byte_counter[10:0];
                rx_frame_word_ready_o = 1;
                if (rx_frame_word_ren_i) begin
                   rx_buffer_byte_counter_nxt = rx_buffer_byte_counter + 1'b1;
                   // Pop next byte, but not past the end of the frame
                   if (rx_buffer_byte_counter + 1'b1 < rx_length) eth_data_rd_pop_o = 1;
                   // Send word from buffer to CPU
                   rx_frame_word_rdata_o_nxt  = eth_data_rd_rdata_i;
                   rx_frame_word_rvalid_o_nxt = 1;
                end

            end

            6: begin  // Transfer frame word from buffer to memory
               rx_state_nxt = rx_state;
               axi_awvalid_o_reg = 0;
               axi_wvalid_o_reg = 1;

               axi_awaddr_o_reg = rx_buffer_ptr + rx_buffer_byte_counter[AXI_ADDR_W-1:0];
               axi_wstrb_o_reg = 1 << axi_awaddr_o_reg[1:0];
               axi_wdata_o_reg    = {{(AXI_DATA_W-8){1'b0}}, eth_data_rd_rdata_i} << (axi_awaddr_o_reg[1:0] * 8);

               // Enable wlast in last transfer of the burst
               if (rx_burst_word_num == axi_awlen) begin
                  axi_wlast_o_reg = 1;
               end

               // wait for write ready
               if (axi_wready_i == 1) begin
                  rx_buffer_byte_counter_nxt = rx_buffer_byte_counter + 1'b1;
                  // Pop next byte, but not past the end of the frame
                  if (rx_buffer_byte_counter + 1'b1 < rx_length) eth_data_rd_pop_o = 1;
                  rx_burst_word_num_nxt = rx_burst_word_num + 1'b1;

                  // Burst complete
                  if (rx_burst_word_num == axi_awlen) begin
                     rx_state_nxt = rx_state - 1'b1;
                  end
               end

            end

            7: begin  // Write receive status
               rx_state_nxt = rx_state;

               rx_bd_addr_o = rx_bd_num << 1;
               rx_bd_wen_o = 1;
               // Clear READY bit, set received length in bits [31:16] (Linux ethoc compatible format)
               // Length and CRC flags are the values latched from the info FIFO in state 3 and
               // stored into rx_buffer_descriptor in state 4.
               rx_bd_o = {
                  rx_buffer_descriptor[31:16],
                  1'b0,
                  rx_buffer_descriptor[14:13],
                  rx_buffer_descriptor[12:0]
               };
               rx_req = 1;

               // Wait for arbiter
               if (bd_mem_arbiter_grant[1] && bd_mem_arbiter_grant_valid) begin
                  // Generate interrupt
                  rx_irq_o = rx_buffer_descriptor[14];

                  // Select next BD address based on WR bit
                  if (rx_buffer_descriptor[13] == 0) rx_bd_num_nxt = rx_bd_num + 1'b1;
                  else rx_bd_num_nxt = tx_bd_num_i;

                  // Reset BD number if reached maximum
                  if (rx_buffer_descriptor[13] == 0 && &rx_bd_num) rx_bd_num_nxt = tx_bd_num_i;


                  // Go to next buffer descriptor
                  rx_state_nxt = 0;
               end
            end

            default: ;

         endcase

         // Edge detection: re-initialize rx_bd_num when tx_bd_num_i changes
         tx_bd_num_prev_nxt = tx_bd_num_i;
         if (tx_bd_num_i != tx_bd_num_prev) begin
            rx_bd_num_nxt      = tx_bd_num_i;
            tx_bd_num_prev_nxt = tx_bd_num_i;
            rx_state_nxt       = 0;
         end

      end
   end

   // AXI manager Write interface
   // Constants
   assign axi_awid_o    = 0;
   assign axi_awsize_o  = 0;  // awsize=0 to transfer 8-bit data
   assign axi_awburst_o = 1;
   assign axi_awlock_o  = 0;
   assign axi_awcache_o = 2;
   assign axi_awqos_o   = 0;
   assign axi_bready_o  = 1;
   // axi_bid_i
   // axi_bresp_i,
   // axi_bvalid_i



endmodule
