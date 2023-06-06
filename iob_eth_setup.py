#!/usr/bin/env python3

import os, sys

sys.path.insert(0, os.getcwd() + "/submodules/LIB/scripts")
import setup

name = "iob_eth"
version = "V0.20"

flows = "doc sim lint fpga"
if setup.is_top_module(sys.modules[__name__]):
    setup_dir = os.path.dirname(__file__)
    build_dir = f"../{name}_{version}"
submodules = {
    "hw_setup": {
        "headers": [
            "iob_s_port",
            "iob_utils.vh",
            "iob_clkenrst_portmap.vs",
            "iob_clkenrst_port.vs",
        ],
        "modules": ["iob_reg.v", "iob_reg_e.v"],
    },
}

confs = [
    # Macros
    # Parameters
    {
        "name": "DATA_W",
        "type": "P",
        "val": "32",
        "min": "NA",
        "max": "NA",
        "descr": "Data bus width",
    },
    {
        "name": "ADDR_W",
        "type": "P",
        "val": "`IOB_ETH_SWREG_ADDR_W",
        "min": "NA",
        "max": "NA",
        "descr": "Address bus width",
    },
    {
        "name": "ETH_MAC_ADDR",
        "type": "P",
        "val": "`ETH_MAC_ADDR",
        "min": "NA",
        "max": "NA",
        "descr": "Instance MAC address",
    },
    {
        "name": "PHY_RST_CNT",
        "type": "P",
        "val": "20'hFFFFF",
        "min": "NA",
        "max": "NA",
        "descr": "Reset counter value",
    },
]

ios = [
    {"name": "iob_s_port", "descr": "CPU native interface", "ports": []},
    {
        "name": "general",
        "descr": "GENERAL INTERFACE SIGNALS",
        "ports": [
            {
                "name": "clk_i",
                "type": "I",
                "n_bits": "1",
                "descr": "System clock input",
            },
            {
                "name": "arst_i",
                "type": "I",
                "n_bits": "1",
                "descr": "System reset, asynchronous and active high",
            },
            {
                "name": "cke_i",
                "type": "I",
                "n_bits": "1",
                "descr": "System reset, asynchronous and active high",
            },
        ],
    },
]

regs = [
    {
        "name": "iob_eth",
        "descr": "IOb-Eth Software Accessible Registers.",
        "regs": [
            {
                "name": "SOFTRESET",
                "type": "W",
                "n_bits": 1,
                "rst_val": 0,
                "addr": -1,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Soft reset.",
            },
        ],
    }
]

blocks = []

# Main function to setup this core and its components
if __name__ == "__main__":
    setup.setup(sys.modules[__name__], no_overlap=True)
