# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": False,
        "confs": [
            {  # For iob_iobuf
                "name": "FPGA_TOOL",
                "descr": "Use IPs from fpga tool. Avaliable options: 'XILINX', 'other'.",
                "type": "P",
                "val": '"other"',
                "min": "NA",
                "max": "NA",
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
                "name": "mii_reg_i",
                "descr": "Register interface",
                "signals": [
                    {"name": "miimoder_i", "width": 32},
                    {"name": "miicommand_i", "width": 32},
                    {"name": "miiaddress_i", "width": 32},
                    {"name": "miitx_data_i", "width": 32},
                ],
            },
            {
                "name": "mii_status_o",
                "descr": "Data/status outputs",
                "signals": [
                    {"name": "miirx_data_o", "width": 32},
                    {"name": "miistatus_o", "width": 32},
                    {"name": "miicommand_clr_o", "width": 1},
                ],
            },
            {
                "name": "management_io",
                "descr": "MII interface",
                "signals": [
                    {"name": "mii_mdc_o", "width": 1},
                    {"name": "mii_mdio_io", "width": 1},
                ],
            },
        ],
        "subblocks": [
            {
                "core_name": "iob_iobuf",
                "instantiate": False,
            },
        ],
    }

    return attributes_dict
