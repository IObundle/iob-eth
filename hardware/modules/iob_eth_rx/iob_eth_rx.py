# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": False,
        "ports": [
            {
                "name": "arst_i",
                "signals": [
                    {"name": "arst_i", "width": 1},
                ],
            },
            {
                "name": "buffer_o",
                "signals": [
                    {"name": "wr_o", "isvar": True, "width": 1},
                    {"name": "addr_o", "isvar": True, "width": 11},
                    {"name": "data_o", "isvar": True, "width": 8},
                ],
            },
            {
                "name": "dma_io",
                "signals": [
                    {"name": "rcv_ack_i", "width": 1},
                    {"name": "data_rcvd_o", "isvar": True, "width": 1},
                    {"name": "crc_err_o", "width": 1},
                ],
            },
            {
                "name": "mii_i",
                "signals": [
                    {"name": "rx_clk_i", "width": 1},
                    {"name": "rx_dv_i", "width": 1},
                    {"name": "rx_data_i", "width": 4},
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
        ],
    }

    return attributes_dict
