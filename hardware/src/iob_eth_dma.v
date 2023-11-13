`timescale 1ns / 1ps

`include "iob_eth_conf.vh"
`include "iob_eth_swreg_def.vh"

module iob_eth_dma #(
   parameter AXI_ADDR_W = 0,
   parameter AXI_DATA_W = 32,          // We currently only support 4 byte transfers
   parameter AXI_LEN_W  = 8,
   parameter AXI_ID_W   = 1,
   parameter BUFFER_W   = 11,
   parameter BD_ADDR_W  = 8 // 128 buffers (2x 32-bit words each)
) (
   // Control interface
   input         rx_en_i,
   input         tx_en_i,
   input [BD_ADDR_W-1:0] tx_bd_num_i,

   // Buffer descriptors
   output                 bd_en_o,
   output [BD_ADDR_W-1:0] bd_addr_o,
   output                 bd_wen_o,
   input  [32-1:0]        bd_i,
   output [32-1:0]        bd_o,

   // TX Front-End
   output reg                     eth_data_wr_wen_o,
   output reg [4-1:0]             eth_data_wr_wstrb_o,
   output reg [BUFFER_W-1:0]      eth_data_wr_addr_o,
   output reg [32-1:0]            eth_data_wr_wdata_o,
   output reg                     tx_ready_i,
   output reg                     crc_en_o,
   output reg [11-1:0]            tx_nbytes_o,
   output reg                     send_o,

   // RX Back-End
   output                         eth_data_rd_ren_o,
   output reg [BUFFER_W-1:0]      eth_data_rd_addr_o,
   input  [32-1:0]                eth_data_rd_rdata_i,
   input                          rx_data_rcvd_i,
   input                          crc_err_i,
   input  [11-1:0]                rx_nbytes_i,
   output reg                     rcv_ack_o,

   // AXI master interface
   `include "axi_m_port.vs"

   // Interrupts
   output reg tx_irq_o,
   output reg rx_irq_o,

   // No-DMA interface
   output reg tx_bd_cnt_o,
   output reg tx_word_cnt_o,
   input tx_frame_word_wen_i,
   input [32-1:0] tx_frame_word_wdata_o,
   output reg rx_bd_cnt_o,
   output reg rx_word_cnt_o,
   input rx_frame_word_ren_i,
   output reg [32-1:0] rx_frame_word_rdata_o,

   input clk_i,
   input cke_i,
   input arst_i
);

   localparam AXI_MAX_BURST_LEN = 16;

   // ############# Transmitter #############

   reg rx_req;
   reg tx_req;
   wire [1:0] bd_mem_arbiter_req = {rx_req, tx_req};
   wire [1:0] bd_mem_arbiter_ack;
   wire [1:0] bd_mem_arbiter_grant;
   wire bd_mem_arbiter_grant_valid;
   wire [$clog2(2)-1:0] bd_mem_arbiter_grant_encoded;
   arbiter #(
      .PORTS(2),
      // arbitration type: "PRIORITY" or "ROUND_ROBIN"
      .TYPE("ROUND_ROBIN"),
      // block type: "NONE", "REQUEST", "ACKNOWLEDGE"
      .BLOCK("NONE"),
      // LSB priority: "LOW", "HIGH"
      .LSB_PRIORITY("LOW")
   ) bd_mem_arbiter (
      .clk(clk_i),
      .rst(arst_i),

      .request(bd_mem_arbiter_req),
      .acknowledge(bd_mem_arbiter_ack),

      .grant(bd_mem_arbiter_grant),
      .grant_valid(bd_mem_arbiter_grant_valid),
      .grant_encoded(bd_mem_arbiter_grant_encoded)
   );


   reg [BD_ADDR_W-1:0] tx_bd_addr_o;
   reg [BD_ADDR_W-1:0] rx_bd_addr_o;
   reg                 tx_bd_wen_o;
   reg                 rx_bd_wen_o;
   reg [32-1:0]        tx_bd_o;
   reg [32-1:0]        rx_bd_o;
   reg [32-1:0]        tx_buffer_descriptor;
   reg [32-1:0]        rx_buffer_descriptor;
   reg [32-1:0]        tx_buffer_ptr;
   reg [32-1:0]        rx_buffer_ptr;

   reg [    AXI_ADDR_W-1:0] axi_araddr_o_reg;
   reg [     AXI_LEN_W-1:0] axi_arlen_o_reg;
   reg                      axi_arvalid_o_reg;
   reg                      axi_rready_o_reg;
   assign axi_araddr_o = axi_araddr_o_reg;
   assign axi_arlen_o = axi_arlen_o_reg;
   assign axi_arvalid_o = axi_arvalid_o_reg;
   assign axi_rready_o = axi_rready_o_reg;

   reg [    AXI_ADDR_W-1:0] axi_awaddr_o_reg;
   reg [     AXI_LEN_W-1:0] axi_awlen_o_reg;
   reg                      axi_awvalid_o_reg;
   reg                      axi_wvalid_o_reg;
   reg [    AXI_DATA_W-1:0] axi_wdata_o_reg;
   reg                      axi_wlast_o_reg;
   assign axi_awaddr_o = axi_awaddr_o_reg;
   assign axi_awlen_o = axi_awlen_o_reg;
   assign axi_awvalid_o = axi_awvalid_o_reg;
   assign axi_wvalid_o = axi_wvalid_o_reg;
   assign axi_wdata_o = axi_wdata_o_reg;
   assign axi_wlast_o = axi_wlast_o_reg;


   // Connect BD memory bus based on arbiter selection
   assign bd_addr_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_addr_o : rx_bd_addr_o;
   assign bd_wen_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_wen_o : rx_bd_wen_o;
   assign bd_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_o : rx_bd_o;

   assign bd_en_o = 1'b1;
   assign eth_data_rd_ren_o = 1'b1;

   //tx program
   reg [3-1:0] tx_state_nxt;
   wire [3-1:0] tx_state;
   iob_reg #(
      .DATA_W (3),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) tx_state_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_state_nxt),
      .data_o(tx_state)
   );

   reg [32-1:0] tx_buffer_word_counter_nxt;
   wire [32-1:0] tx_buffer_word_counter;
   iob_reg #(
      .DATA_W (32),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) tx_buffer_word_counter_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_buffer_word_counter_nxt),
      .data_o(tx_buffer_word_counter)
   );

   reg [BD_ADDR_W-1:0] tx_bd_num_nxt;
   wire [BD_ADDR_W-1:0] tx_bd_num;
   iob_reg #(
      .DATA_W (BD_ADDR_W),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) tx_bd_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(tx_bd_num_nxt),
      .data_o(tx_bd_num)
   );

   always @* begin
      tx_req = 1'b0;

      if (arst_i) begin

         tx_state_nxt   = 1'b0;
         tx_bd_num_nxt  = 1'b0;
         tx_bd_addr_o   = 1'b0;
         tx_bd_wen_o    = 1'b0;
         tx_bd_o        = 1'b0;
         send_o = 1'b0;
         axi_arvalid_o_reg = 1'b0;
         axi_rready_o_reg = 1'b0;
         eth_data_wr_wen_o = 1'b0;
         tx_irq_o = 1'b0;
         // No-DMA interface
         tx_bd_cnt_o = 1'b0;
         tx_word_cnt_o = 1'b0;

      end else if (tx_en_i) begin

         tx_state_nxt = tx_state + 1'b1;

         case (tx_state)

            0: begin  // Request buffer descriptor
               tx_bd_addr_o = tx_bd_num<<1;
               tx_req = 1'b1;
               send_o = 1'b0;
               tx_irq_o = 1'b0;
               tx_bd_wen_o = 1'b0;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[0] || !bd_mem_arbiter_grant_valid)
                  tx_state_nxt = tx_state;
            end

            1: begin  // Read buffer descriptor.
               tx_buffer_descriptor = bd_i;

               // Wait for ready bit
               if (!tx_buffer_descriptor[15])
                  tx_state_nxt = tx_state - 1'b1;
            end

            2: begin //Request buffer pointer
               tx_bd_addr_o = (tx_bd_num<<1) + 1;
               tx_req = 1'b1;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[0] || !bd_mem_arbiter_grant_valid)
                  tx_state_nxt = tx_state;
            end

            3: begin  // Read buffer pointer
               tx_buffer_ptr = bd_i;
               tx_buffer_word_counter_nxt = 0;

               // Wait for buffer ready for next frame
               if (!tx_ready_i)
                  tx_state_nxt = tx_state - 1'b1;
            end

            4: begin  // Start frame transfer from external memory
               // TODO: Instead of having fixed words of 4 bytes (shifting
               // 2 bits), we should use the AXI_DATA_W to calculate the
               // correct shift.
               axi_araddr_o_reg = tx_buffer_ptr + (tx_buffer_word_counter<<2);
               // FIXME: 'tx_buffer_descriptor[31:(16+2)]' may not be correct
               // if the frame size is not a multiple of 4 bytes
               axi_arlen_o_reg = `IOB_MIN(AXI_MAX_BURST_LEN,tx_buffer_descriptor[31:(16+2)]-tx_buffer_word_counter) - 1'b1;
               axi_arvalid_o_reg = 1'b1;
               axi_rready_o_reg = 1'b0;
               eth_data_wr_wen_o = 1'b0;

               // Wait for address ready
               if (!axi_arready_i)
                  tx_state_nxt = tx_state;

               // Check if frame transfer is complete
               if (tx_buffer_descriptor[31:(16+2)]-tx_buffer_word_counter == 0) begin
                  axi_arvalid_o_reg = 1'b0;

                  // Configure transmitter settings
                  crc_en_o = tx_buffer_descriptor[11];
                  //tx_nbytes_o = tx_buffer_descriptor[31:16];
                  tx_nbytes_o = tx_buffer_descriptor[26:16]; // 11 bits is enough for frame size
                  send_o = 1'b1;

                  // Disable ready bit
                  tx_buffer_descriptor[15] = 1'b0;

                  // Write transmit status
                  tx_state_nxt = 6;
               end

               // No-DMA interface
               tx_bd_cnt_o = tx_bd_num;
               tx_word_cnt_o = tx_buffer_word_counter;
               if (tx_frame_word_wen_i) begin
                  tx_buffer_word_counter_nxt = tx_buffer_word_counter + 1'b1;
                  // Send word from CPU to buffer
                  eth_data_wr_wen_o = 1'b1;
                  eth_data_wr_wstrb_o = 4'hf;
                  eth_data_wr_addr_o = tx_buffer_word_counter;
                  eth_data_wr_wdata_o = tx_frame_word_wdata_o;
               end

            end

            5: begin // Transfer frame word from memory to buffer
               tx_state_nxt = tx_state;
               axi_rready_o_reg = 1'b0;
               axi_arvalid_o_reg = 1'b0;

               if (axi_rvalid_i==1) begin
                  tx_buffer_word_counter_nxt = tx_buffer_word_counter + 1'b1;
                  axi_rready_o_reg = 1'b1;
                  // Send word to buffer
                  eth_data_wr_wen_o = 1'b1;
                  eth_data_wr_wstrb_o = 4'hf;
                  eth_data_wr_addr_o = tx_buffer_word_counter;
                  eth_data_wr_wdata_o = axi_rdata_i;

                  if (axi_rlast_i==1)
                     tx_state_nxt = tx_state - 1'b1;
               end

            end

            6: begin // Write transmit status
               tx_state_nxt = tx_state;

               tx_bd_addr_o = tx_bd_num<<1;
               tx_bd_wen_o = 1'b1;
               tx_bd_o = tx_buffer_descriptor;
               tx_req = 1'b1;

               // Wait for arbiter
               if (bd_mem_arbiter_grant[0] && bd_mem_arbiter_grant_valid) begin
                  // Generate interrupt
                  tx_irq_o = tx_buffer_descriptor[14];

                  // Select next BD address based on WR bit
                  if (tx_buffer_descriptor[13] == 0)
                     tx_bd_num_nxt = tx_bd_num + 1'b1;
                  else
                     tx_bd_num_nxt = 1'b0;

                  // Reset BD number if reached maximum
                  if (tx_bd_num_nxt >= tx_bd_num_i)
                     tx_bd_num_nxt = 1'b0;

                  // Go to next buffer descriptor
                  tx_state_nxt = 1'b0;
               end
            end

            default: ;

         endcase

      end
   end

   // AXI Master Read interface
   // Constants
   assign axi_arid_o    = 0;
   assign axi_arsize_o  = 2;
   assign axi_arburst_o = 1;
   assign axi_arlock_o  = 0;
   assign axi_arcache_o = 2;
   assign axi_arprot_o  = 2;
   assign axi_arqos_o   = 0;
   //axi_rid_i
   //axi_rresp_i

   // ############# Receiver #############

   //rx program
   reg [3-1:0] rx_state_nxt;
   wire [3-1:0] rx_state;
   iob_reg #(
      .DATA_W (3),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) rx_state_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_state_nxt),
      .data_o(rx_state)
   );

   reg [32-1:0] rx_buffer_word_counter_nxt;
   wire [32-1:0] rx_buffer_word_counter;
   iob_reg #(
      .DATA_W (32),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) rx_buffer_word_counter_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_buffer_word_counter_nxt),
      .data_o(rx_buffer_word_counter)
   );

   reg [BD_ADDR_W-1:0] rx_bd_num_nxt;
   wire [BD_ADDR_W-1:0] rx_bd_num;
   iob_reg #(
      .DATA_W (BD_ADDR_W),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) rx_bd_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_bd_num_nxt),
      .data_o(rx_bd_num)
   );

   reg [32-1:0] rx_burst_word_num_nxt;
   wire [32-1:0] rx_burst_word_num;
   iob_reg #(
      .DATA_W (32),
      .RST_VAL(0),
      .CLKEDGE("posedge")
   ) rx_burst_word_num_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rx_burst_word_num_nxt),
      .data_o(rx_burst_word_num)
   );

   always @* begin
      rx_req = 1'b0;

      if (arst_i) begin

         rx_state_nxt   = 1'b0;
         rx_bd_num_nxt  = tx_bd_num_i;
         rx_bd_addr_o   = 1'b0;
         rx_bd_wen_o    = 1'b0;
         rx_bd_o        = 1'b0;
         rcv_ack_o      = 1'b0;
         axi_awvalid_o_reg = 1'b0;
         axi_wlast_o_reg = 1'b0;
         rx_irq_o = 1'b0;
         // No-DMA interface
         rx_bd_cnt_o = 1'b0;
         rx_word_cnt_o = 1'b0;
         rx_frame_word_rdata_o = 1'b0;

      end else if (rx_en_i) begin

         rx_state_nxt = rx_state + 1'b1;

         case (rx_state)

            0: begin  // Request buffer descriptor
               rx_bd_addr_o = rx_bd_num<<1;
               rx_req = 1'b1;
               rcv_ack_o = 1'b0;
               rx_irq_o = 1'b0;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[1] || !bd_mem_arbiter_grant_valid)
                  rx_state_nxt = rx_state;

            end

            1: begin  // Read buffer descriptor.
               rx_buffer_descriptor = bd_i;

               // Wait for ready bit
               if (!rx_buffer_descriptor[15])
                  rx_state_nxt = rx_state - 1'b1;
            end

            2: begin //Request buffer pointer
               rx_bd_addr_o = (rx_bd_num<<1) + 1;
               rx_req = 1'b1;

               // Wait for arbiter
               if (!bd_mem_arbiter_grant[1] || !bd_mem_arbiter_grant_valid)
                  rx_state_nxt = rx_state;
            end

            3: begin  // Read buffer pointer
               rx_buffer_ptr = bd_i;
               rx_buffer_word_counter_nxt = 0;

               // Wait for buffer ready for next frame
               if (!rx_data_rcvd_i)
                  rx_state_nxt = rx_state - 1'b1;
            end

            4: begin  // Start frame transfer to external memory
               axi_awaddr_o_reg = rx_buffer_ptr + (rx_buffer_word_counter<<2);
               axi_awlen_o_reg = `IOB_MIN(AXI_MAX_BURST_LEN,(rx_nbytes_i>>2)-rx_buffer_word_counter) - 1'b1;
               axi_awvalid_o_reg = 1'b1;
               // Get word from buffer
               eth_data_rd_addr_o = rx_buffer_word_counter;
               rx_burst_word_num_nxt = 1'b0;

               // Wait for address ready
               if (!axi_awready_i)
                  rx_state_nxt = rx_state;

               // Check if frame transfer is complete
               if ((rx_nbytes_i>>2)-rx_buffer_word_counter == 0) begin
                  axi_awvalid_o_reg = 1'b0;

                  // Disable ready bit
                  rx_buffer_descriptor[15] = 1'b0;
                  // Write crc_err
                  rx_buffer_descriptor[1] = crc_err_i;
                  // Write buffer size
                  rx_buffer_descriptor[31:16] = rx_nbytes_i;

                  // Acknowledge read complete
                  rcv_ack_o = 1'b1;

                  // Write receive status
                  rx_state_nxt = 6;
               end

               // No-DMA interface
               rx_bd_cnt_o = rx_bd_num;
               rx_word_cnt_o = rx_buffer_word_counter;
               if (rx_frame_word_ren_i) begin
                  rx_buffer_word_counter_nxt = rx_buffer_word_counter + 1'b1;
                  eth_data_rd_addr_o = rx_buffer_word_counter + 1'b1; // Update next word addr
                  // Send word from buffer to CPU
                  rx_frame_word_rdata_o = eth_data_rd_rdata_i;
               end

            end

            5: begin // Transfer frame word from buffer to memory
               rx_state_nxt = rx_state;
               axi_awvalid_o_reg = 1'b0;
               axi_wvalid_o_reg = 1'b1;
               axi_wdata_o_reg = eth_data_rd_rdata_i;
               eth_data_rd_addr_o = rx_buffer_word_counter;

               // wait for write ready
               if (axi_wready_i==1) begin
                  rx_buffer_word_counter_nxt = rx_buffer_word_counter + 1'b1;
                  eth_data_rd_addr_o = rx_buffer_word_counter + 1'b1; // Update next word addr
                  rx_burst_word_num_nxt = rx_burst_word_num + 1'b1;
               end

               // Check if last word
               if (rx_buffer_descriptor[31:16]-rx_buffer_word_counter == 1) begin
                  axi_wlast_o_reg = 1'b1;
                  rx_state_nxt = rx_state - 1'b1;
               end

               // Tranfer next burst
               if (rx_burst_word_num == AXI_MAX_BURST_LEN-1)
                  rx_state_nxt = rx_state - 1'b1;

            end

            6: begin // Write receive status
               rx_state_nxt = rx_state;

               rx_bd_addr_o = rx_bd_num<<1;
               rx_bd_wen_o = 1'b1;
               rx_bd_o = rx_buffer_descriptor;
               rx_req = 1'b1;

               // Wait for arbiter
               if (bd_mem_arbiter_grant[1] && bd_mem_arbiter_grant_valid) begin
                  // Generate interrupt
                  rx_irq_o = rx_buffer_descriptor[14];

                  // Select next BD address based on WR bit
                  if (rx_buffer_descriptor[13] == 0)
                     rx_bd_num_nxt = rx_bd_num + 1'b1;
                  else
                     rx_bd_num_nxt = tx_bd_num_i;

                  // Reset BD number if reached maximum
                  if (rx_bd_num_nxt >= 1<<BD_ADDR_W)
                     rx_bd_num_nxt = tx_bd_num_i;


                  // Go to next buffer descriptor
                  rx_state_nxt = 1'b0;
               end
            end

            default: ;

         endcase

      end
   end

   // AXI Master Write interface
   // Constants
   assign axi_awid_o    = 0;
   assign axi_awsize_o  = 2;
   assign axi_awburst_o = 1;
   assign axi_awlock_o  = 0;
   assign axi_awcache_o = 2;
   assign axi_awprot_o  = 2;
   assign axi_awqos_o   = 0;
   assign axi_wstrb_o   = 4'b1111;
   assign axi_bready_o  = 1'b1;
   // axi_bid_i
   // axi_bresp_i,
   // axi_bvalid_i



endmodule
