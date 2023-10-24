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
   output reg                     eth_data_rd_ren_o,
   output reg [BUFFER_W-1:0]      eth_data_rd_addr_o,
   input  [32-1:0]                eth_data_rd_rdata_i,
   input                          crc_err_i,
   input                          rx_data_rcvd_i,

   // AXI master interface
   `include "axi_m_port.vs"

   // Interrupts
   output reg tx_irq_o,
   output reg rx_irq_o,

   input clk_i,
   input cke_i,
   input arst_i
);
   // ############# Transmitter #############

   wire [1:0] bd_mem_arbiter_req;
   wire [1:0] bd_mem_arbiter_ack;
   wire [1:0] bd_mem_arbiter_grant;
   wire bd_mem_arbiter_grant_valid;
   wire [$clog2(2)-1:0] bd_mem_arbiter_grant_encoded;
   arbiter #(
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


   reg [BD_ADDR_W-1:0] tx_bd_addr_o;
   reg [BD_ADDR_W-1:0] rx_bd_addr_o;
   reg                 tx_bd_wen_o;
   reg                 rx_bd_wen_o;
   reg [32-1:0]        tx_bd_o;
   reg [32-1:0]        rx_bd_o;
   reg [32-1:0]        buffer_descriptor;
   reg [32-1:0]        buffer_ptr;
   reg [32-1:0]        buffer_word_counter;

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
               if ((bd_i[15]==0) ||
                  (bd_mem_arbiter_ack[0]==0 || bd_mem_arbiter_grant[0]==0 || bd_mem_arbiter_grant_valid==0) ||
                  (!tx_ready_i)) begin
                  tx_bd_addr_o <= tx_bd_num<<1;
                  tx_pc <= tx_pc;
               end
            end

            2: begin  // Store buffer pointer
               buffer_ptr <= bd_i;
               buffer_word_counter <= 0;
            end

            3: begin  // Start frame transfer from external memory
               axi_araddr_o_reg <= buffer_ptr + buffer_word_counter;
               axi_arlen_o_reg <= `IOB_MIN(16,buffer_descriptor[31:16]-buffer_word_counter);
               axi_arvalid_o_reg <= 1'b1;
               // Wait for address ready
               if (axi_arready_i==0)
                  tx_pc <= tx_pc;

               // Check if frame transfer is complete
               if (buffer_descriptor[31:16]-buffer_word_counter == 0) begin
                  axi_arvalid_o_reg <= 1'b0;

                  // Reset buffer word counter and go to next buffer descriptor
                  buffer_word_counter <= 1'b0;
                  tx_pc <= 1'b0;

                  crc_en_o <= buffer_descriptor[11];
                  //tx_nbytes_o <= buffer_descriptor[31:16];
                  tx_nbytes_o <= buffer_descriptor[26:16];
                  send_o <= 1'b1;

                  // Write transmit status
                  // - Disable ready bit

                  // Generate interrupt
                  tx_irq_o <= buffer_descriptor[14];

                  // Select BD address based on WR bit
                  if (buffer_descriptor[13] == 0)
                     tx_bd_num <= tx_bd_num + 1'b1;
                  else
                     tx_bd_num <= 1'b0;
               end
            end

            4: begin // receive frame word
               tx_pc <= tx_pc;

               if (axi_rvalid_i==1) begin
                  buffer_word_counter <= buffer_word_counter + 1'b1;
                  axi_rready_o_reg <= 1'b1;
                  // Send word to buffer
                  eth_data_wr_wen_o <= 1'b1;
                  eth_data_wr_wstrb_o <= 4'hf;
                  eth_data_wr_addr_o <= buffer_word_counter;
                  eth_data_wr_wdata_o <= axi_rdata_i;

                  if (axi_rlast_i==1)
                     tx_pc <= 3;
               end

            end

            default: ;

         endcase

      end else begin

         tx_pc       <= 1'b0;
         tx_bd_addr_o   <= 1'b0;
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

               // Wait for empty bit and
               // wait for arbiter
               // wait for received data
               if ((bd_i[15]==0) ||
                  (bd_mem_arbiter_ack[1]==0 || bd_mem_arbiter_grant[1]==0 || bd_mem_arbiter_grant_valid==0) ||
                  (!rx_data_rcvd_i)) begin
                  rx_bd_addr_o <= rx_bd_num<<1;
                  rx_pc <= rx_pc;
               end
            end

            2: begin  // Store buffer pointer; Write frame to external memeory.
               buffer_ptr <= bd_i;
               buffer_word_counter <= 0;
            end
            
            3: begin  // Start frame transfer to external memory
               axi_awaddr_o_reg <= buffer_ptr + buffer_word_counter;
               axi_awlen_o_reg <= `IOB_MIN(16,buffer_descriptor[31:16]-buffer_word_counter);
               axi_awvalid_o_reg <= 1'b1;
               // Wait for address ready
               if (axi_awready_i==0)
                  rx_pc <= rx_pc;

               // Check if frame transfer is complete
               if (buffer_descriptor[31:16]-buffer_word_counter == 0) begin
                  axi_awvalid_o_reg <= 1'b0;

                  // Reset buffer word counter and go to next buffer descriptor
                  buffer_word_counter <= 1'b0;
                  rx_pc <= 1'b0;

                  // Write receive status
                  // - Disable ready bit
                  // - Write crc_err

                  // Generate interrupt
                  rx_irq_o <= buffer_descriptor[14];

                  // Select BD address based on WR bit
                  if (buffer_descriptor[13] == 0)
                     rx_bd_num <= rx_bd_num + 1'b1;
                  else
                     rx_bd_num <= 1'b0;
               end

               // Get word from buffer
               eth_data_rd_ren_o <= 1'b1;
               eth_data_rd_addr_o <= buffer_word_counter;

            end

            4: begin // receive frame word
               rx_pc <= rx_pc;
               axi_wvalid_o_reg <= 1'b0;

               // wait for write ready
               // wait for arbiter
               if ((axi_wready_i==1) &&
                  (bd_mem_arbiter_ack[1]==1 && bd_mem_arbiter_grant[1]==1 && bd_mem_arbiter_grant_valid==1)) begin
                  buffer_word_counter <= buffer_word_counter + 1'b1;
                  axi_wdata_o_reg <= eth_data_rd_rdata_i;
                  axi_wvalid_o_reg <= 1'b1;

                  if (buffer_descriptor[31:16]-buffer_word_counter+1 == 0) begin
                     axi_wlast_o_reg <= 1'b1;
                     rx_pc <= 3;
                  end
               end

            end

            default: ;

         endcase

      end else begin

         tx_pc       <= 1'b0;
         rx_bd_addr_o   <= 1'b0;
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
   // axi_bid_i
   // axi_bresp_i,
   // axi_bvalid_i



endmodule
