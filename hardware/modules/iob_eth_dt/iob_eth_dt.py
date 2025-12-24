# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": False,
        "description": "Ethernet Data Transfer Module",
        "confs": [
            {
                "name": "AXI_ID_W",
                "descr": "AXI ID bus width",
                "type": "D",
                "val": "1",
            },
            {
                "name": "AXI_LEN_W",
                "descr": "AXI burst length width",
                "type": "D",
                "val": "8",
            },
            {
                "name": "AXI_ADDR_W",
                "descr": "AXI address bus width",
                "type": "D",
                "val": "0",
            },
            {
                "name": "AXI_DATA_W",
                "descr": "AXI data bus width",
                "type": "D",
                "val": "32",
            },
            {
                "name": "BUFFER_W",
                "descr": "",
                "type": "P",
                "val": "11",
            },
            {
                "name": "BD_ADDR_W",
                "descr": "128 buffers = 256 addresses (2x 32-bit words each buffer)",
                "type": "P",
                "val": "8",
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
                "name": "csrs_control_i",
                "signals": [
                    {"name": "rx_en_i", "width": 1},
                    {"name": "tx_en_i", "width": 1},
                    {"name": "tx_bd_num_i", "width": "BD_ADDR_W-1"},
                    # TODO: What should happen if the value of `tx_bd_num_i` changes? Should
                    # the RX state machine be reset to this buffer descriptor?
                    # For example, if the state machine is reading BD number 64, and the value
                    # changes to 65, should the state machine be reset to BD number 65? Or keep
                    # reading 64?
                ],
            },
            {
                "name": "buffer_descriptors_io",
                "signals": [
                    {"name": "bd_en_o", "width": 1},
                    {"name": "bd_addr_o", "width": "BD_ADDR_W"},
                    {"name": "bd_wen_o", "width": 1},
                    {"name": "bd_i", "width": 32},
                    {"name": "bd_o", "width": 32},
                ],
            },
            {
                "name": "tx_front_end_io",
                "signals": [
                    {"name": "eth_data_wr_wen_o", "isvar": True, "width": 1},
                    {"name": "eth_data_wr_addr_o", "isvar": True, "width": "BUFFER_W"},
                    {"name": "eth_data_wr_wdata_o", "isvar": True, "width": 8},
                    {"name": "tx_ready_i", "width": 1},
                    {"name": "crc_en_o", "width": 1},
                    {"name": "tx_nbytes_o", "width": 11},
                    {"name": "send_o", "width": 1},
                ],
            },
            {
                "name": "rx_back_end_io",
                "signals": [
                    {"name": "eth_data_rd_ren_o", "width": 1},
                    {"name": "eth_data_rd_addr_o", "isvar": True, "width": "BUFFER_W"},
                    {"name": "eth_data_rd_rdata_i", "width": 8},
                    {"name": "rx_data_rcvd_i", "width": 1},
                    {"name": "crc_err_i", "width": 1},
                    {"name": "rx_nbytes_i", "width": 11},
                    {"name": "rcv_ack_o", "width": 1},
                ],
            },
            {
                "name": "axi_m",
                "descr": "AXI manager interface for external memory (DMA)",
                "signals": {
                    "type": "axi",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "no_dma_io",
                "signals": [
                    {"name": "tx_bd_cnt_o", "isvar": True, "width": "BD_ADDR_W-1"},
                    {"name": "tx_word_cnt_o", "isvar": True, "width": 11},
                    {"name": "tx_frame_word_wen_i", "width": 1},
                    {"name": "tx_frame_word_wdata_i", "width": 8},
                    {"name": "tx_frame_word_ready_o", "isvar": True, "width": 1},
                    {"name": "rx_bd_cnt_o", "isvar": True, "width": "BD_ADDR_W-1"},
                    {"name": "rx_word_cnt_o", "isvar": True, "width": 11},
                    {"name": "rx_frame_word_ren_i", "width": 1},
                    {"name": "rx_frame_word_rdata_o", "isvar": True, "width": 8},
                    {"name": "rx_frame_word_rvalid_o", "isvar": True, "width": 1},
                    {"name": "rx_frame_word_ready_o", "isvar": True, "width": 1},
                ],
            },
            {
                "name": "interrupts_o",
                "signals": [
                    {"name": "tx_irq_o", "isvar": True, "width": 1},
                    {"name": "rx_irq_o", "isvar": True, "width": 1},
                ],
            },
        ],
        "subblocks": [
            {
                "core_name": "iob_reg",
                "instantiate": False,
                "port_params": {
                    "clk_en_rst_s": "c_a",
                },
            },
            {
                "core_name": "iob_arbiter",
                "instantiate": False,
            },
        ],
    }

    return attributes_dict
