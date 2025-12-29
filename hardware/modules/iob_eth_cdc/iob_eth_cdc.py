# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


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
                "name": "tx_rx_clk_i",
                "signals": [
                    {"name": "mii_rx_clk_i", "width": 1},
                    {"name": "mii_tx_clk_i", "width": 1},
                ],
            },
            {
                "name": "phy_rst_io",
                "signals": [
                    {"name": "phy_rst_i", "width": 1},
                    {"name": "rx_phy_rst_o", "width": 1},
                    {"name": "tx_phy_rst_o", "width": 1},
                ],
            },
            {
                "name": "system_io",
                "signals": [
                    {"name": "rcv_ack_i", "width": 1},
                    {"name": "send_i", "width": 1},
                    {"name": "crc_en_i", "width": 1},
                    {"name": "tx_nbytes_i", "width": 11},
                    {"name": "crc_err_o", "width": 1},
                    {"name": "rx_nbytes_o", "width": "BUFFER_W"},
                    {"name": "rx_data_rcvd_o", "width": 1},
                    {"name": "tx_ready_o", "width": 1},
                ],
            },
            {
                "name": "eth_io",
                "signals": [
                    {"name": "eth_rcv_ack_o", "width": 1},
                    {"name": "eth_send_o", "width": 1},
                    {"name": "eth_crc_en_o", "width": 1},
                    {"name": "eth_tx_nbytes_o", "width": 11},
                    {"name": "eth_crc_err_i", "width": 1},
                    {"name": "eth_rx_nbytes_i", "width": "BUFFER_W"},
                    {"name": "eth_rx_data_rcvd_i", "width": 1},
                    {"name": "eth_tx_ready_i", "width": 1},
                ],
            },
            # Synchronizer ports
            # {
            #     "name": "buffer_o",
            #     "signals": [
            #         {"name": "wr_o", "isvar": True, "width": 1},
            #         {"name": "addr_o", "isvar": True, "width": 11},
            #         {"name": "data_o", "isvar": True, "width": 8},
            #     ],
            # },
            # {
            #     "name": "dt_io",
            #     "signals": [
            #         {"name": "rcv_ack_i", "width": 1},
            #         {"name": "data_rcvd_o", "isvar": True, "width": 1},
            #         {"name": "crc_err_o", "width": 1},
            #     ],
            # },
            # {
            #     "name": "mii_i",
            #     "signals": [
            #         {"name": "rx_clk_i", "width": 1},
            #         {"name": "rx_dv_i", "width": 1},
            #         {"name": "rx_data_i", "width": 4},
            #     ],
            # },
        ],
        "wires": [
            # Reset synchronizer wires
            {
                "name": "rx_reset_sync_clk_rst",
                "signals": [
                    {"name": "mii_rx_clk_i"},
                    {"name": "arst_i"},
                ],
            },
            {
                "name": "rx_reset_sync_arst_o",
                "signals": [
                    {"name": "rx_clk_arst", "width": 1},
                ],
            },
            {
                "name": "tx_reset_sync_clk_rst",
                "signals": [
                    {"name": "mii_tx_clk_i"},
                    {"name": "arst_i"},
                ],
            },
            {
                "name": "tx_reset_sync_arst_o",
                "signals": [
                    {"name": "tx_clk_arst", "width": 1},
                ],
            },
        ],
        "subblocks": [
            # Reset Synchronizers
            {
                "core_name": "iob_reset_sync",
                "instance_name": "rx_reset_sync",
                "instance_description": "Async reset synchronizer for RX",
                "connect": {
                    "clk_rst_s": "rx_reset_sync_clk_rst",
                    "arst_o": "rx_reset_sync_arst_o",
                },
            },
            {
                "core_name": "iob_reset_sync",
                "instance_name": "tx_reset_sync",
                "instance_description": "Async reset synchronizer for TX",
                "connect": {
                    "clk_rst_s": "tx_reset_sync_clk_rst",
                    "arst_o": "tx_reset_sync_arst_o",
                },
            },
            # Synchronizers (generated below)
        ],
        # "snippets": [
        #     {
        #         "verilog_code": """""",
        #     },
        # ],
    }

    #
    # Synchronizers
    #

    synchronizers = {
        # Name: (data_w, clk, arst, input, output)
        "rx_arst_sync": (1, "mii_rx_clk_i", "rx_clk_arst", "phy_rst_i", "rx_phy_rst_o"),
        "tx_arst_sync": (1, "mii_tx_clk_i", "tx_clk_arst", "phy_rst_i", "tx_phy_rst_o"),
        "rcv_f2s_sync": (
            1,
            "mii_rx_clk_i",
            "rx_phy_rst_o",
            "rcv_ack_i",
            "eth_rcv_ack_o",
        ),
        "send_f2s_sync": (1, "mii_tx_clk_i", "tx_phy_rst_o", "send_i", "eth_send_o"),
        "crc_en_f2s_sync": (
            1,
            "mii_tx_clk_i",
            "tx_phy_rst_o",
            "crc_en_i",
            "eth_crc_en_o",
        ),
        "tx_nbytes_f2s_sync": (
            11,
            "mii_tx_clk_i",
            "tx_phy_rst_o",
            "tx_nbytes_i",
            "eth_tx_nbytes_o",
        ),
        "crc_err_sync": (1, "clk_i", "arst_i", "eth_crc_err_i", "crc_err_o"),
        "rx_nbytes_sync": (
            "BUFFER_W",
            "clk_i",
            "arst_i",
            "eth_rx_nbytes_i",
            "rx_nbytes_o",
        ),
        "rx_data_rcvd_sync": (
            1,
            "clk_i",
            "arst_i",
            "eth_rx_data_rcvd_i",
            "rx_data_rcvd_o",
        ),
        "tx_ready_sync": (1, "clk_i", "arst_i", "eth_tx_ready_i", "tx_ready_o"),
    }
    for k, v in synchronizers.items():
        attributes_dict["wires"] += [
            # Create internal wires for synchronizer ports
            {
                "name": f"{k}_clk_rst",
                "signals": [{"name": v[1]}, {"name": v[2]}],
            },
            {
                "name": f"{k}_signal_i",
                "signals": [{"name": v[3]}],
            },
            {
                "name": f"{k}_signal_o",
                "signals": [{"name": v[4]}],
            },
        ]
        # Create synchronizer
        attributes_dict["subblocks"].append(
            {
                "core_name": "iob_sync",
                "instance_name": f"{k}_sync",
                "instance_description": f"Synchronizer for {v[4]}",
                "parameters": {
                    "DATA_W": v[0],
                },
                "connect": {
                    "clk_rst_s": f"{k}_clk_rst",
                    "signal_i": f"{k}_signal_i",
                    "signal_o": f"{k}_signal_o",
                },
            },
        )

    return attributes_dict
