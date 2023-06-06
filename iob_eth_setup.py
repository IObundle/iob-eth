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
                "name": "MODER",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 40960,
                "addr": 0,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Mode Register",
            },
            {
                "name": "INT_SOURCE",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 4,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Interrupt Source Register",
            },
            {
                "name": "INT_MASK",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 8,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Interrupt Mask Register",
            },
            {
                "name": "IPGT",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 18,
                "addr": 12,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Back to Back Inter Packet Gap Register",
            },
            {
                "name": "IPGR1",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 12,
                "addr": 16,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Non Back to Back Inter Packet Gap Register 1",
            },
            {
                "name": "IPGR2",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 18,
                "addr": 20,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Non Back to Back Inter Packet Gap Register 2",
            },
            {
                "name": "PACKETLEN",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 4195840,
                "addr": 24,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Packet Length (minimum and maximum) Register",
            },
            {
                "name": "COLLCONF",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 61443,
                "addr": 28,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Collision and Retry Configuration",
            },
            {
                "name": "TX_BD_NUM",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 64,
                "addr": 32,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Transmit Buffer Descriptor Number",
            },
            {
                "name": "CTRLMODER",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 36,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Control Module Mode Register",
            },
            {
                "name": "MIIMODER",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 100,
                "addr": 40,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Mode Register",
            },
            {
                "name": "MIICOMMAND",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 44,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Command Register",
            },
            {
                "name": "MIIADDRESS",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 48,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Address Register. Contains the PHY address and the register within the PHY address",
            },
            {
                "name": "MIITX_DATA",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 52,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Transmit Data. The data to be transmitted to the PHY",
            },
            {
                "name": "MIIRX_DATA",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 56,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Receive Data. The data received from the PHY",
            },
            {
                "name": "MIISTATUS",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 60,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MII Status Register",
            },
            {
                "name": "MAC_ADDR0",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 64,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MAC Individual Address0. The LSB four bytes of the individual address are written to this register",
            },
            {
                "name": "MAC_ADDR1",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 68,
                "log2n_items": 0,
                "autologic": True,
                "descr": "MAC Individual Address1. The MSB two bytes of the individual address are written to this register",
            },
            {
                "name": "ETH_HASH0_ADR",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 72,
                "log2n_items": 0,
                "autologic": True,
                "descr": "HASH0 Register",
            },
            {
                "name": "ETH_HASH1_ADR",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 76,
                "log2n_items": 0,
                "autologic": True,
                "descr": "HASH1 Register",
            },
            {
                "name": "ETH_TXCTRL",
                "type": "RW",
                "n_bits": 32,
                "rst_val": 0,
                "addr": 80,
                "log2n_items": 0,
                "autologic": True,
                "descr": "Transmit Control Register",
            },
        ],
    }
]

blocks = []

# Main function to setup this core and its components
if __name__ == "__main__":
    setup.setup(sys.modules[__name__], no_overlap=True)
