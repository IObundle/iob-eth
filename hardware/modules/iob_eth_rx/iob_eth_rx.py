# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only


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
                "name": "fifo_o",
                "descr": "Byte push interface to data FIFO",
                "signals": [
                    {"name": "wr_o", "isvar": True, "width": 1},
                    {"name": "data_o", "isvar": True, "width": 8},
                ],
            },
            {
                "name": "info_io",
                "descr": "Frame info push interface to info FIFO",
                "signals": [
                    {"name": "info_wen_o", "isvar": True, "width": 1},
                    {"name": "info_wdata_o", "isvar": True, "width": 12},
                    {"name": "info_w_full_i", "width": 1},
                ],
            },
            {
                "name": "flow_control_i",
                "descr": "Write-side empty of data FIFO (RX parks here until drained)",
                "signals": [
                    {"name": "w_empty_i", "width": 1},
                ],
            },
            {
                "name": "mii_i",
                "descr": "Default description",
                "signals": [
                    {"name": "rx_clk_i", "width": 1},
                    {"name": "rx_dv_i", "width": 1},
                    {"name": "rx_data_i", "width": 4},
                ],
            },
        ],
        "subblocks": [],
    }

    return attributes_dict
