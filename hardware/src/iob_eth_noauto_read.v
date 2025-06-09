`timescale 1ns / 1ps

module iob_eth_noauto_read #(
   parameter DATA_W  = 1
) (
   // clk_en_rst_s: Clock, clock enable and reset
   input                   clk_i,
   input                   cke_i,
   input                   arst_i,
   // CSR interface
   input                   valid_i,
   input                   rready_i,
   output     [DATA_W-1:0] rdata_o,
   output                  rvalid_o,
   output                  ready_o,
   // internal core interface
   output                  int_ren_o,
   input      [DATA_W-1:0] int_rdata_i,
   input                   int_rvalid_i,
   input                   int_ready_i
);

    wire state;
    wire state_nxt;
    wire state_en;
    wire state_0_en;
    wire state_1_en;

    // toggle state
    assign state_nxt = ~state;
    assign state_0_en = valid_i & ready_o;
    assign state_1_en = rvalid_o & rready_i;
    assign state_en = (state)? state_1_en : state_0_en;

    // state register
    iob_reg_cae #(
      .DATA_W (1),
      .RST_VAL(1'd0)
    ) state_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .en_i(state_en),
      .data_i(state_nxt),
      .data_o(state)
    );

    // register rdata and rvalid
    wire [DATA_W-1:0] rdata_nxt;
    wire [DATA_W-1:0] rdata_r;

    assign rdata_nxt = (int_rvalid_i) ? int_rdata_i : rdata_r;
    iob_reg_ca #(
      .DATA_W (DATA_W),
      .RST_VAL({DATA_W{1'd0}})
    ) rdata_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .data_i(rdata_nxt),
      .data_o(rdata_r)
    );

    wire rvalid_nxt;
    wire rvalid_r;
    wire rvalid_rst;

    // reset on state 1->0 transition
    assign rvalid_rst = (state_en) & (state);
    assign rvalid_nxt = (rvalid_r) ? rvalid_r : int_rvalid_i;
    iob_reg_car #(
      .DATA_W (1),
      .RST_VAL(1'd0)
    ) rvalid_reg (
      .clk_i (clk_i),
      .cke_i (cke_i),
      .arst_i(arst_i),
      .rst_i(rvalid_rst),
      .data_i(rvalid_nxt),
      .data_o(rvalid_r)
    );

    // CSR outputs
    assign ready_o = ready_i;
    assign rvalid_o = (int_rvalid_i) ? int_rdata_i : rdata_r;
    assign rvalid_o = int_rvalid_i | rvalid_r;

    // internal core outputs
    assign int_ren_o = (state == 1'b0) & valid_i;

endmodule
