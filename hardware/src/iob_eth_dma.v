`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma #(
            parameter DMA_DATA_W = 32,
            // AXI4 interface parameters
            parameter AXI_ADDR_W = 32,
            parameter AXI_DATA_W = DMA_DATA_W
    ) (
        // system inputs
        input                 clk,
        input                 rst,

        `include "cpu_axi4_m_if.v"

        // DMA Configurations
        input[AXI_ADDR_W-1:0] dma_addr,
        input                 dma_run,
        output wire           dma_ready,
        input [9:0]           dma_len,
        input                 dma_read_from_not_write,

        // For now have two different addresses for in and out data
        output [31:0]         in_data,
        output reg[8:0]       in_addr,
        output                in_wr,

        input [31:0]          out_data,
        output reg[8:0]       out_addr
    );

wire dma_ready_r,dma_ready_w;

assign dma_ready = dma_ready_r & dma_ready_w;

iob_eth_dma_w #(
    .DMA_DATA_W(DMA_DATA_W),
    .AXI_ADDR_W(AXI_ADDR_W),
    .AXI_DATA_W(AXI_DATA_W)
  ) eth_dma_w (
        // system inputs
        .clk(clk),
        .rst(rst),

        .out_data(out_data),
        .out_addr(out_addr),

        .dma_addr(dma_addr),
        .dma_run(dma_run & dma_read_from_not_write),
        .dma_ready(dma_ready_w),
        .dma_len(dma_len),

        // AXI4 Master i/f
        // Address write
        .m_axi_awid(m_axi_awid), 
        .m_axi_awaddr(m_axi_awaddr), 
        .m_axi_awlen(m_axi_awlen), 
        .m_axi_awsize(m_axi_awsize), 
        .m_axi_awburst(m_axi_awburst), 
        .m_axi_awlock(m_axi_awlock), 
        .m_axi_awcache(m_axi_awcache), 
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos), 
        .m_axi_awvalid(m_axi_awvalid), 
        .m_axi_awready(m_axi_awready),
        //write
        .m_axi_wdata(m_axi_wdata), 
        .m_axi_wstrb(m_axi_wstrb), 
        .m_axi_wlast(m_axi_wlast), 
        .m_axi_wvalid(m_axi_wvalid), 
        .m_axi_wready(m_axi_wready), 
        //write response
        .m_axi_bresp(m_axi_bresp), 
        .m_axi_bvalid(m_axi_bvalid), 
        .m_axi_bready(m_axi_bready)
  );

iob_eth_dma_r #(
    .DMA_DATA_W(DMA_DATA_W),
    .AXI_ADDR_W(AXI_ADDR_W),
    .AXI_DATA_W(AXI_DATA_W)
  ) eth_dma_r (
        // system inputs
        .clk(clk),
        .rst(rst),

        .in_data(in_data),
        .in_addr(in_addr),
        .in_wr(in_wr),

        .dma_addr(dma_addr),
        .dma_run(dma_run & !dma_read_from_not_write),
        .dma_ready(dma_ready_r),
        .dma_len(dma_len),

        // AXI4 Master i/f
        //address read
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
   
        //read
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
  );

endmodule
