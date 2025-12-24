# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": True,
        "ports": [
            {
                "name": "clk_en_rst_s",
                "descr": "Clock, clock enable and reset",
                "signals": {
                    "type": "iob_clk",
                },
            },
            {
                "name": "management_io",
                "descr": "MII management interface",
                "signals": [
                    {"name": "mii_mdc_o", "width": 1},
                    {"name": "mii_mdio_io", "width": 1},
                ],
            },
        ],
        "subblocks": [],
        "snippets": [
            {
                "verilog_code": """
   assign mii_mdc_o        = 1'b0;  //TODO
   //assign mii_mdio_io   = 1'b0;  //TODO

            """
            }
        ],
    }

    return attributes_dict
