# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": True,
        "description": "Ethernet Interrupt Controller Module",
        "confs": [],
        "ports": [
            {
                "name": "clk_en_rst_s",
                "descr": "Clock, clock enable and reset",
                "signals": {
                    "type": "iob_clk",
                },
            },
            {
                "name": "sw_write_i",
                "descr": "Software write interface (write-1-to-clear for int_source)",
                "signals": [
                    {"name": "sw_wen_i", "width": 1},
                    {"name": "sw_wdata_i", "width": 32},
                ],
            },
            {
                "name": "sw_mask_i",
                "descr": "Software mask interface",
                "signals": [
                    {"name": "sw_mask_wen_i", "width": 1},
                    {"name": "sw_mask_wdata_i", "width": 32},
                ],
            },
            {
                "name": "hw_events_i",
                "descr": "Hardware event pulses (single-cycle)",
                "signals": [
                    {"name": "hw_tx_frame_i", "width": 1},
                    {"name": "hw_tx_error_i", "width": 1},
                    {"name": "hw_rx_frame_i", "width": 1},
                    {"name": "hw_rx_error_i", "width": 1},
                    {"name": "hw_busy_i", "width": 1},
                ],
            },
            {
                "name": "csrs_readback_o",
                "descr": "Register outputs for CSR readback",
                "signals": [
                    {"name": "int_source_o", "width": 32},
                    {"name": "int_mask_o", "width": 32},
                ],
            },
            {
                "name": "irq_o",
                "descr": "Interrupt output",
                "signals": [
                    {"name": "irq_o", "width": 1},
                ],
            },
        ],
        "snippets": [
            {
                "verilog_code": """
   assign irq_o = |(int_source_o & int_mask_o);

   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         int_source_o <= 32'd0;
         int_mask_o   <= 32'd0;
      end else if (cke_i) begin
         // int_mask: normal RW
         if (sw_mask_wen_i)
            int_mask_o <= sw_mask_wdata_i;

         // int_source: write-1-to-clear from software, set from hardware
         if (sw_wen_i) begin
            // Software clears bits written as 1
            int_source_o <= (int_source_o & ~sw_wdata_i);
         end
         // OR in hardware events (regardless of software write)
         if (hw_tx_frame_i)  int_source_o[0] <= 1'b1;
         if (hw_tx_error_i)  int_source_o[1] <= 1'b1;
         if (hw_rx_frame_i)  int_source_o[2] <= 1'b1;
         if (hw_rx_error_i)  int_source_o[3] <= 1'b1;
         if (hw_busy_i)      int_source_o[4] <= 1'b1;
      end
   end
"""
            },
        ],
    }

    return attributes_dict
