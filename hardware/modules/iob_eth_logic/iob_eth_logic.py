# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": True,
        "confs": [
            {
                "name": "BUFFER_W",
                "type": "P",
                "val": "11",
                "min": "0",
                "max": "32",
                "descr": "Buffer size",
            },
        ],
        "ports": [
            {
                "name": "clk_en_rst_s",
                "descr": "Clock, clock enable and reset",
                "signals": {
                    "type": "iob_clk",
                },
            },
            {
                "name": "eth_logic_io",
                "signals": [
                    {"name": "tx_bd_cnt_valid_rd_i", "width": 1},
                    {"name": "tx_bd_cnt_ready_rd_o", "width": 1},
                    {"name": "tx_bd_cnt_rvalid_rd_o", "width": 1},
                    {"name": "rx_bd_cnt_valid_rd_i", "width": 1},
                    {"name": "rx_bd_cnt_ready_rd_o", "width": 1},
                    {"name": "rx_bd_cnt_rvalid_rd_o", "width": 1},
                    {"name": "tx_word_cnt_valid_rd_i", "width": 1},
                    {"name": "tx_word_cnt_ready_rd_o", "width": 1},
                    {"name": "tx_word_cnt_rvalid_rd_o", "width": 1},
                    {"name": "rx_word_cnt_valid_rd_i", "width": 1},
                    {"name": "rx_word_cnt_ready_rd_o", "width": 1},
                    {"name": "rx_word_cnt_rvalid_rd_o", "width": 1},
                    {"name": "rx_nbytes_valid_rd_i", "width": 1},
                    {"name": "rx_nbytes_ready_rd_o", "width": 1},
                    {"name": "rx_nbytes_rvalid_rd_o", "width": 1},
                    {"name": "rx_nbytes_rdata_rd_o", "width": "BUFFER_W"},
                    {"name": "frame_word_ready_wrrd_o", "width": 1},
                    {"name": "frame_word_wstrb_wrrd_i", "width": 1},
                    {"name": "frame_word_valid_wrrd_i", "width": 1},
                    {"name": "internal_frame_word_wen_o", "width": 1},
                    {"name": "internal_frame_word_ren_o", "width": 1},
                    {"name": "internal_frame_word_ready_wr_i", "width": 1},
                    {"name": "internal_frame_word_ready_rd_i", "width": 1},
                    {"name": "internal_bd_wen_o", "width": 1},
                    {"name": "bd_valid_wrrd_i", "width": 1},
                    {"name": "bd_wstrb_wrrd_i", "width": 4},
                    {"name": "bd_ready_wrrd_o", "width": 1},
                    {"name": "bd_rvalid_wrrd_o", "width": 1},
                    {"name": "rx_nbytes_valid_i", "width": 1},
                    {"name": "rx_nbytes_i", "width": "BUFFER_W"},
                ],
            },
        ],
        "comb": {
            "code": """
    // Delay rvalid and rdata signals of NOAUTO CSRs by one clock cycle, since they must come after valid & ready handshake

    // tx bd cnt logic
    tx_bd_cnt_ready_rd_o = 1'b1;
    tx_bd_cnt_rvalid_rd_o_nxt = tx_bd_cnt_valid_rd_i & tx_bd_cnt_ready_rd_o;

    // rx bd cnt logic
    rx_bd_cnt_ready_rd_o = 1'b1;
    rx_bd_cnt_rvalid_rd_o_nxt = rx_bd_cnt_valid_rd_i & rx_bd_cnt_ready_rd_o;

    // tx word cnt logic
    tx_word_cnt_ready_rd_o = 1'b1;
    tx_word_cnt_rvalid_rd_o_nxt = tx_word_cnt_valid_rd_i & tx_word_cnt_ready_rd_o;

    // rx word cnt logic
    rx_word_cnt_ready_rd_o = 1'b1;
    rx_word_cnt_rvalid_rd_o_nxt = rx_word_cnt_valid_rd_i & rx_word_cnt_ready_rd_o;

    // rx nbytes logic
    rx_nbytes_ready_rd_o = 1'b1;
    rx_nbytes_rvalid_rd_o_en = rx_nbytes_valid_rd_i & rx_nbytes_ready_rd_o;
    rx_nbytes_rvalid_rd_o_rst = rx_nbytes_rvalid_rd_o;  // Enable for one clock cycle
    rx_nbytes_rvalid_rd_o_nxt = 1'b1;
    // same logic for rdata
    rx_nbytes_rdata_rd_o_en = rx_nbytes_rvalid_rd_o_en;
    rx_nbytes_rdata_rd_o_nxt = rx_nbytes_valid_i ? rx_nbytes_i : 0;

    // frame word logic
    frame_word_ready_wrrd_o = internal_frame_word_wen_o ? internal_frame_word_ready_wr_i : internal_frame_word_ready_rd_i;
    internal_frame_word_wen_o = frame_word_valid_wrrd_i & (|frame_word_wstrb_wrrd_i);
    internal_frame_word_ren_o = frame_word_valid_wrrd_i & (~(|frame_word_wstrb_wrrd_i));

    // BD logic
    internal_bd_wen_o = bd_valid_wrrd_i & (|bd_wstrb_wrrd_i);
    bd_ready_wrrd_o = 1'b1;
    bd_rvalid_wrrd_o_nxt = bd_valid_wrrd_i && (~(|bd_wstrb_wrrd_i));
    // bd_rdata_wrrd already delayed due to RAM
""",
        },
        # "snippets": [
        #     {"verilog_code": "iob_reg_ca #(.DATA_W(1), .RST_VAL()) tx_bd_cnt_rvalid_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .data_i(tx_bd_cnt_rvalid_rd_o_nxt), .data_o(tx_bd_cnt_rvalid_rd_o) );"},
        #     {"verilog_code": "iob_reg_ca #(.DATA_W(1), .RST_VAL()) rx_bd_cnt_rvalid_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .data_i(rx_bd_cnt_rvalid_rd_o_nxt), .data_o(rx_bd_cnt_rvalid_rd_o) );"},
        #     {"verilog_code": "iob_reg_ca #(.DATA_W(1), .RST_VAL()) tx_word_cnt_rvalid_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .data_i(tx_word_cnt_rvalid_rd_o_nxt), .data_o(tx_word_cnt_rvalid_rd_o) );"},
        #     {"verilog_code": "iob_reg_ca #(.DATA_W(1), .RST_VAL()) rx_word_cnt_rvalid_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .data_i(rx_word_cnt_rvalid_rd_o_nxt), .data_o(rx_word_cnt_rvalid_rd_o) );"},
        #     {"verilog_code": "iob_reg_care #(.DATA_W(1), .RST_VAL(0)) rx_nbytes_rvalid_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .rst_i(rx_nbytes_rvalid_rd_o_rst), .en_i(rx_nbytes_rvalid_rd_o_en), .data_i(rx_nbytes_rvalid_rd_o_nxt), .data_o(rx_nbytes_rvalid_rd_o) );"},
        #     {"verilog_code": "iob_reg_cae #(.DATA_W(BUFFER_W), .RST_VAL()) rx_nbytes_rdata_rd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .en_i(rx_nbytes_rdata_rd_o_en), .data_i(rx_nbytes_rdata_rd_o_nxt), .data_o(rx_nbytes_rdata_rd_o) );"},
        #     {"verilog_code": "iob_reg_ca #(.DATA_W(1), .RST_VAL()) bd_rvalid_wrrd_o_reg ( .clk_i(clk_i), .cke_i(cke_i), .arst_i(arst_i), .data_i(bd_rvalid_wrrd_o_nxt), .data_o(bd_rvalid_wrrd_o) );"}
        # ],
    }

    return attributes_dict
