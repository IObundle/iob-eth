// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0

`timescale 1ns / 1ps
`include "iob_eth_mii_management_conf.vh"

module iob_eth_mii_management #(
   `include "iob_eth_mii_management_params.vs"
) (
   `include "iob_eth_mii_management_io.vs"
);

   localparam IDLE = 2'd0;
   localparam FRAME = 2'd1;
   localparam DONE = 2'd2;

   reg [1:0] state, state_nxt;

   reg  [7:0] clkdiv_reg;
   wire [7:0] div = (clkdiv_reg == 8'd0) ? 8'd2 : clkdiv_reg;

   // MDC generation
   reg  [7:0] clk_cnt;
   reg        mdc;
   wire       mdc_tick = (clk_cnt >= (div >> 1) - 1);
   wire       mdc_rise = mdc_tick && (mdc == 1'b0);
   wire       mdc_fall = mdc_tick && (mdc == 1'b1);

   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         clkdiv_reg <= 8'd40;
         clk_cnt    <= 8'd0;
         mdc        <= 1'b0;
      end else if (cke_i) begin
         if (miimoder_i[7:0] != 8'd0) clkdiv_reg <= miimoder_i[7:0];
         if (mdc_tick) begin
            clk_cnt <= 8'd0;
            mdc     <= ~mdc;
         end else begin
            clk_cnt <= clk_cnt + 1'b1;
         end
      end
   end

   assign mii_mdc_o = mdc;

   // MDIO output (update on MDC falling edge)
   reg mdio_out;
   reg mdio_out_nxt;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) mdio_out <= 1'b0;
      else if (cke_i && mdc_fall) mdio_out <= mdio_out_nxt;
   end

   // MDIO output enable (update on MDC falling edge)
   reg mdio_oe;
   reg mdio_oe_nxt;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) mdio_oe <= 1'b0;
      else if (cke_i && mdc_fall) mdio_oe <= mdio_oe_nxt;
   end

   // MDIO input/output via iobuf
   wire mdio_iobuf_o;

   iob_iobuf #(
      .FPGA_TOOL(FPGA_TOOL)
   ) mdio_iobuf_inst (
       .i_i  (mdio_out),
       .t_i  (~mdio_oe),
       .n_i  (1'b0),
       .o_o  (mdio_iobuf_o),
       .io_io(mii_mdio_io)
   );

   // MDIO input (sample on every clock cycle to ensure a direct load on the IBUFCTRL output)
   reg mdio_in;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) mdio_in <= 1'b0;
      else if (cke_i) mdio_in <= mdio_iobuf_o;
   end

   // Edge detection on miicommand
   reg miicommand_prev;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) miicommand_prev <= 1'b0;
      else if (cke_i) miicommand_prev <= miicommand_i[1] | miicommand_i[2];
   end
   wire start_op = (miicommand_i[1] | miicommand_i[2]) && !miicommand_prev;

   // State machine combinatorial logic
   reg [6:0] bit_cnt, bit_cnt_nxt;
   reg [15:0] data_shift, data_shift_nxt;
   reg [15:0] rx_data, rx_data_nxt;
   reg op_read;
   reg busy_nxt;
   reg done_pulse;

   // Latch start request from single-cycle start_op pulse until consumed
   // by the state machine on mdc_rise when IDLE (start_op might be missed
   // if it fires while state != IDLE)
   reg start_req;
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) start_req <= 1'b0;
      else if (cke_i) begin
         if (start_op) start_req <= 1'b1;
         else if (state == IDLE && mdc_rise) start_req <= 1'b0;
      end
   end

   always @* begin
      state_nxt      = state;
      bit_cnt_nxt    = bit_cnt;
      data_shift_nxt = data_shift;
      rx_data_nxt    = rx_data;
      mdio_out_nxt   = 1'b1;
      mdio_oe_nxt    = 1'b1;
      busy_nxt       = 1'b0;
      done_pulse     = 1'b0;
      op_read        = miicommand_i[1];

      case (state)
         IDLE: begin
            mdio_oe_nxt = 1'b0;
            if (start_req) begin
               state_nxt   = FRAME;
               bit_cnt_nxt = 7'd0;
               if (miicommand_i[2]) data_shift_nxt = miitx_data_i[15:0];
            end
         end

         FRAME: begin
            busy_nxt = 1'b1;
            // Determine the current bit's output based on bit_cnt
            // 0-31: preamble
            if (bit_cnt <= 31) begin
               mdio_out_nxt = 1'b1;
               // NOPRE: skip preamble (jump to first start bit)
               if (miimoder_i[8]) bit_cnt_nxt = 7'd32;
               // 32: start "0"
            end else if (bit_cnt == 32) begin
               mdio_out_nxt = 1'b0;
               // 33: start "1"
            end else if (bit_cnt == 33) begin
               mdio_out_nxt = 1'b1;
               // 34-35: opcode
            end else if (bit_cnt <= 35) begin
               if (op_read) mdio_out_nxt = (bit_cnt == 34) ? 1'b1 : 1'b0;
               else mdio_out_nxt = (bit_cnt == 34) ? 1'b0 : 1'b1;
               // 36-40: PHY address (5 bits, MSB first)
            end else if (bit_cnt <= 40) begin
               mdio_out_nxt = miiaddress_i[40-bit_cnt];
               // 41-45: register address (5 bits, MSB first)
            end else if (bit_cnt <= 45) begin
               mdio_out_nxt = miiaddress_i[45-bit_cnt+8];
               // 46-47: turnaround
            end else if (bit_cnt <= 47) begin
               if (op_read) mdio_oe_nxt = 1'b0;
               else mdio_out_nxt = (bit_cnt == 46) ? 1'b1 : 1'b0;
               // 48-63: data
            end else begin
               if (op_read) begin
                  mdio_oe_nxt = 1'b0;
               end else begin
                  mdio_out_nxt   = data_shift[15];
                  data_shift_nxt = {data_shift[14:0], 1'b0};
               end
            end

            if (bit_cnt == 64) begin
               state_nxt  = DONE;
               done_pulse = 1'b1;
            end else begin
               bit_cnt_nxt = bit_cnt + 1'b1;
               if (op_read && bit_cnt >= 48) rx_data_nxt = {rx_data[14:0], mdio_in};
            end
         end

         DONE: begin
            mdio_oe_nxt = 1'b0;
            state_nxt   = IDLE;
         end

         default: state_nxt = IDLE;
      endcase
   end

   // Sequential update on MDC rising edge
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         state      <= IDLE;
         bit_cnt    <= 7'd0;
         data_shift <= 16'd0;
         rx_data    <= 16'd0;
      end else if (cke_i && mdc_rise) begin
         if (state != IDLE) begin
            state      <= state_nxt;
            bit_cnt    <= bit_cnt_nxt;
            data_shift <= data_shift_nxt;
            rx_data    <= rx_data_nxt;
         end else if (start_req) begin
            state   <= FRAME;
            bit_cnt <= 7'd0;
            if (miicommand_i[2]) data_shift <= miitx_data_i[15:0];
         end
      end
   end

   // Busy: combinational — high immediately when a command is received
   // (start_req) and stays high until the frame finishes (state returns to IDLE)
   wire busy = (state != IDLE) | start_req;

   // Outputs
   assign miirx_data_o     = {16'd0, rx_data};
   assign miistatus_o      = {30'd0, busy, 1'b0};
   assign miicommand_clr_o = done_pulse;

endmodule
