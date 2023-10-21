#!/usr/bin/env python3

import os

from iob_module import iob_module
from iob_block_group import iob_block_group

# Submodules
from iob_utils import iob_utils
from iob_reg import iob_reg
from iob_reg_e import iob_reg_e
from iob_sync import iob_sync
from iob_f2s_1bit_sync import iob_f2s_1bit_sync
from iob_ram_tdp_be import iob_ram_tdp_be
from iob_ram_dp import iob_ram_dp


class iob_eth(iob_module):
    name = "iob_eth"
    version = "V0.20"
    flows = "sim emb lint fpga doc"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        """Create submodules list with dependencies of this module"""
        super()._create_submodules_list(
            [
                {"interface": "iob_s_port"},
                {"interface": "iob_s_portmap"},
                {"interface": "clk_en_rst_s_s_portmap"},
                {"interface": "clk_en_rst_s_port"},
                iob_utils,
                iob_reg,
                iob_reg_e,
                iob_sync,
                iob_f2s_1bit_sync,
                iob_ram_tdp_be,
                iob_ram_dp,
            ]
        )

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs(
            [
                # Macros
                {
                    "name": "PREAMBLE",
                    "type": "M",
                    "val": "8'h55",
                    "min": "NA",
                    "max": "NA",
                    "descr": "",
                },
                {
                    "name": "PREAMBLE_LEN",
                    "type": "M",
                    "val": "7", # Should it be 7 + 2 bytes to align data transfers?
                    "max": "NA",
                    "min": "NA",
                    "descr": "",
                },
                {
                    "name": "SFD",
                    "type": "M",
                    "val": "8'hD5",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Start Frame Delimiter",
                },
                {
                    "name": "MAC_ADDR_LEN",
                    "type": "M",
                    "val": "6",
                    "min": "NA",
                    "max": "NA",
                    "descr": "",
                },
                # Parameters
                {
                    "name": "DATA_W",
                    "type": "P",
                    "val": "32",
                    "min": "NA",
                    "max": "128",
                    "descr": "Data bus width",
                },
                {
                    "name": "ADDR_W",
                    "type": "P",
                    "val": "`IOB_ETH_SWREG_ADDR_W",
                    "min": "NA",
                    "max": "128",
                    "descr": "Address bus width",
                },
                # External memory interface
                {
                    "name": "AXI_ID_W",
                    "type": "P",
                    "val": "0",
                    "min": "1",
                    "max": "32",
                    "descr": "AXI ID bus width",
                },
                {
                    "name": "AXI_ADDR_W",
                    "type": "P",
                    "val": "24",
                    "min": "1",
                    "max": "32",
                    "descr": "AXI address bus width",
                },
                {
                    "name": "AXI_DATA_W",
                    "type": "P",
                    "val": "DATA_W",
                    "min": "1",
                    "max": "32",
                    "descr": "AXI data bus width",
                },
                {
                    "name": "AXI_LEN_W",
                    "type": "P",
                    "val": "4",
                    "min": "1",
                    "max": "4",
                    "descr": "AXI burst length width",
                },
                #{
                #    "name": "BURST_W",
                #    "type": "P",
                #    "val": "0",
                #    "min": "0",
                #    "max": "8",
                #    "descr": "AXI burst width",
                #},
                {
                    "name": "BUFFER_W",
                    "type": "P",
                    "val": "1",  # BURST_W+1
                    "min": "0",
                    "max": "32",
                    "descr": "Buffer size",
                },
                {
                    "name": "MEM_ADDR_OFFSET",
                    "type": "P",
                    "val": "0",
                    "min": "0",
                    "max": "NA",
                    "descr": "Offset of memory address",
                },
                # Ethernet
                {
                    "name": "PHY_RST_CNT",
                    "type": "P",
                    "val": "20'hFFFFF",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Reset counter value",
                },
                {
                    "name": "BD_NUM_LOG2",
                    "type": "P",
                    "val": "7",
                    "min": "NA",
                    "max": "7",
                    "descr": "Log2 amount of buffer descriptors",
                },
            ]
        )

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {"name": "iob_s_port", "descr": "CPU native interface", "ports": []},
            {'name': 'axi_m_port', 'descr':'AXI master interface for external memory.', 'ports': []},
            {
                "name": "general",
                "descr": "General Interface Signals",
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
                        "descr": "System clock enable signal",
                    },
                    {
                        "name": "inta_o",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Interrupt Output A",
                    },
                ],
            },
            {
                "name": "phy",
                "descr": "PHY Interface Ports",
                "ports": [
                    {
                        "name": "MTxClk",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Transmit Nibble or Symbol Clock. The PHY provides the MTxClk signal. It operates at a frequency of 25 MHz (100 Mbps) or 2.5 MHz (10 Mbps). The clock is used as a timing reference for the transfer of MTxD[3:0], MtxEn, and MTxErr.",
                    },
                    {
                        "name": "MTxD",
                        "type": "O",
                        "n_bits": "4",
                        "descr": "Transmit Data Nibble. Signals are the transmit data nibbles. They are synchronized to the rising edge of MTxClk. When MTxEn is asserted, PHY accepts the MTxD.",
                    },
                    {
                        "name": "MTxEn",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Transmit Enable. When asserted, this signal indicates to the PHY that the data MTxD[3:0] is valid and the transmission can start. The transmission starts with the first nibble of the preamble. The signal remains asserted until all nibbles to be transmitted are presented to the PHY. It is deasserted prior to the first MTxClk, following the final nibble of a frame.",
                    },
                    {
                        "name": "MTxErr",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Transmit Coding Error. When asserted for one MTxClk clock period while MTxEn is also asserted, this signal causes the PHY to transmit one or more symbols that are not part of the valid data or delimiter set somewhere in the frame being transmitted to indicate that there has been a transmit coding error.",
                    },
                    {
                        "name": "MRxClk",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Receive Nibble or Symbol Clock. The PHY provides the MRxClk signal. It operates at a frequency of 25 MHz (100 Mbps) or 2.5 MHz (10 Mbps). The clock is used as a timing reference for the reception of MRxD[3:0], MRxDV, and MRxErr.",
                    },
                    {
                        "name": "MRxDv",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Receive Data Valid. The PHY asserts this signal to indicate to the Rx MAC that it is presenting the valid nibbles on the MRxD[3:0] signals. The signal is asserted synchronously to the MRxClk. MRxDV is asserted from the first recovered nibble of the frame to the final recovered nibble. It is then deasserted prior to the first MRxClk that follows the final nibble.",
                    },
                    {
                        "name": "MRxD",
                        "type": "I",
                        "n_bits": "4",
                        "descr": "Receive Data Nibble. These signals are the receive data nibble. They are synchronized to the rising edge of MRxClk. When MRxDV is asserted, the PHY sends a data nibble to the Rx MAC. For a correctly interpreted frame, seven bytes of a preamble and a completely formed SFD must be passed across the interface.",
                    },
                    {
                        "name": "MRxErr",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Receive Error. The PHY asserts this signal to indicate to the Rx MAC that a media error was detected during the transmission of the current frame. MRxErr is synchronous to the MRxClk and is asserted for one or more MRxClk clock periods and then deasserted.",
                    },
                    {
                        "name": "MColl",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Collision Detected. The PHY asynchronously asserts the collision signal MColl after the collision has been detected on the media. When deasserted, no collision is detected on the media.",
                    },
                    {
                        "name": "MCrS",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "Carrier Sense. The PHY asynchronously asserts the carrier sense MCrS signal after the medium is detected in a non-idle state. When deasserted, this signal indicates that the media is in an idle state (and the transmission can start).",
                    },
                    {
                        "name": "MDC",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "Management Data Clock. This is a clock for the MDIO serial data channel.",
                    },
                    {
                        "name": "MDIO",
                        "type": "IO",
                        "n_bits": "1",
                        "descr": "Management Data Input/Output. Bi-directional serial data channel for PHY/STA communication.",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_regs(cls):
        cls.regs += [
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
            },
            {
                "name": "iob_eth_bd",
                "descr": "IOb-Eth Buffer Descriptors.",
                "regs": [
                    {
                        "name": "BD",
                        "type": "RW",
                        "n_bits": 32,
                        "rst_val": 0,
                        "addr": 1024,
                        "log2n_items": "BD_NUM_LOG2+1",
                        "autologic": False,
                        "descr": "Buffer descriptors.",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += [
            iob_block_group(
                name="host_if",
                description="Host Interface",
                blocks=[
                    iob_module(
                        name="IFC+CSR",
                        description="Interface Controller (IFC), and Control and Status Registers (CSR)",
                    ),
                    iob_module(
                        name="Buffer Descriptors",
                        description="Internal memory for Buffer Descriptors",
                    ),
                    iob_module(
                        name="TX Buffer",
                        description="Internal storage for immediate frame transfer",
                    ),
                    iob_module(
                        name="RX Buffer",
                        description="Internal storage for immediate frame reception",
                    ),
                    iob_module(
                        name="DMA",
                        description="Direct Memory Access module. Writes received frames to memory and reads frames for transfer.",
                    ),
                ],
            ),
            iob_block_group(
                name="mii_management",
                description="MII Management module",
                blocks=[
                    iob_module(
                        name="Clock generator",
                        description="Divides system clock into slower clock for PHY interface",
                    ),
                    iob_module(
                        name="Operation Controller",
                        description="Control MII read and write operations",
                    ),
                    iob_module(
                        name="Shift Registers",
                        description="Enable serial (MII side) to parallel (host side) communication",
                    ),
                    iob_module(
                        name="Output Control",
                        description="Control MDIO signal. Can be either input or output",
                    ),
                ],
            ),
            iob_block_group(
                name="tx_module",
                description="Frame transfer module",
                blocks=[
                    iob_module(
                        name="Status signals",
                        description="Read and write transfer related signals from CSR and Buffer Descriptors",
                    ),
                    iob_module(
                        name="Frame Pad",
                        description="Add padding to outgoing frames",
                    ),
                    iob_module(
                        name="CRC",
                        description="Calculate Cyclic Redundancy Check (CRC) for outgoing frame",
                    ),
                    iob_module(
                        name="Data nibble",
                        description="Convert data bytes to nibbles",
                    ),
                    iob_module(
                        name="PHY Signals",
                        description="Output PHY TX signals",
                    ),
                ],
            ),
            iob_block_group(
                name="rx_module",
                description="Frame reception module",
                blocks=[
                    iob_module(
                        name="Status signals",
                        description="Read and write reception related signals from CSR and Buffer Descriptors",
                    ),
                    iob_module(
                        name="CRC",
                        description="Verify Cyclic Redundancy Check (CRC) for incoming frame",
                    ),
                    iob_module(
                        name="Preamble removal",
                        description="Detect and remove incoming frame preamble",
                    ),
                    iob_module(
                        name="Data Assembly",
                        description="Convert PHY RX signal into data bytes",
                    ),
                ],
            ),
        ]
