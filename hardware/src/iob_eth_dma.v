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

   input clk_i,
   input cke_i,
   input arst_i
);
   // ############# Transmitter #############

   //tx program
   reg [1:0] tx_pc;
   reg [BD_ADDR_W-1:0] tx_bd_num;
   always @(posedge clk_i, posedge arst_i)

      if (arst_i) begin

         tx_pc       <= 1'b0;
         tx_bd_num   <= 1'b0;
         bd_en_o     <= 1'b1;
         bd_addr_o   <= 1'b0;
         bd_wen_o    <= 1'b0;
         bd_o        <= 1'b0;

      end else if (tx_en_i) begin

         tx_pc <= tx_pc + 1'b1;  // Increment pc by default

         case (tx_pc)

            0: begin  // Read buffer descriptor
               bd_addr_o <= tx_bd_num<<1;
            end

            1: begin  // Read buffer pointer.
               buffer_descriptor <= bd_i;
               bd_addr_o <= tx_bd_num<<1 + 1;

               // Wait for ready bit
               if (bd_i[15]==0)
                  bd_addr_o <= tx_bd_num<<1;
                  tx_pc <= tx_pc;
            end

            2: begin  // Store buffer pointer; Read frame from external memeory.
               buffer_ptr <= bd_i;
               buffer_word_counter <= 1;

               //TODO: Read frame word from extmem; Send word to FIFO
               axi_addr <= bd_i;
            end

            3: begin  // Read next word from buffer;
               tx_pc <= tx_pc;
               buffer_word_counter <= buffer_word_counter + 1'b1;

               //TODO: Read frame word from extmem; Send word to FIFO
               axi_addr <= buffer_ptr + buffer_word_counter;

               // Finished transmission
               if (buffer_word_counter == buffer_descriptor[31:16]) begin
                  // Reset buffer word counter and go to next buffer descriptor
                  buffer_word_counter <= 1'b0;
                  tx_pc <= 1'b0;

                  // Write transmit status
                  // - Disable ready bit

                  // Generate interrupt

                  // Select BD address based on WR bit
                  if (buffer_descriptor[13] == 0)
                     tx_bd_num <= tx_bd_num + 1'b1;
                  else
                     tx_bd_num <= 1'b0

               end
            end

            default: ;

         endcase

      end else begin

         tx_pc       <= 1'b0;
         bd_en_o     <= 1'b1;
         bd_addr_o   <= BD_ADDR_W'h0;
         bd_wen_o    <= 1'b0;
         bd_o        <= 1'b0;

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

   //TODO

   // ############# Receiver #############

   //rx program
   reg [1:0] rx_pc;
   reg [BD_ADDR_W-1:0] rx_bd_num;
   always @(posedge clk_i, posedge arst_i)

      if (arst_i) begin

         rx_pc       <= 1'b0;
         rx_bd_num   <= 1'b0;
         bd_en_o     <= 1'b1;
         bd_addr_o   <= 1'b0;
         bd_wen_o    <= 1'b0;
         bd_o        <= 1'b0;

      end else if (rx_en_i) begin

         rx_pc <= rx_pc + 1'b1;  // Increment pc by default

         case (rx_pc)

            0: begin  // Read buffer descriptor
               bd_addr_o <= rx_bd_num<<1;
            end

            1: begin  // Read buffer pointer.
               buffer_descriptor <= bd_i;
               bd_addr_o <= rx_bd_num<<1 + 1;

               // Wait for empty bit
               if (bd_i[15]==0)
                  bd_addr_o <= rx_bd_num<<1;
                  rx_pc <= rx_pc;
            end

            2: begin  // Store buffer pointer; Write frame to external memeory.
               buffer_ptr <= bd_i;
               buffer_word_counter <= 1;

               //TODO: Write frame word to extmem; Get word from FIFO
               axi_addr <= bd_i;
            end

            3: begin  // Write next word to buffer;
               rx_pc <= rx_pc;
               buffer_word_counter <= buffer_word_counter + 1'b1;

               //TODO: Write frame word to extmem; Send word to FIFO
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
         bd_en_o     <= 1'b1;
         bd_addr_o   <= BD_ADDR_W'h0;
         bd_wen_o    <= 1'b0;
         bd_o        <= 1'b0;

      end

   // AXI Master Read interface



endmodule
