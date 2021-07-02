`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma_r #(
          parameter DMA_DATA_W = 32,
          // AXI4 interface parameters
          parameter AXI_ADDR_W = 32,
          parameter AXI_DATA_W = DMA_DATA_W
          ) (
             // system inputs
             input             clk,
             input             rst,

             //AXI4 Master i/f
           //address read
           output [`AXI_ID_W-1:0]    m_axi_arid,
           output reg [AXI_ADDR_W-1:0] m_axi_araddr,
           output reg [`AXI_LEN_W-1:0] m_axi_arlen,
           output [`AXI_SIZE_W-1:0]  m_axi_arsize,
           output [`AXI_BURST_W-1:0] m_axi_arburst,
           output [`AXI_LOCK_W-1:0]  m_axi_arlock,
           output [`AXI_CACHE_W-1:0] m_axi_arcache,
           output [`AXI_PROT_W-1:0]  m_axi_arprot,
           output [`AXI_QOS_W-1:0]   m_axi_arqos,
           output reg                m_axi_arvalid,
           input                     m_axi_arready,

           //read
           input [`AXI_ID_W-1:0] m_axi_rid,
           input [AXI_DATA_W-1:0] m_axi_rdata,
           input [`AXI_RESP_W-1:0] m_axi_rresp,
           input  m_axi_rlast,
           input  m_axi_rvalid,
           output reg m_axi_rready,

             // DMA Configurations
             input[AXI_ADDR_W-1:0] dma_addr,
             input                   dma_run,
             output reg            dma_ready,
           input [9:0]           dma_len,

             output wire[31:0]     in_data,
             output reg[8:0]       in_addr,
           output reg            in_wr
             );

   assign m_axi_arid = 0;   // id is zero
   assign m_axi_arsize = 3'h2; // 4 bytes at a time 
   assign m_axi_arburst = 2'b01; // incr bursting
   assign m_axi_arlock = 0; // do not lock
   assign m_axi_arcache = 4'h2; 
   assign m_axi_arprot = `AXI_PROT_W'b010;
   assign m_axi_arqos = `AXI_QOS_W'h0;

   wire [31:0] aligned_data;
   wire aligned_valid;

   wire axi_transfer = (m_axi_rvalid & m_axi_rready);

   wire [7:0] axi_len;
   wire first_transfer_valid;
   reg remaining_data;

   // Aligns data coming from the RAM
   eth_burst_align burst_align(
        .data(m_axi_rdata),
        .transfer(axi_transfer),
        .offset(dma_addr[1:0]),
        .len(dma_len),
        .remaining_data(remaining_data),

        .data_out(in_data),
        .axi_len(axi_len),

        .first_transfer_valid(first_transfer_valid),

        .clk(clk),
        .rst(rst)
    );

   reg [3:0] state;
   reg did_first_transfer;

   wire next_cycle_valid = (first_transfer_valid || did_first_transfer);

   always @(posedge clk, posedge rst)
   begin
      if(rst)
      begin
         m_axi_araddr <= 0;
         m_axi_arlen <= 0;
         m_axi_arvalid <= 0;
         m_axi_rready <= 0;
         in_addr <= 0;
         state <= 0;
         in_wr <= 0;
         remaining_data <= 0;
         did_first_transfer <= 0;
         dma_ready <= 1'b1;
      end else begin
         if(axi_transfer && next_cycle_valid) begin
            in_addr <= in_addr + 32'h1;
         end

         if(next_cycle_valid)
            in_wr <= axi_transfer;

         case(state)
           4'h0: begin
             if(dma_run)
             begin
              dma_ready <= 1'b0;
              state <= 4'h1;
              did_first_transfer <= 0;
              m_axi_arvalid <= 1'b1;
              m_axi_araddr <= {dma_addr[AXI_ADDR_W-1:2],2'b00};
              m_axi_arlen <= axi_len;
              in_addr <= (`DMA_R_START-1); // Start one earlier since in_addr is always one value ahead (this makes the code simpler and saves either a register or a subtraction)
             end
           end
           4'h1: begin
             if(m_axi_arready) begin
              m_axi_arvalid <= 1'b0;
              m_axi_rready <= 1'b1;
              state <= 4'h2;
             end
           end
           4'h2: begin
             if(axi_transfer) begin
                 did_first_transfer <= 1'b1;
             end

             if(axi_transfer & m_axi_rlast) begin
              m_axi_rready <= 1'b0;
              state <= 4'h4;
              remaining_data <= 1'b1;
             end
           end
           4'h4: begin
              in_addr <= in_addr + 32'h1;
              in_wr <= 1'b1;
              remaining_data <= 1'b0;
              state <= 4'h8;
           end
           4'h8: begin
              in_wr <= 1'b0;
              dma_ready <= 1'b1;
              state <= 4'h0;
           end
          default:;
         endcase
      end
   end

endmodule
