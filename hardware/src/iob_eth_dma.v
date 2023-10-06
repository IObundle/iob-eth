`timescale 1ns / 1ps

`include "iob_eth.vh"
`include "iob_eth_swreg_def.vh"

module iob_eth_dma #(
   parameter AXI_ADDR_W = 0,
   parameter AXI_DATA_W = 32,          // We currently only support 4 byte transfers
   parameter AXI_LEN_W  = 8,
   parameter AXI_ID_W   = 1
   //parameter BURST_W    = 0,
   //parameter BUFFER_W   = BURST_W + 1
) (
   // Configuration interface
   // TODO

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
endmodule
