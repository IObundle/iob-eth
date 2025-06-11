`timescale 1ns / 1ps

module iob_eth_noauto_read_write #(
   parameter DATA_W  = 1
) (
   // clk_en_rst_s: Clock, clock enable and reset
   input               clk_i,
   input               cke_i,
   input               arst_i,
   // CSR interface
   input               valid_i,
   input  [DATA_W-1:0] wdata_i,
   input               wstrb_i,
   output              ready_o,
   output [DATA_W-1:0] rdata_o,
   input               rready_i,
   output              rvalid_o,
   // internal core interface
   output              int_wen_o,
   output [DATA_W-1:0] int_wdata_o,
   input               int_ready_wr_i,
   output              int_ren_o,
   input  [DATA_W-1:0] int_rdata_i,
   input               int_rvalid_i,
   input               int_ready_rd_i
);

   wire ready_read;
   wire ready_write;
   wire valid_read;

   assign valid_read = valid_i & (~(|wstrb_i));
   assign ready_o = valid_read ? ready_read : ready_write;

   iob_eth_noauto_read #(
      .DATA_W(DATA_W)
   ) noauto_read_inst (
       // clk_en_rst_s: Clock, clock enable and reset
       .clk_i(clk_i),
       .cke_i(cke_i),
       .arst_i(arst_i),
       // CSR interface
       .valid_i(valid_read),
       .rdata_o(rdata_o),
       .rready_i(rready_i),
       .ready_o(ready_read),
       .rvalid_o(rvalid_o),
       // internal core interface
       .int_ren_o(int_ren_o),
       .int_rdata_i(int_rdata_i),
       .int_rvalid_i(int_rvalid_i),
       .int_ready_i(int_ready_rd_i)
   );

   iob_eth_noauto_write #(
      .DATA_W(DATA_W)
   ) noauto_write_inst (
       // CSR interface
       .valid_i(valid_i),
       .wdata_i(wdata_i),
       .wstrb_i(wstrb_i),
       .ready_o(ready_write),
       // internal core interface
       .int_wen_o(int_wen_o),
       .int_wdata_o(int_wdata_o),
       .int_ready_i(int_ready_wr_i)
   );

endmodule
