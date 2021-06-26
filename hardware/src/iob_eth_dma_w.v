`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma_w #(
		    parameter DMA_DATA_W = 32,
		    // AXI4 interface parameters
		    parameter AXI_ADDR_W = 32,
		    parameter AXI_DATA_W = DMA_DATA_W
		    ) (
		       // system inputs
		       input 		       clk,
		       input 		       rst,

		       //AXI4 Master i/f
           // Master Interface Write Address
           output [`AXI_ID_W-1:0]        m_axi_awid,
           output reg [AXI_ADDR_W-1:0]   m_axi_awaddr,
           output reg [`AXI_LEN_W-1:0]   m_axi_awlen,
           output [`AXI_SIZE_W-1:0]      m_axi_awsize,
           output [`AXI_BURST_W-1:0]     m_axi_awburst,
           output [`AXI_LOCK_W-1:0]      m_axi_awlock,
           output [`AXI_CACHE_W-1:0]     m_axi_awcache,
           output [`AXI_PROT_W-1:0]      m_axi_awprot,
           output [`AXI_QOS_W-1:0]       m_axi_awqos,
           output reg                    m_axi_awvalid,
           input                         m_axi_awready,

           // Master Interface Write Data
           output reg [DMA_DATA_W-1:0]   m_axi_wdata,
           output reg [DMA_DATA_W/8-1:0] m_axi_wstrb,
           output reg                    m_axi_wlast,
           output reg                    m_axi_wvalid,
           input                         m_axi_wready,

           // Master Interface Write Response
           //input [`AXI_ID_W-1:0]         m_axi_bid,
           input [`AXI_RESP_W-1:0]       m_axi_bresp,
           input                         m_axi_bvalid,
           output reg                    m_axi_bready,

		     // DMA Configurations
		     input[AXI_ADDR_W-1:0] dma_addr,
		     input 		            dma_run,
		     output reg            dma_ready,
           input [10:0]          dma_start_index,
           input [10:0]          dma_end_index,

		     input [31:0]          out_data,
		     output reg[8:0]       out_addr
		     );

   reg [31:0] address;

   // One byte at a time, for now
   assign m_axi_awid = `AXI_ID_W'b0;
   assign m_axi_awsize = 3'h2;
   assign m_axi_awburst = 2'b01;
   assign m_axi_awlock = 1'b0;
   assign m_axi_awcache = 4'h2;
   assign m_axi_awprot = `AXI_PROT_W'b010;
   assign m_axi_awqos = `AXI_QOS_W'h0;
   
   wire [3:0] ram_wstrb_start = dma_addr[1] ? (dma_addr[0] ? 4'b1000 : 4'b1100):
                                              (dma_addr[0] ? 4'b1110 : 4'b1111);

   wire [3:0] in_wstrb_start = dma_start_index[1] ? (dma_start_index[0] ? 4'b1000 : 4'b1100):
                                                    (dma_start_index[0] ? 4'b1110 : 4'b1111);

   wire axi_transfer = (m_axi_wvalid & m_axi_wready);
   wire last_in = (out_addr == (dma_end_index[10:2] + (dma_end_index[1:0] > dma_start_index[1:0] ? 10'h1 : 10'h0)));

   wire buffer_last;
   reg burst_align_valid; // Quick starts the transfer

   wire [31:0] aligned_data;
   wire aligned_valid;

   reg [7:0] state;

   wire doDelay = (state >= 8'h4 & !axi_transfer); // Always delay if a transfer has not happened

   // Aligns data coming from the buffer
   eth_burst_align burst_align(
        .data(out_data),
        .strobe(in_wstrb_start),
        .valid(burst_align_valid), // After starting, m_axi_transfer controls the remaining 
        .last(last_in),

        .data_out(aligned_data),
        .data_valid(aligned_valid),
        .strobe_out(),
        .last_out(buffer_last),

        .delay(doDelay),

        .clk(clk),
        .rst(rst)
    );

   wire [31:0] misaligned_data;
   wire [3:0] misaligned_strobe;
   wire misaligned_valid;
   wire misaligned_last;

   // Misalign data to write to RAM
   eth_burst_split burst_split(
        .data(aligned_data),
        .valid(aligned_valid),
        .strobe(ram_wstrb_start),
        .last(buffer_last),

        .data_out(misaligned_data),
        .data_valid(misaligned_valid),
        .strobe_out(misaligned_strobe),
        .last_out(misaligned_last),

        .delay(doDelay),

        .clk(clk),
        .rst(rst)
    );

   reg [10:0] transfers;

   always @(posedge clk, posedge rst)
   begin
      if(rst)
      begin
         m_axi_awaddr <= 0;
         m_axi_awlen <= 0;
         m_axi_awvalid <= 0;
         m_axi_wvalid <= 0;
         m_axi_wlast <= 0;
         m_axi_wstrb <= 0;
         m_axi_bready <= 0;
         m_axi_wdata <= 0;
         burst_align_valid <= 0;
         state <= 0;
         transfers <= 0;
         out_addr <= 0;
         dma_ready <= 1'b1;
      end else begin

      if(axi_transfer) begin
         transfers <= transfers + 1;
      end

      if(last_in) begin
         burst_align_valid <= 1'b0;
      end

      case(state)
         8'h0: begin
            if(dma_run)
            begin
               state <= 5'h1;
               out_addr <= dma_start_index[10:2];
               dma_ready <= 1'b0;
               transfers <= 0;
               m_axi_awvalid <= 1'b1;
               m_axi_awaddr <= {dma_addr[AXI_ADDR_W-1:2],2'b00};
               m_axi_awlen <= dma_end_index[10:2] - dma_start_index[10:2] + (dma_end_index[1:0] > dma_start_index[1:0] ? 10'h1 : 10'h0);
            end
         end
        8'h1: begin // Wait for first valid data
           if(m_axi_awready) begin
               m_axi_awvalid <= 1'b0;

               state <= 8'h2;
               out_addr <= out_addr + 1;
               burst_align_valid <= 1'b1;
           end
        end
        8'h2: begin
           out_addr <= out_addr + 8'h1;
           if(misaligned_valid) begin
               state <= 8'h4;
               m_axi_wvalid <= 1'b1;
               m_axi_wdata <= misaligned_data;
               m_axi_wstrb <= misaligned_strobe;
           end
        end
        8'h4: begin // Perform burst transfer
           if(axi_transfer) begin
               m_axi_wdata <= misaligned_data;
               m_axi_wstrb <= misaligned_strobe;
               if(burst_align_valid & !last_in)
                  out_addr <= out_addr + 1;
               if(transfers + 1 == m_axi_awlen) begin
                  m_axi_wlast <= 1'b1;
                  state <= 8'h8;
               end
           end
        end
        8'h8: begin
         if(axi_transfer) begin
            state <= 8'h10;
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b1;
         end
        end
        8'h10: begin
           if(m_axi_bvalid) begin
              m_axi_bready <= 1'b0;
              dma_ready <= 1'b1;
              state <= 8'h0;
           end
        end
        default:;
      endcase
      end
   end

endmodule
