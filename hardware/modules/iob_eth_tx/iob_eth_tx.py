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
                "name": "buffer_io",
                "signals": [
                    {"name": "addr_o", "isvar": True, "width": 11},
                    {"name": "data_i", "width": 8},
                ],
            },
            {
                "name": "dma_io",
                "signals": [
                    {"name": "send_i", "width": 1},
                    {"name": "ready_o", "isvar": True, "width": 1},
                    {"name": "nbytes_i", "width": 11},
                    {"name": "crc_en_i", "width": 1},
                ],
            },
            {
                "name": "mii_io",
                "signals": [
                    {"name": "tx_clk_i", "width": 1},
                    {"name": "tx_en_o", "isvar": True, "width": 1},
                    {"name": "tx_data_o", "isvar": True, "width": 4},
                ],
            },
        ],
        "subblocks": [],
    }

    return attributes_dict
