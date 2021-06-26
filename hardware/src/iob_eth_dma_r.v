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
		       input 		       clk,
		       input 		       rst,

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
		       input 		             dma_run,
		       output reg            dma_ready,
           input [10:0]          dma_start_index,
           input [10:0]          dma_end_index,

		       output wire[31:0]     in_data,
		       output reg[8:0]       in_addr,
           output wire           in_wr,
           output wire[3:0]      in_wstrb
		       );

   assign m_axi_arid = 0;   // id is zero
   assign m_axi_arsize = 3'h2; // 4 bytes at a time 
   assign m_axi_arburst = 2'b01; // incr bursting
   assign m_axi_arlock = 0; // do not lock
   assign m_axi_arcache = 4'h2; 
   assign m_axi_arprot = `AXI_PROT_W'b010;
   assign m_axi_arqos = `AXI_QOS_W'h0;

   reg [3:0] state;
   reg [3:0] read_wstrb;

   wire [3:0] dma_read_strobe_start = dma_addr[1] ? (dma_addr[0] ? 4'b1000 : 4'b1100):
                                                    (dma_addr[0] ? 4'b1110 : 4'b1111);

   wire [3:0] in_wstrb_start = dma_start_index[1] ? (dma_start_index[0] ? 4'b1000 : 4'b1100):
                                                    (dma_start_index[0] ? 4'b1110 : 4'b1111);

   wire [31:0] aligned_data;
   wire aligned_valid;
   wire ram_last;
   wire write_last;

   // Aligns data coming from the RAM
   eth_burst_align burst_align(
        .data(m_axi_rdata),
        .strobe(read_wstrb),
        .valid(m_axi_rvalid),
        .last(m_axi_rlast),

        .data_out(aligned_data),
        .data_valid(aligned_valid),
        .strobe_out(),
        .last_out(ram_last),

        .delay(1'b0),

        .clk(clk),
        .rst(rst)
    );

   // Misalign data to write to the TX buffer
   eth_burst_split burst_split(
        .data(aligned_data),
        .valid(aligned_valid),
        .strobe(in_wstrb_start),
        .last(ram_last),

        .data_out(in_data),
        .data_valid(in_wr),
        .strobe_out(in_wstrb),
        .last_out(write_last),

        .delay(1'b0),
        
        .clk(clk),
        .rst(rst)
    );

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
         read_wstrb <= 4'b0001;
         dma_ready <= 1'b1;
      end else begin
         if(in_wr)
          in_addr <= in_addr + 32'h1;

         case(state)
           4'h0: begin
             if(dma_run)
             begin
              dma_ready <= 1'b0;
              state <= 4'h1;
              read_wstrb <= dma_read_strobe_start;
              m_axi_arvalid <= 1'b1;
              m_axi_araddr <= {dma_addr[AXI_ADDR_W-1:2],2'b00};
              m_axi_arlen <= dma_end_index[10:2] - dma_start_index[10:2];
              in_addr <= dma_start_index[10:2];
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
             if(m_axi_rvalid & m_axi_rlast) begin
              m_axi_rready <= 1'b0;
              state <= 4'h4;
             end
           end
           4'h4: begin
             if(write_last) begin // Wait for last to signal end of DMA transfer
              dma_ready <= 1'b1;
              state <= 4'h0;
             end
           end
          default:;
         endcase
      end
   end

endmodule
