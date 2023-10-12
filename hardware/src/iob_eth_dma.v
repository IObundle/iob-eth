`timescale 1ns / 1ps

`include "iob_eth.vh"
`include "iob_eth_swreg_def.vh"

module iob_eth_dma #(
   parameter AXI_ADDR_W = 0,
   parameter AXI_DATA_W = 32,          // We currently only support 4 byte transfers
   parameter AXI_LEN_W  = 8,
   parameter AXI_ID_W   = 1,
   //parameter BURST_W    = 0,
   //parameter BUFFER_W   = BURST_W + 1
   parameter BD_ADDR_W  = 8
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
   output                           eth_data_wr_wen_o,
   output [2-1:0]                   eth_data_wr_wstrb_o,
   output [`ETH_DATA_WR_ADDR_W-1:0] eth_data_wr_addr_o,
   output [32-1:0]                  eth_data_wr_wdata_o,

   // RX Back-End
   output                           eth_data_rd_ren_o,
   output [`ETH_DATA_WR_ADDR_W-1:0] eth_data_rd_addr_o,
   input  [32-1:0]                  eth_data_rd_rdata_i,

   // AXI master interface
   `include "axi_m_port.vs"

   // Interrupts
   output tx_irq_o,
   output rx_irq_o,

   input clk_i,
   input cke_i,
   input arst_i
);
   // ############# Transmitter #############

   wire [1:0] bd_mem_arbiter_req;
   wire [1:0] bd_mem_arbiter_ack;
   wire [1:0] bd_mem_arbiter_grant;
   wire [1:0] bd_mem_arbiter_grant_valid;
   wire [$clog2(PORTS)-1:0] bd_mem_arbiter_grant_encoded;
   module arbiter #(
      .PORTS(2),
      // arbitration type: "PRIORITY" or "ROUND_ROBIN"
      .TYPE("PRIORITY"),
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

   // Connect BD memory bus based on arbiter selection
   assign bd_addr_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_addr_o : rx_bd_addr_o;
   assign bd_wen_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_wen_o : rx_bd_wen_o;
   assign bd_o = bd_mem_arbiter_grant_encoded==0 ? tx_bd_o : rx_bd_o;

   assign bd_en_o = 1'b1;

   //tx program
   reg [1:0] tx_pc;
   reg [BD_ADDR_W-1:0] tx_bd_num;
   always @(posedge clk_i, posedge arst_i)

      if (arst_i) begin

         tx_pc       <= 1'b0;
         tx_bd_num   <= 1'b0;
         tx_bd_addr_o   <= 1'b0;
         tx_bd_wen_o    <= 1'b0;
         tx_bd_o        <= 1'b0;

      end else if (tx_en_i) begin

         tx_pc <= tx_pc + 1'b1;  // Increment pc by default

         case (tx_pc)

            0: begin  // Read buffer descriptor
               tx_bd_addr_o <= tx_bd_num<<1;
            end

            1: begin  // Read buffer pointer.
               buffer_descriptor <= bd_i;
               tx_bd_addr_o <= tx_bd_num<<1 + 1;

               // Wait for ready bit and
               // wait for arbiter and
               // wait for buffer ready for next frame
               if (bd_i[15]==0) ||
                  (bd_mem_arbiter_ack[0]==0 || bd_mem_arbiter_grant[0]==0 || bd_mem_arbiter_grant_valid==0)
                  // TODO: Check buffer ready for next frame
                  tx_bd_addr_o <= tx_bd_num<<1;
                  tx_pc <= tx_pc;
            end

            2: begin  // Store buffer pointer
               buffer_ptr <= bd_i;
               buffer_word_counter <= 0;
            end

            3: begin  // Start frame transfer from external memory
               axi_araddr_o <= buffer_ptr + buffer_word_counter;
               axi_arlen_o <= `IOB_MIN(16,buffer_descriptor[31:16]-buffer_word_counter);
               axi_arvalid_o <= 1'b1;
               // Wait for address ready
               if (axi_arready_i==0)
                  tx_pc <= tx_pc;

               // Check if frame transfer is complete
               if (buffer_descriptor[31:16]-buffer_word_counter == 0)
                  axi_arvalid_o <= 1'b0;

                  // Reset buffer word counter and go to next buffer descriptor
                  buffer_word_counter <= 1'b0;
                  tx_pc <= 1'b0;

                  // Write transmit status
                  // - Disable ready bit

                  // Generate interrupt
                  assign tx_irq_o = 1'b1;

                  // Select BD address based on WR bit
                  if (buffer_descriptor[13] == 0)
                     tx_bd_num <= tx_bd_num + 1'b1;
                  else
                     tx_bd_num <= 1'b0
            end

            4: begin // receive frame word
               tx_pc <= tx_pc;

               if (axi_rvalid_i==1)
                  buffer_word_counter <= buffer_word_counter + 1'b1;
                  axi_rready_o <= 1'b1;
                  // Send word to buffer
                  eth_data_wr_wen_o <= 1'b1;
                  eth_data_wr_wstrb_o <= 4'hf;
                  eth_data_wr_addr_o <= buffer_word_counter;
                  eth_data_wr_wdata_o <= axi_rdata_i;

                  if (axi_rlast_i==1)
                     tx_pc <= 3;

            end

            default: ;

         endcase

      end else begin

         tx_pc       <= 1'b0;
         tx_bd_addr_o   <= BD_ADDR_W'h0;
         tx_bd_wen_o    <= 1'b0;
         tx_bd_o        <= 1'b0;

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

   //TODO

   // ############# Receiver #############

   //rx program
   reg [1:0] rx_pc;
   reg [BD_ADDR_W-1:0] rx_bd_num;
   always @(posedge clk_i, posedge arst_i)

      if (arst_i) begin

         rx_pc       <= 1'b0;
         rx_bd_num   <= 1'b0;
         rx_bd_addr_o   <= 1'b0;
         rx_bd_wen_o    <= 1'b0;
         rx_bd_o        <= 1'b0;

      end else if (rx_en_i) begin

         rx_pc <= rx_pc + 1'b1;  // Increment pc by default

         case (rx_pc)

            0: begin  // Read buffer descriptor
               rx_bd_addr_o <= rx_bd_num<<1;
            end

            1: begin  // Read buffer pointer.
               buffer_descriptor <= bd_i;
               rx_bd_addr_o <= rx_bd_num<<1 + 1;

               // Wait for ready bit and
               // wait for arbiter
               if (bd_i[15]==0) ||
                  (bd_mem_arbiter_ack[1]==0 || bd_mem_arbiter_grant[1]==0 || bd_mem_arbiter_grant_valid==0)
                  rx_bd_addr_o <= rx_bd_num<<1;
                  rx_pc <= rx_pc;
            end

            2: begin  // Store buffer pointer; Write frame to external memeory.
               buffer_ptr <= bd_i;
               buffer_word_counter <= 1;

               //TODO: Write frame word to extmem; Get word from buffer
               axi_addr <= bd_i;
            end

            3: begin  // Write next word to buffer;
               rx_pc <= rx_pc;
               buffer_word_counter <= buffer_word_counter + 1'b1;

               //TODO: Write frame word to extmem; Send word to buffer
               axi_addr <= buffer_ptr + buffer_word_counter;

               // Finished transmission
               if (buffer_word_counter == buffer_descriptor[31:16]) begin
                  // Reset buffer word counter and go to next buffer descriptor
                  buffer_word_counter <= 1'b0;
                  rx_pc <= 1'b0;

                  // Write receive status
                  // - Disable empty bit

                  // Generate interrupt

                  // Select BD address based on WR bit
                  if (buffer_descriptor[13] == 0)
                     rx_bd_num <= rx_bd_num + 1'b1;
                  else
                     rx_bd_num <= 1'b0

               end
            end

            default: ;

         endcase

      end else begin

         tx_pc       <= 1'b0;
         rx_bd_addr_o   <= BD_ADDR_W'h0;
         rx_bd_wen_o    <= 1'b0;
         rx_bd_o        <= 1'b0;

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



endmodule
