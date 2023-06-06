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
                "descr": """Mode Register\n
                            Bit Description\n
                            31-17: Reserved\n
                            16: RECSMALL - Receive Small Packets. 0 = Packets smaller than MINFL are ignored; 1 = Packets smaller than MINFL are accepted.\n
                            15: PAD - Padding enabled. 0 = do not add pads to short frames; 1 = add pads to short frames (until the minimum frame length is equal to MINFL).\n
                            14: HUGEN = Huge Packets Enable. 0 = the maximum frame length is MAXFL. All Additional bytes are discarded; 1 = Frames up 64KB are transmitted.\n
                            13: CRCEN - CRC Enable. 0 = Tx MAC does not append the CRC (passed frames already contain the CRC; 1 = Tx MAC appends the CRC to every frame.\n
                            12: DLYCRCEN - Delayed CRC Enabled. 0 = Normal operation (CRC calculation starts immediately after the SFD); 1 = CRC calculation starts 4 bytes after the SFD.\n
                            11: Reserved\n
                            10: FULLD - Full Duplex. 0 = Half duplex mode; 1 = Full duplex mode.\n
                            9: EXDFREN - Excess Defer Enabled. 0 = When the excessive deferral limit is reached, a packet is aborted; 1 = MAC waits for the carrier indefinitely.\n
                            8: NOBCKOF - No Backoff. 0 = Normal operation (a binary exponential backoff algorithm is used); 1 = Tx MAC starts retransmitting immediately after the collision.\n
                            7: LOOPBCK - Loop Back. 0 = Normal operation; 1 = Tx is looped back to the RX.\n
                            6: IFG - Interframe Gap for Incoming frames. 0 = Normal operation (minimum IFG is required for a frame to be accepted; 1 = All frames are accepted regardless to the IFG.\n
                            5: PRO - Promiscuous. 0 = Check the destination address of the incoming frames; 1 = Receive the frame regardless of its address.\n
                            4: IAM - Individual Address Mode. 0 = Normal operation (physical address is checked when the frame is received); 1 = The individual hash table is used to check all individual addresses received.\n
                            3: BRO - Broadcast Address. 0 = Receive all frames containing the breadcast address; 1 = Reject all frames containing the broadcast address unless the PRO bit=1.\n
                            2: NOPRE - No Preamble. 0 = Normal operation (7-byte preamble); 1 = No preamble is sent.\n
                            1: TXEN - Transmit Enable. 0 = Transmit is disabled; 1 = Transmit is enabled. If the value, written to the TX_BD_NUM register, is equal to 0x0 (zero buffer descriptors are used), then the transmitter is automatically disabled regardless of the TXEN bit.\n
                            0: RXEN - Receive Enable. 0 = Transmit is disabled; 1 = Transmit is enabled. If the value, written to the TX_BD_NUM register, is equal to 0x80 (all buffer descriptors are used for transmit buffer descriptors, so there is no receive BD), then the receiver is automatically disabled regardless of the RXEN bit.\n""",
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
