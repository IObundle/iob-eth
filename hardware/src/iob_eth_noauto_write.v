`timescale 1ns / 1ps

module iob_eth_noauto_write #(
   parameter DATA_W  = 1
) (
   // CSR interface
   input               valid_i,
   input  [DATA_W-1:0] wdata_i,
   input               wstrb_i,
   output              ready_o,
   // internal core interface
   output              int_wen_o,
   output [DATA_W-1:0] int_wdata_o,
   input               int_ready_i
);

   // CSR outputs
   assign ready_o = int_ready_i;

   // internal core outputs
   assign int_wen_o = valid_i & (|wstrb_i);
   assign int_wdata_o = wdata_i;

endmodule
