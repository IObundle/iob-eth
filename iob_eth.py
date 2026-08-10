# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

import shutil
import sys
import os
import subprocess

sys.path.append(f"{os.path.dirname(__file__)}/scripts/")
from gen_custom_config_build import gen_custom_config_build


def setup(py_params_dict):
    PLIC_SOURCE_ID = py_params_dict.get("plic_source_id", 1)
    CSR_IF = py_params_dict["csr_if"] if "csr_if" in py_params_dict else "iob"
    VERSION = "0.1.0"
    gen_custom_config_build(py_params_dict)

    IF_DISPLAY_NAME = {
        "iob": "IOb",
        "axil": "AXI-Lite",
        "wb": "Wishbone",
    }

    # Copy utility files
    if py_params_dict.get("py2hwsw_target", "") == "setup":
        build_dir = py_params_dict["build_dir"]
        # check if eth is top module
        if py_params_dict["issuer"]:
            dev_sdc = "iob_eth_dev_periph.sdc"
        else:
            dev_sdc = "iob_eth_dev_top.sdc"
            # Py2hwsw does not usually give build dir python parameter for top module (only if user defines it via args)
            if not build_dir:
                build_dir = f"../iob_eth_V{VERSION}"
        paths = [
            (
                f"hardware/fpga/vivado/iob_aes_ku040_db_g/{dev_sdc}",
                "hardware/fpga/vivado/iob_aes_ku040_db_g/iob_eth_dev.sdc",
            ),
            (
                f"hardware/fpga/vivado/iob_smart_zynq_sl/{dev_sdc}",
                "hardware/fpga/vivado/iob_smart_zynq_sl/iob_eth_dev.sdc",
            ),
            (
                f"hardware/fpga/quartus/iob_cyclonev_gt_dk/{dev_sdc}",
                "hardware/fpga/quartus/iob_cyclonev_gt_dk/iob_eth_dev.sdc",
            ),
        ]

        for src, dst in paths:
            dst = os.path.join(build_dir, dst)
            dst_dir = os.path.dirname(dst)
            os.makedirs(dst_dir, exist_ok=True)
            shutil.copy2(f"{os.path.dirname(__file__)}/{src}", dst)
            # Hack for Nix: Files copied from Nix's py2hwsw package do not contain write permissions
            os.system("chmod -R ug+w " + dst)

        # Copy all scripts
        dst = os.path.join(build_dir, "scripts")
        shutil.copytree(
            f"{os.path.dirname(__file__)}/scripts",
            dst,
            dirs_exist_ok=True,
        )
        # Hack for Nix: Files copied from Nix's py2hwsw package do not contain write permissions
        os.system("chmod -R ug+w " + dst)

    attributes_dict = {
        "generate_hw": True,
        "description": "IObundle's ethernet core. Driver-compatible with the OpenCores ethmac core, containing a similar Control/Status Register interface. The original sources for this core and public key signature are available at: https://github.com/IObundle/iob-eth.",
        "version": VERSION,
        "board_list": ["iob_aes_ku040_db_g", "iob_cyclonev_gt_dk"],
        "confs": [
            # Macros
            {
                "name": "PREAMBLE",
                "descr": "Ethernet packet preamble value",
                "type": "M",
                "val": "8'h55",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "PREAMBLE_LEN",
                "descr": "Ethernet packet preamble length",
                "type": "M",
                "val": "7",  # Should it be 7 + 2 bytes to align data transfers?
                "max": "NA",
                "min": "NA",
            },
            {
                "name": "SFD",
                "descr": "Start Frame Delimiter",
                "type": "M",
                "val": "8'hD5",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "MAC_ADDR_LEN",
                "descr": "Ethernet MAC address length",
                "type": "M",
                "val": "6",
                "min": "NA",
                "max": "NA",
            },
            # Parameters
            {
                "name": "DATA_W",
                "descr": "Data bus width",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "128",
            },
            # External memory interface
            {
                "name": "AXI_ID_W",
                "descr": "AXI ID bus width",
                "type": "P",
                "val": "1",
                "min": "0",
                "max": "32",
            },
            {
                "name": "AXI_ADDR_W",
                "descr": "AXI address bus width",
                "type": "P",
                "val": "24",
                "min": "1",
                "max": "32",
            },
            {
                "name": "AXI_DATA_W",
                "descr": "AXI data bus width",
                "type": "P",
                "val": "32",
                "min": "1",
                "max": "32",
            },
            {
                "name": "AXI_LEN_W",
                "descr": "AXI burst length width",
                "type": "P",
                "val": "4",
                "min": "1",
                "max": "4",
            },
            # Ethernet
            {
                "name": "PHY_RST_CNT",
                "descr": "PHY reset counter value. Sets the duration of the PHY reset signal. Suggest smaller value during simulation, like 20'h00100.",
                "type": "P",
                # For simulation, use a smaller value, like 20'h00100
                "val": "20'hFFFFF",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "BD_NUM_LOG2",
                "descr": "Log2 amount of buffer descriptors",
                "type": "P",
                "val": "7",
                "min": "NA",
                "max": "7",
            },
            {
                "name": "BUFFER_W",
                "descr": "Buffer size",
                "type": "P",
                "val": "11",
                "min": "0",
                "max": "32",
            },
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
                "name": "axi_m",
                "descr": "AXI manager interface for external memory",
                "signals": {
                    "type": "axi",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                },
            },
            {
                "name": "inta_o",
                "descr": "Interrupt Output",
                "signals": [
                    {
                        "name": "inta_o",
                        "width": 1,
                        "descr": "Interrupt Output A",
                    },
                ],
            },
            {
                "name": "phy_rstn_o",
                "descr": "PHY reset output (active low)",
                "signals": [
                    {
                        "name": "phy_rstn_o",
                        "width": "1",
                        "descr": "Reset signal for PHY. Duration configurable via PHY_RST_CNT parameter.",
                    },
                ],
            },
            {
                "name": "mii_io",
                "descr": "MII interface",
                "signals": [
                    # Same signals as standard "mii" interface, but with custom descriptions.
                    {
                        "name": "mii_tx_clk_i",
                        "width": "1",
                        "descr": "Transmit Nibble or Symbol Clock. The PHY provides the MTxClk signal. It operates at a frequency of 25 MHz (100 Mbps) or 2.5 MHz (10 Mbps). The clock is used as a timing reference for the transfer of MTxD[3:0], MtxEn, and MTxErr.",
                    },
                    {
                        "name": "mii_txd_o",
                        "width": "4",
                        "descr": "Transmit Data Nibble. Signals are the transmit data nibbles. They are synchronized to the rising edge of MTxClk. When MTxEn is asserted, PHY accepts the MTxD.",
                    },
                    {
                        "name": "mii_tx_en_o",
                        "width": "1",
                        "descr": "Transmit Enable. When asserted, this signal indicates to the PHY that the data MTxD[3:0] is valid and the transmission can start. The transmission starts with the first nibble of the preamble. The signal remains asserted until all nibbles to be transmitted are presented to the PHY. It is deasserted prior to the first MTxClk, following the final nibble of a frame.",
                    },
                    {
                        "name": "mii_tx_er_o",
                        "width": "1",
                        "descr": "Transmit Coding Error. When asserted for one MTxClk clock period while MTxEn is also asserted, this signal causes the PHY to transmit one or more symbols that are not part of the valid data or delimiter set somewhere in the frame being transmitted to indicate that there has been a transmit coding error.",
                    },
                    {
                        "name": "mii_rx_clk_i",
                        "width": "1",
                        "descr": "Receive Nibble or Symbol Clock. The PHY provides the MRxClk signal. It operates at a frequency of 25 MHz (100 Mbps) or 2.5 MHz (10 Mbps). The clock is used as a timing reference for the reception of MRxD[3:0], MRxDV, and MRxErr.",
                    },
                    {
                        "name": "mii_rxd_i",
                        "width": "4",
                        "descr": "Receive Data Nibble. These signals are the receive data nibble. They are synchronized to the rising edge of MRxClk. When MRxDV is asserted, the PHY sends a data nibble to the Rx MAC. For a correctly interpreted frame, seven bytes of a preamble and a completely formed SFD must be passed across the interface.",
                    },
                    {
                        "name": "mii_rx_dv_i",
                        "width": "1",
                        "descr": "Receive Data Valid. The PHY asserts this signal to indicate to the Rx MAC that it is presenting the valid nibbles on the MRxD[3:0] signals. The signal is asserted synchronously to the MRxClk. MRxDV is asserted from the first recovered nibble of the frame to the final recovered nibble. It is then deasserted prior to the first MRxClk that follows the final nibble.",
                    },
                    {
                        "name": "mii_rx_er_i",
                        "width": "1",
                        "descr": "Receive Error. The PHY asserts this signal to indicate to the Rx MAC that a media error was detected during the transmission of the current frame. MRxErr is synchronous to the MRxClk and is asserted for one or more MRxClk clock periods and then deasserted.",
                    },
                    {
                        "name": "mii_crs_i",
                        "width": "1",
                        "descr": "Carrier Sense. The PHY asynchronously asserts the carrier sense MCrS signal after the medium is detected in a non-idle state. When deasserted, this signal indicates that the media is in an idle state (and the transmission can start).",
                    },
                    {
                        "name": "mii_col_i",
                        "width": "1",
                        "descr": "Collision Detected. The PHY asynchronously asserts the collision signal MColl after the collision has been detected on the media. When deasserted, no collision is detected on the media.",
                    },
                    {
                        "name": "mii_mdio_io",
                        "width": "1",
                        "descr": "Management Data Input/Output. Bi-directional serial data channel for PHY/STA communication.",
                    },
                    {
                        "name": "mii_mdc_o",
                        "width": "1",
                        "descr": "Management Data Clock. This is a clock for the MDIO serial data channel.",
                    },
                ],
            },
        ],
    }
    # Document all supported CSR interfaces
    for supported_if in ["iob", "axil", "wb"]:
        # CSR_IF has already been documented previously. Only document other supported interfaces.
        if CSR_IF != supported_if:
            attributes_dict["ports"].append(
                {
                    "name": f"csrs_cbus_{supported_if}_s",
                    "doc_only": True,
                    "descr": f"Control and status interface, when selecting the {IF_DISPLAY_NAME[supported_if]} CSR interface.",
                    "signals": {
                        "type": supported_if,
                        "ADDR_W": 12,
                        "DATA_W": "DATA_W",
                        "prefix": "csrs_",
                    },
                },
            )

    #
    # Wires
    #
    attributes_dict |= {
        "wires": [
            {
                "name": "moder",
                "descr": "",
                "signals": [
                    {"name": "moder_wr", "width": 32},
                    {"name": "moder_rd", "width": 32},
                    {"name": "moder_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "int_source",
                "descr": "",
                "signals": [
                    {"name": "int_source_valid_wrrd", "width": 1},
                    {"name": "int_source_wdata_wrrd", "width": 32},
                    {"name": "int_source_wstrb_wrrd", "width": 4},
                    {"name": "int_source_ready_wrrd", "width": 1},
                    {"name": "int_source_rdata_wrrd", "width": 32},
                    {"name": "int_source_rvalid_wrrd", "width": 1},
                ],
            },
            {
                "name": "int_mask",
                "descr": "",
                "signals": [
                    {"name": "int_mask_wr", "width": 32},
                    {"name": "int_mask_rd", "width": 32},
                    {"name": "int_mask_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "ipgt",
                "descr": "",
                "signals": [
                    {"name": "ipgt_wr", "width": 32},
                    {"name": "ipgt_rd", "width": 32},
                    {"name": "ipgt_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "ipgr1",
                "descr": "",
                "signals": [
                    {"name": "ipgr1_wr", "width": 32},
                    {"name": "ipgr1_rd", "width": 32},
                    {"name": "ipgr1_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "ipgr2",
                "descr": "",
                "signals": [
                    {"name": "ipgr2_wr", "width": 32},
                    {"name": "ipgr2_rd", "width": 32},
                    {"name": "ipgr2_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "packetlen",
                "descr": "",
                "signals": [
                    {"name": "packetlen_wr", "width": 32},
                    {"name": "packetlen_rd", "width": 32},
                    {"name": "packetlen_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "collconf",
                "descr": "",
                "signals": [
                    {"name": "collconf_wr", "width": 32},
                    {"name": "collconf_rd", "width": 32},
                    {"name": "collconf_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "tx_bd_num",
                "descr": "",
                "signals": [
                    {"name": "tx_bd_num_wr", "width": 32},
                    {"name": "tx_bd_num_rd", "width": 32},
                    {"name": "tx_bd_num_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "ctrlmoder",
                "descr": "",
                "signals": [
                    {"name": "ctrlmoder_wr", "width": 32},
                    {"name": "ctrlmoder_rd", "width": 32},
                    {"name": "ctrlmoder_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miimoder",
                "descr": "",
                "signals": [
                    {"name": "miimoder_wr", "width": 32},
                    {"name": "miimoder_rd", "width": 32},
                    {"name": "miimoder_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miicommand",
                "descr": "",
                "signals": [
                    {"name": "miicommand_wr", "width": 32},
                    {"name": "miicommand_rd", "width": 32},
                    {"name": "miicommand_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miiaddress",
                "descr": "",
                "signals": [
                    {"name": "miiaddress_wr", "width": 32},
                    {"name": "miiaddress_rd", "width": 32},
                    {"name": "miiaddress_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miitx_data",
                "descr": "",
                "signals": [
                    {"name": "miitx_data_wr", "width": 32},
                    {"name": "miitx_data_rd", "width": 32},
                    {"name": "miitx_data_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miirx_data",
                "descr": "",
                "signals": [
                    {"name": "miirx_data_wr", "width": 32},
                    {"name": "miirx_data_rd", "width": 32},
                    {"name": "miirx_data_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "miistatus",
                "descr": "",
                "signals": [
                    {"name": "miistatus_valid_wrrd", "width": 1},
                    {"name": "miistatus_wdata_wrrd", "width": 32},
                    {"name": "miistatus_wstrb_wrrd", "width": 4},
                    {"name": "miistatus_ready_wrrd", "width": 1},
                    {"name": "miistatus_rdata_wrrd", "width": 32},
                    {"name": "miistatus_rvalid_wrrd", "width": 1},
                ],
            },
            {
                "name": "mac_addr0",
                "descr": "",
                "signals": [
                    {"name": "mac_addr0_wr", "width": 32},
                    {"name": "mac_addr0_rd", "width": 32},
                    {"name": "mac_addr0_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "mac_addr1",
                "descr": "",
                "signals": [
                    {"name": "mac_addr1_wr", "width": 32},
                    {"name": "mac_addr1_rd", "width": 32},
                    {"name": "mac_addr1_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "eth_hash0_adr",
                "descr": "",
                "signals": [
                    {"name": "eth_hash0_adr_wr", "width": 32},
                    {"name": "eth_hash0_adr_rd", "width": 32},
                    {"name": "eth_hash0_adr_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "eth_hash1_adr",
                "descr": "",
                "signals": [
                    {"name": "eth_hash1_adr_wr", "width": 32},
                    {"name": "eth_hash1_adr_rd", "width": 32},
                    {"name": "eth_hash1_adr_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "eth_txctrl",
                "descr": "",
                "signals": [
                    {"name": "eth_txctrl_wr", "width": 32},
                    {"name": "eth_txctrl_rd", "width": 32},
                    {"name": "eth_txctrl_wstrb", "width": 32 // 8},
                ],
            },
            {
                "name": "tx_bd_cnt",
                "descr": "",
                "signals": [
                    {"name": "tx_bd_cnt_valid_rd", "width": 1},
                    {"name": "tx_bd_cnt_rdata_rd", "width": "BD_NUM_LOG2"},
                    {"name": "tx_bd_cnt_ready_rd", "width": 1},
                    {"name": "tx_bd_cnt_rvalid_rd", "width": 1},
                ],
            },
            {
                "name": "rx_bd_cnt",
                "descr": "",
                "signals": [
                    {"name": "rx_bd_cnt_valid_rd", "width": 1},
                    {"name": "rx_bd_cnt_rdata_rd", "width": "BD_NUM_LOG2"},
                    {"name": "rx_bd_cnt_ready_rd", "width": 1},
                    {"name": "rx_bd_cnt_rvalid_rd", "width": 1},
                ],
            },
            {
                "name": "tx_word_cnt",
                "descr": "",
                "signals": [
                    {"name": "tx_word_cnt_valid_rd", "width": 1},
                    {"name": "tx_word_cnt_rdata_rd", "width": "BUFFER_W"},
                    {"name": "tx_word_cnt_ready_rd", "width": 1},
                    {"name": "tx_word_cnt_rvalid_rd", "width": 1},
                ],
            },
            {
                "name": "rx_word_cnt",
                "descr": "",
                "signals": [
                    {"name": "rx_word_cnt_valid_rd", "width": 1},
                    {"name": "rx_word_cnt_rdata_rd", "width": "BUFFER_W"},
                    {"name": "rx_word_cnt_ready_rd", "width": 1},
                    {"name": "rx_word_cnt_rvalid_rd", "width": 1},
                ],
            },
            {
                "name": "rx_nbytes",
                "descr": "",
                "signals": [
                    {"name": "rx_nbytes_valid_rd", "width": 1},
                    {"name": "rx_nbytes_rdata_rd", "width": "BUFFER_W"},
                    {"name": "rx_nbytes_ready_rd", "width": 1},
                    {"name": "rx_nbytes_rvalid_rd", "width": 1},
                ],
            },
            {
                "name": "frame_word",
                "descr": "",
                "signals": [
                    {"name": "frame_word_valid_wrrd", "width": 1},
                    {"name": "frame_word_wdata_wrrd", "width": 8},
                    {"name": "frame_word_wstrb_wrrd", "width": 1},
                    {"name": "frame_word_ready_wrrd", "width": 1},
                    {"name": "frame_word_rdata_wrrd", "width": 8},
                    {"name": "frame_word_rvalid_wrrd", "width": 1},
                ],
            },
            {
                "name": "phy_rst_val",
                "descr": "",
                "signals": [
                    {"name": "phy_rst_val_rd", "width": 1},
                ],
            },
            {
                "name": "bd",
                "descr": "",
                "signals": [
                    {"name": "bd_valid_wrrd", "width": 1},
                    {"name": "bd_addr_wrrd", "width": "BD_NUM_LOG2+1+2"},
                    {"name": "bd_wdata_wrrd", "width": 32},
                    {"name": "bd_wstrb_wrrd", "width": 32 // 8},
                    {"name": "bd_ready_wrrd", "width": 1},
                    {"name": "bd_rdata_wrrd", "width": 32},
                    {"name": "bd_rvalid_wrrd", "width": 1},
                ],
            },
            {
                "name": "internal_signals",
                "descr": "",
                "signals": [
                    {"name": "internal_bd_wen", "width": 1},
                    {"name": "internal_frame_word_wen", "width": 1},
                    {"name": "internal_frame_word_ready_wr", "width": 1},
                    {"name": "internal_frame_word_ren", "width": 1},
                    {"name": "internal_frame_word_ready_rd", "width": 1},
                ],
            },
            # MII management
            {
                "name": "mii_reg",
                "signals": [
                    {"name": "miimoder_wr"},  # mii_moder_i
                    {"name": "miicommand_wr"},  # miicommand_i
                    {"name": "miiaddress_wr"},  # miiaddress_i
                    {"name": "miitx_data_wr"},  # miitx_data_i
                ],
            },
            {
                "name": "mii_status",
                "signals": [
                    # Data/status output
                    {"name": "mii_miirx_data", "width": 32},  # miirx_data_o
                    {"name": "mii_miistatus", "width": 32},  # miistatus_o
                    {"name": "mii_miicommand_clr", "width": 1},  # miicommand_clr_o
                ],
            },
            {
                "name": "mii_management",
                "signals": [
                    {"name": "mii_mdc_o"},
                    {"name": "mii_mdio_io"},
                ],
            },
            # internal wires
            {
                "name": "internal_wires",
                "signals": [
                    {"name": "phy_rst_cnt_o", "width": 21},
                    {"name": "phy_rst", "width": 1},
                ],
            },
            # CDC wires
            {
                "name": "cdc_clks",
                "signals": [
                    {"name": "mii_rx_clk_i"},
                    {"name": "mii_tx_clk_i"},
                ],
            },
            {
                "name": "cdc_phy_rst",
                "signals": [
                    {"name": "phy_rst"},
                    {"name": "rx_phy_rst", "width": 1},
                    {"name": "tx_phy_rst", "width": 1},
                ],
            },
            {
                "name": "cdc_system",
                "signals": [
                    {"name": "send", "width": 1},
                    {"name": "crc_en", "width": 1},
                    {"name": "tx_nbytes", "width": 11},
                    {"name": "tx_ready", "width": 1},
                ],
            },
            {
                "name": "cdc_eth",
                "signals": [
                    {"name": "eth_send", "width": 1},
                    {"name": "eth_crc_en", "width": 1},
                    {"name": "eth_tx_nbytes", "width": 11},
                    {"name": "eth_tx_ready", "width": 1},
                ],
            },
            # Eth logic wires
            {
                "name": "eth_logic",
                "signals": [
                    # CSRs IO
                    # tx_bd_cnt
                    {"name": "tx_bd_cnt_valid_rd"},
                    {"name": "tx_bd_cnt_ready_rd"},
                    {"name": "tx_bd_cnt_rvalid_rd"},
                    # rx_bd_cnt
                    {"name": "rx_bd_cnt_valid_rd"},
                    {"name": "rx_bd_cnt_ready_rd"},
                    {"name": "rx_bd_cnt_rvalid_rd"},
                    # tx_word_cnt
                    {"name": "tx_word_cnt_valid_rd"},
                    {"name": "tx_word_cnt_ready_rd"},
                    {"name": "tx_word_cnt_rvalid_rd"},
                    # rx_word_cnt
                    {"name": "rx_word_cnt_valid_rd"},
                    {"name": "rx_word_cnt_ready_rd"},
                    {"name": "rx_word_cnt_rvalid_rd"},
                    # rx_nbytes
                    {"name": "rx_nbytes_valid_rd"},
                    {"name": "rx_nbytes_ready_rd"},
                    {"name": "rx_nbytes_rvalid_rd"},
                    {"name": "rx_nbytes_rdata_rd"},
                    # frame_word
                    {"name": "frame_word_ready_wrrd"},
                    {"name": "frame_word_wstrb_wrrd"},
                    {"name": "frame_word_valid_wrrd"},
                    {"name": "internal_frame_word_wen"},
                    {"name": "internal_frame_word_ren"},
                    {"name": "internal_frame_word_ready_wr"},
                    {"name": "internal_frame_word_ready_rd"},
                    # bd
                    {"name": "internal_bd_wen"},
                    {"name": "bd_valid_wrrd"},
                    {"name": "bd_wstrb_wrrd"},
                    {"name": "bd_ready_wrrd"},
                    {"name": "bd_rvalid_wrrd"},
                    # rx_nbytes status from Data Transfer block
                    {"name": "rx_nbytes_valid"},
                    {"name": "rx_nbytes", "width": "BUFFER_W"},
                ],
            },
            # Data Transfer wires
            {
                "name": "dt_wires",
                "signals": [
                    # buffer descriptor wires
                    {"name": "dt_bd_en", "width": 1},
                    {"name": "dt_bd_addr", "width": 8},
                    {"name": "dt_bd_wen", "width": 1},
                    {"name": "dt_bd_i", "width": 32},
                    {"name": "dt_bd_o", "width": 32},
                    # interrupt wires
                    {"name": "rx_irq", "width": 1},
                    {"name": "tx_irq", "width": 1},
                ],
            },
            # iob_acc
            {
                "name": "iob_acc_en_rst",
                "signals": [
                    {"name": "phy_rst"},
                    {"name": "iob_acc_rst", "width": 1},
                ],
            },
            {
                "name": "iob_acc_incr",
                "signals": [
                    {"name": "iob_acc_incr", "width": 21},
                ],
            },
            {
                "name": "iob_acc_data",
                "signals": [
                    {"name": "phy_rst_cnt_o"},
                ],
            },
            # TX data FIFO
            {
                "name": "tx_fifo_decl",
                "descr": "TX data FIFO",
                "signals": [
                    {"name": "tx_fifo_w_en", "width": 1},
                    {"name": "tx_fifo_w_data", "width": 8},
                    {"name": "tx_fifo_w_full", "width": 1},
                    {"name": "tx_fifo_w_empty", "width": 1},
                    {"name": "tx_fifo_r_en", "width": 1},
                    {"name": "tx_fifo_r_data", "width": 8},
                    {"name": "tx_fifo_r_empty", "width": 1},
                    {"name": "tx_fifo_ext_mem_w_clk", "width": 1},
                    {"name": "tx_fifo_ext_mem_w_en", "width": 1},
                    {"name": "tx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_w_data", "width": 8},
                    {"name": "tx_fifo_ext_mem_r_clk", "width": 1},
                    {"name": "tx_fifo_ext_mem_r_en", "width": 1},
                    {"name": "tx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_r_data", "width": 8},
                ],
            },
            {
                "name": "tx_fifo_w_clk_en_rst_s",
                "signals": [
                    {"name": "clk_i"},
                    {"name": "cke_i"},
                    {"name": "arst_i"},
                    {"name": "1'b0"},
                    {"name": "tx_fifo_w_en"},
                ],
            },
            {
                "name": "tx_fifo_w_data",
                "signals": [
                    {"name": "tx_fifo_w_data", "width": 8},
                ],
            },
            {
                "name": "tx_fifo_w_full",
                "signals": [
                    {"name": "tx_fifo_w_full"},
                ],
            },
            {
                "name": "tx_fifo_w_empty",
                "signals": [
                    {"name": "tx_fifo_w_empty"},
                ],
            },
            {
                "name": "tx_fifo_r_clk_en_rst_s",
                "signals": [
                    {"name": "mii_tx_clk_i"},
                    {"name": "1'b1"},
                    {"name": "tx_phy_rst"},
                    {"name": "1'b0"},
                    {"name": "tx_fifo_r_en"},
                ],
            },
            {
                "name": "tx_fifo_r_data",
                "signals": [
                    {"name": "tx_fifo_r_data", "width": 8},
                ],
            },
            {
                "name": "tx_fifo_r_empty",
                "signals": [
                    {"name": "tx_fifo_r_empty"},
                ],
            },
            {
                "name": "tx_fifo_extmem",
                "signals": [
                    {"name": "tx_fifo_ext_mem_w_clk"},
                    {"name": "tx_fifo_ext_mem_w_en"},
                    {"name": "tx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_w_data", "width": 8},
                    {"name": "tx_fifo_ext_mem_r_clk"},
                    {"name": "tx_fifo_ext_mem_r_en"},
                    {"name": "tx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_r_data", "width": 8},
                ],
            },
            {
                "name": "tx_fifo_ram",
                "signals": [
                    {"name": "tx_fifo_ext_mem_r_clk"},
                    {"name": "tx_fifo_ext_mem_r_en"},
                    {"name": "tx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_r_data", "width": 8},
                    {"name": "tx_fifo_ext_mem_w_clk"},
                    {"name": "tx_fifo_ext_mem_w_en"},
                    {"name": "tx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "tx_fifo_ext_mem_w_data", "width": 8},
                ],
            },
            {
                "name": "tx_fifo_io",
                "signals": [
                    {"name": "tx_fifo_r_en"},
                    {"name": "tx_fifo_r_data", "width": 8},
                ],
            },
            # RX data FIFO
            {
                "name": "rx_fifo_decl",
                "descr": "RX data FIFO",
                "signals": [
                    {"name": "rx_fifo_w_en", "width": 1},
                    {"name": "rx_fifo_w_data", "width": 8},
                    {"name": "rx_fifo_w_empty", "width": 1},
                    {"name": "rx_fifo_r_en", "width": 1},
                    {"name": "rx_fifo_r_data", "width": 8},
                    {"name": "rx_fifo_r_empty", "width": 1},
                    {"name": "rx_fifo_ext_mem_w_clk", "width": 1},
                    {"name": "rx_fifo_ext_mem_w_en", "width": 1},
                    {"name": "rx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_w_data", "width": 8},
                    {"name": "rx_fifo_ext_mem_r_clk", "width": 1},
                    {"name": "rx_fifo_ext_mem_r_en", "width": 1},
                    {"name": "rx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_r_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_w_clk_en_rst_s",
                "signals": [
                    {"name": "mii_rx_clk_i"},
                    {"name": "1'b1"},
                    {"name": "rx_phy_rst"},
                    {"name": "1'b0"},
                    {"name": "rx_fifo_w_en"},
                ],
            },
            {
                "name": "rx_fifo_w_data",
                "signals": [
                    {"name": "rx_fifo_w_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_w_empty",
                "signals": [
                    {"name": "rx_fifo_w_empty"},
                ],
            },
            {
                "name": "rx_fifo_r_clk_en_rst_s",
                "signals": [
                    {"name": "clk_i"},
                    {"name": "cke_i"},
                    {"name": "arst_i"},
                    {"name": "1'b0"},
                    {"name": "rx_fifo_r_en"},
                ],
            },
            {
                "name": "rx_fifo_r_data",
                "signals": [
                    {"name": "rx_fifo_r_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_r_empty",
                "signals": [
                    {"name": "rx_fifo_r_empty"},
                ],
            },
            {
                "name": "rx_fifo_extmem",
                "signals": [
                    {"name": "rx_fifo_ext_mem_w_clk"},
                    {"name": "rx_fifo_ext_mem_w_en"},
                    {"name": "rx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_w_data", "width": 8},
                    {"name": "rx_fifo_ext_mem_r_clk"},
                    {"name": "rx_fifo_ext_mem_r_en"},
                    {"name": "rx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_r_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_ram",
                "signals": [
                    {"name": "rx_fifo_ext_mem_r_clk"},
                    {"name": "rx_fifo_ext_mem_r_en"},
                    {"name": "rx_fifo_ext_mem_r_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_r_data", "width": 8},
                    {"name": "rx_fifo_ext_mem_w_clk"},
                    {"name": "rx_fifo_ext_mem_w_en"},
                    {"name": "rx_fifo_ext_mem_w_addr", "width": "BUFFER_W"},
                    {"name": "rx_fifo_ext_mem_w_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_o",
                "signals": [
                    {"name": "rx_fifo_w_en"},
                    {"name": "rx_fifo_w_data", "width": 8},
                ],
            },
            {
                "name": "rx_fifo_flow_control",
                "signals": [
                    {"name": "rx_fifo_w_empty"},
                ],
            },
            # RX info FIFO
            {
                "name": "info_fifo_decl",
                "descr": "RX info FIFO",
                "signals": [
                    {"name": "rx_info_w_en", "width": 1},
                    {"name": "rx_info_w_data", "width": 12},
                    {"name": "rx_info_w_full", "width": 1},
                    {"name": "rx_info_r_en", "width": 1},
                    {"name": "rx_info_r_data", "width": 12},
                    {"name": "rx_info_r_empty", "width": 1},
                    {"name": "rx_info_ext_mem_w_clk", "width": 1},
                    {"name": "rx_info_ext_mem_w_en", "width": 1},
                    {"name": "rx_info_ext_mem_w_addr", "width": 1},
                    {"name": "rx_info_ext_mem_w_data", "width": 12},
                    {"name": "rx_info_ext_mem_r_clk", "width": 1},
                    {"name": "rx_info_ext_mem_r_en", "width": 1},
                    {"name": "rx_info_ext_mem_r_addr", "width": 1},
                    {"name": "rx_info_ext_mem_r_data", "width": 12},
                ],
            },
            {
                "name": "info_fifo_w_clk_en_rst_s",
                "signals": [
                    {"name": "mii_rx_clk_i"},
                    {"name": "1'b1"},
                    {"name": "rx_phy_rst"},
                    {"name": "1'b0"},
                    {"name": "rx_info_w_en"},
                ],
            },
            {
                "name": "info_fifo_w_data",
                "signals": [
                    {"name": "rx_info_w_data", "width": 12},
                ],
            },
            {
                "name": "info_fifo_w_full",
                "signals": [
                    {"name": "rx_info_w_full"},
                ],
            },
            {
                "name": "info_fifo_r_clk_en_rst_s",
                "signals": [
                    {"name": "clk_i"},
                    {"name": "cke_i"},
                    {"name": "arst_i"},
                    {"name": "1'b0"},
                    {"name": "rx_info_r_en"},
                ],
            },
            {
                "name": "info_fifo_r_data",
                "signals": [
                    {"name": "rx_info_r_data", "width": 12},
                ],
            },
            {
                "name": "info_fifo_r_empty",
                "signals": [
                    {"name": "rx_info_r_empty"},
                ],
            },
            {
                "name": "info_fifo_extmem",
                "signals": [
                    {"name": "rx_info_ext_mem_w_clk"},
                    {"name": "rx_info_ext_mem_w_en"},
                    {"name": "rx_info_ext_mem_w_addr", "width": 1},
                    {"name": "rx_info_ext_mem_w_data", "width": 12},
                    {"name": "rx_info_ext_mem_r_clk"},
                    {"name": "rx_info_ext_mem_r_en"},
                    {"name": "rx_info_ext_mem_r_addr", "width": 1},
                    {"name": "rx_info_ext_mem_r_data", "width": 12},
                ],
            },
            {
                "name": "info_fifo_ram",
                "signals": [
                    {"name": "rx_info_ext_mem_r_clk"},
                    {"name": "rx_info_ext_mem_r_en"},
                    {"name": "rx_info_ext_mem_r_addr", "width": 1},
                    {"name": "rx_info_ext_mem_r_data", "width": 12},
                    {"name": "rx_info_ext_mem_w_clk"},
                    {"name": "rx_info_ext_mem_w_en"},
                    {"name": "rx_info_ext_mem_w_addr", "width": 1},
                    {"name": "rx_info_ext_mem_w_data", "width": 12},
                ],
            },
            {
                "name": "rx_fifo_info",
                "signals": [
                    {"name": "rx_info_w_en"},
                    {"name": "rx_info_w_data", "width": 12},
                    {"name": "rx_info_w_full"},
                ],
            },
            # Transmitter
            {
                "name": "tx_phy_rst",
                "signals": [
                    {"name": "tx_phy_rst"},
                ],
            },
            {
                "name": "tx_dt",
                "signals": [
                    {"name": "eth_send"},
                    {"name": "eth_tx_ready"},
                    {"name": "eth_tx_nbytes"},
                    {"name": "eth_crc_en"},
                ],
            },
            {
                "name": "tx_mii",
                "signals": [
                    {"name": "mii_tx_clk_i"},
                    {"name": "mii_tx_en_o"},
                    {"name": "mii_txd_o"},
                ],
            },
            # Receiver
            {
                "name": "rx_phy_rst",
                "signals": [
                    {"name": "rx_phy_rst"},
                ],
            },
            {
                "name": "rx_mii",
                "signals": [
                    {"name": "mii_rx_clk_i"},
                    {"name": "mii_rx_dv_i"},
                    {"name": "mii_rxd_i"},
                ],
            },
            # tdp wires
            {
                "name": "bd_ram_clk",
                "descr": "clock",
                "signals": [
                    {"name": "clk_i"},
                ],
            },
            {
                "name": "bd_ram_port_a",
                "descr": "Port A",
                "signals": [
                    {"name": "bd_valid_wrrd"},
                    {"name": "internal_bd_wen"},
                    {"name": "bd_ram_port_a_addr", "width": "BD_NUM_LOG2+1"},
                    {"name": "bd_wdata_wrrd"},
                    {"name": "bd_rdata_wrrd"},
                ],
            },
            {
                "name": "bd_ram_port_b",
                "descr": "Port B",
                "signals": [
                    {"name": "dt_bd_en"},
                    {"name": "dt_bd_wen"},
                    {"name": "dt_bd_addr"},
                    {"name": "dt_bd_o"},
                    {"name": "dt_bd_i"},
                ],
            },
            # Data transfer block wires
            {
                "name": "dt_csrs_control",
                "signals": [
                    {"name": "dt_csrs_control_rx_en", "width": 1},
                    {"name": "dt_csrs_control_tx_en", "width": 1},
                    {"name": "dt_csrs_control_tx_bd_num", "width": "BD_NUM_LOG2"},
                ],
            },
            {
                "name": "dt_buffer_descriptors",
                "signals": [
                    {"name": "dt_bd_en"},
                    {"name": "dt_bd_addr"},
                    {"name": "dt_bd_wen"},
                    {"name": "dt_bd_i"},
                    {"name": "dt_bd_o"},
                ],
            },
            {
                "name": "dt_tx_front_end",
                "signals": [
                    {"name": "tx_fifo_w_en"},
                    {"name": "tx_fifo_w_data", "width": 8},
                    {"name": "tx_fifo_w_full"},
                    {"name": "tx_ready"},
                    {"name": "crc_en"},
                    {"name": "tx_nbytes"},
                    {"name": "send"},
                ],
            },
            {
                "name": "dt_rx_back_end",
                "signals": [
                    {"name": "rx_fifo_r_en"},
                    {"name": "rx_fifo_r_data", "width": 8},
                    {"name": "rx_info_r_en"},
                    {"name": "rx_info_r_empty"},
                    {"name": "rx_info_r_data", "width": 12},
                    {"name": "rx_nbytes_valid"},
                    {"name": "rx_nbytes", "width": "BUFFER_W"},
                ],
            },
            {
                "name": "dt_no_dma",
                "signals": [
                    {"name": "tx_bd_cnt_rdata_rd"},
                    {"name": "tx_word_cnt_rdata_rd"},
                    {"name": "internal_frame_word_wen"},
                    {"name": "frame_word_wdata_wrrd"},
                    {"name": "internal_frame_word_ready_wr"},
                    {"name": "rx_bd_cnt_rdata_rd"},
                    {"name": "rx_word_cnt_rdata_rd"},
                    {"name": "internal_frame_word_ren"},
                    {"name": "frame_word_rdata_wrrd"},
                    {"name": "frame_word_rvalid_wrrd"},
                    {"name": "internal_frame_word_ready_rd"},
                ],
            },
            {
                "name": "dt_interrupts",
                "signals": [
                    {"name": "tx_irq"},
                    {"name": "rx_irq"},
                ],
            },
            # Other
        ],
        "subblocks": [
            {
                "core_name": "iob_csrs",
                "instance_name": "csrs",
                "instance_description": "The Control and Status Register block contains registers accessible by the software for controlling the IP core attached as a peripheral.",
                "autoaddr": False,
                "rw_overlap": True,
                "csr_if": CSR_IF,
                "csrs": [
                    {
                        "name": "iob_eth",
                        "descr": "IOb_Eth Software Accessible Registers",
                        "regs": [
                            {
                                # NOTE: The Linux ethmac driver from opencores does not support half-duplex. Only full-duplex. Therefore there is no need to implement half-duplex mode.
                                "name": "moder",
                                "descr": "Mode Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 40960,
                                "addr": 0,
                                "log2n_items": 0,
                            },
                            {
                                "name": "int_source",
                                "descr": "Interrupt Source Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 4,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "int_mask",
                                "descr": "Interrupt Mask Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 8,
                                "log2n_items": 0,
                            },
                            {
                                "name": "ipgt",
                                "descr": "Back to Back Inter Packet Gap Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 18,
                                "addr": 12,
                                "log2n_items": 0,
                            },
                            {
                                "name": "ipgr1",
                                "descr": "Non Back to Back Inter Packet Gap Register 1",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 12,
                                "addr": 16,
                                "log2n_items": 0,
                            },
                            {
                                "name": "ipgr2",
                                "descr": "Non Back to Back Inter Packet Gap Register 2",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 18,
                                "addr": 20,
                                "log2n_items": 0,
                            },
                            {
                                "name": "packetlen",
                                "descr": "Packet Length (minimum and maximum) Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 4195840,
                                "addr": 24,
                                "log2n_items": 0,
                            },
                            {
                                "name": "collconf",
                                "descr": "Collision and Retry Configuration",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 61443,
                                "addr": 28,
                                "log2n_items": 0,
                            },
                            {
                                "name": "tx_bd_num",
                                "descr": "Transmit Buffer Descriptor Number",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 64,
                                "addr": 32,
                                "log2n_items": 0,
                            },
                            {
                                "name": "ctrlmoder",
                                "descr": "Control Module Mode Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 36,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miimoder",
                                "descr": "MII Mode Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 100,
                                "addr": 40,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miicommand",
                                "descr": "MII Command Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 44,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miiaddress",
                                "descr": "MII Address Register. Contains the PHY address and the register within the PHY address",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 48,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miitx_data",
                                "descr": "MII Transmit Data. The data to be transmitted to the PHY",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 52,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miirx_data",
                                "descr": "MII Receive Data. The data received from the PHY",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 56,
                                "log2n_items": 0,
                            },
                            {
                                "name": "miistatus",
                                "descr": "MII Status Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 60,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "mac_addr0",
                                "descr": "MAC Individual Address0. The LSB four bytes of the individual address are written to this register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 64,
                                "log2n_items": 0,
                            },
                            {
                                "name": "mac_addr1",
                                "descr": "MAC Individual Address1. The MSB two bytes of the individual address are written to this register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 68,
                                "log2n_items": 0,
                            },
                            {
                                "name": "eth_hash0_adr",
                                "descr": "HASH0 Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 72,
                                "log2n_items": 0,
                            },
                            {
                                "name": "eth_hash1_adr",
                                "descr": "HASH1 Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 76,
                                "log2n_items": 0,
                            },
                            {
                                "name": "eth_txctrl",
                                "descr": "Transmit Control Register",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 80,
                                "log2n_items": 0,
                            },
                        ],
                    },
                    {
                        "name": "no_dma",
                        "descr": "Data transfer/status registers for use without DMA",
                        "regs": [
                            {
                                "name": "tx_bd_cnt",
                                "descr": "Buffer descriptor number of current TX frame",
                                "mode": "R",
                                "n_bits": "BD_NUM_LOG2",
                                "rst_val": 0,
                                "addr": 84,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "rx_bd_cnt",
                                "descr": "Buffer descriptor number of current RX frame",
                                "mode": "R",
                                "n_bits": "BD_NUM_LOG2",
                                "rst_val": 0,
                                "addr": 88,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "tx_word_cnt",
                                "descr": "Word number of current TX frame",
                                "mode": "R",
                                "n_bits": "BUFFER_W",
                                "rst_val": 0,
                                "addr": 92,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "rx_word_cnt",
                                "descr": "Word number of current RX frame",
                                "mode": "R",
                                "n_bits": "BUFFER_W",
                                "rst_val": 0,
                                "addr": 96,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "rx_nbytes",
                                "descr": "Size of received frame in bytes. Will be zero if no frame has been received. Will reset to zero when cpu completes reading the frame.",
                                "mode": "R",
                                "n_bits": "BUFFER_W",
                                "rst_val": 0,
                                "addr": 100,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                            {
                                "name": "frame_word",
                                "descr": "Frame word to transfer to/from buffer",
                                "mode": "RW",
                                "n_bits": 8,
                                "rst_val": 0,
                                "addr": 104,
                                "log2n_items": 0,
                                "type": "NOAUTO",
                            },
                        ],
                    },
                    {
                        "name": "phy_rst",
                        "descr": "PHY reset control registers",
                        "regs": [
                            {
                                "name": "phy_rst_val",
                                "descr": "Current PHY reset signal value",
                                "mode": "R",
                                "n_bits": 1,
                                "rst_val": 0,
                                "addr": 108,
                                "log2n_items": 0,
                            },
                        ],
                    },
                    {
                        "name": "iob_eth_bd",
                        "descr": "IOb_Eth Buffer Descriptors",
                        "regs": [
                            {
                                "name": "bd",
                                "descr": "Buffer descriptors",
                                "mode": "RW",
                                "n_bits": 32,
                                "rst_val": 0,
                                "addr": 1024,
                                "log2n_items": "BD_NUM_LOG2+1",
                                "type": "NOAUTO",
                            },
                        ],
                    },
                ],
                "connect": {
                    # iob_csrs 'control_if_s' port is connected automatically by py2hwsw
                    "clk_en_rst_s": "clk_en_rst_s",
                    # Register interfaces
                    "moder_io": "moder",
                    "int_source_io": "int_source",
                    "int_mask_io": "int_mask",
                    "ipgt_io": "ipgt",
                    "ipgr1_io": "ipgr1",
                    "ipgr2_io": "ipgr2",
                    "packetlen_io": "packetlen",
                    "collconf_io": "collconf",
                    "tx_bd_num_io": "tx_bd_num",
                    "ctrlmoder_io": "ctrlmoder",
                    "miimoder_io": "miimoder",
                    "miicommand_io": "miicommand",
                    "miiaddress_io": "miiaddress",
                    "miitx_data_io": "miitx_data",
                    "miirx_data_io": "miirx_data",
                    "miistatus_io": "miistatus",
                    "mac_addr0_io": "mac_addr0",
                    "mac_addr1_io": "mac_addr1",
                    "eth_hash0_adr_io": "eth_hash0_adr",
                    "eth_hash1_adr_io": "eth_hash1_adr",
                    "eth_txctrl_io": "eth_txctrl",
                    "tx_bd_cnt_io": "tx_bd_cnt",
                    "rx_bd_cnt_io": "rx_bd_cnt",
                    "tx_word_cnt_io": "tx_word_cnt",
                    "rx_word_cnt_io": "rx_word_cnt",
                    "rx_nbytes_io": "rx_nbytes",
                    "frame_word_io": "frame_word",
                    "phy_rst_val_i": "phy_rst_val",
                    "bd_io": "bd",
                },
            },
            # PHY reset counter
            {
                "core_name": "iob_acc",
                "instance_name": "phy_reset_counter",
                "instance_description": "Counter to generate initial PHY reset signal. Configurable duration based on counter reset value.",
                "parameters": {
                    "DATA_W": "21",
                    "RST_VAL": "21'h100000 | (PHY_RST_CNT - 1)",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "en_rst_i": "iob_acc_en_rst",
                    "incr_i": "iob_acc_incr",
                    "data_o": "iob_acc_data",
                },
            },
            # CDC block
            {
                "core_name": "iob_eth_cdc",
                "instance_name": "cdc",
                "instance_description": "Clock domain crossing block, using internal synchronizers.",
                "parameters": {
                    "BUFFER_W": "BUFFER_W",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "tx_rx_clk_i": "cdc_clks",
                    "phy_rst_io": "cdc_phy_rst",
                    "system_io": "cdc_system",
                    "eth_io": "cdc_eth",
                },
            },
            # Transmitter
            {
                "core_name": "iob_eth_tx",
                "instance_name": "transmitter",
                "instance_description": "Ethernet transmitter that reads payload bytes from a host interface, emits preamble/SFD and payload, computes and appends the CRC, and provides flow-control so the surrounding logic knows when the transmitter is ready for the next frame.",
                "connect": {
                    "arst_i": "tx_phy_rst",
                    "fifo_io": "tx_fifo_io",
                    "dt_io": "tx_dt",
                    "mii_io": "tx_mii",
                },
            },
            # Receiver
            {
                "core_name": "iob_eth_rx",
                "instance_name": "receiver",
                "instance_description": "Ethernet receiver that detects frame start, captures the destination MAC and payload, writes received bytes and a status info word to host FIFOs, and validates the frame with a CRC check.",
                "connect": {
                    "arst_i": "rx_phy_rst",
                    "fifo_o": "rx_fifo_o",
                    "info_io": "rx_fifo_info",
                    "flow_control_i": "rx_fifo_flow_control",
                    "mii_i": "rx_mii",
                },
            },
            # TX data FIFO
            {
                "core_name": "iob_fifo_async",
                "instance_name": "tx_data_fifo",
                "instance_description": "TX data FIFO: written in the system clock domain (Data Transfer block), read in the MII TX clock domain (transmitter).",
                "parameters": {
                    "W_DATA_W": 8,
                    "R_DATA_W": 8,
                    "ADDR_W": "BUFFER_W",
                },
                "connect": {
                    "w_clk_en_rst_s": "tx_fifo_w_clk_en_rst_s",
                    "w_data_i": "tx_fifo_w_data",
                    "w_full_o": "tx_fifo_w_full",
                    "w_empty_o": "tx_fifo_w_empty",
                    "w_level_o": "z",
                    "r_clk_en_rst_s": "tx_fifo_r_clk_en_rst_s",
                    "r_data_o": "tx_fifo_r_data",
                    "r_full_o": "z",
                    "r_empty_o": "tx_fifo_r_empty",
                    "r_level_o": "z",
                    "extmem_io": "tx_fifo_extmem",
                },
            },
            {
                "core_name": "iob_ram_at2p",
                "instance_name": "tx_data_fifo_ram",
                "instance_description": "",
                "parameters": {
                    "ADDR_W": "BUFFER_W",
                    "DATA_W": 8,
                },
                "connect": {
                    "ram_at2p_s": "tx_fifo_ram",
                },
            },
            # RX data FIFO
            {
                "core_name": "iob_fifo_async",
                "instance_name": "rx_data_fifo",
                "instance_description": "RX data FIFO: written in the MII RX clock domain (receiver), read in the system clock domain (Data Transfer block).",
                "parameters": {
                    "W_DATA_W": 8,
                    "R_DATA_W": 8,
                    "ADDR_W": "BUFFER_W",
                },
                "connect": {
                    "w_clk_en_rst_s": "rx_fifo_w_clk_en_rst_s",
                    "w_data_i": "rx_fifo_w_data",
                    "w_full_o": "z",
                    "w_empty_o": "rx_fifo_w_empty",
                    "w_level_o": "z",
                    "r_clk_en_rst_s": "rx_fifo_r_clk_en_rst_s",
                    "r_data_o": "rx_fifo_r_data",
                    "r_full_o": "z",
                    "r_empty_o": "rx_fifo_r_empty",
                    "r_level_o": "z",
                    "extmem_io": "rx_fifo_extmem",
                },
            },
            {
                "core_name": "iob_ram_at2p",
                "instance_name": "rx_data_fifo_ram",
                "instance_description": "",
                "parameters": {
                    "ADDR_W": "BUFFER_W",
                    "DATA_W": 8,
                },
                "connect": {
                    "ram_at2p_s": "rx_fifo_ram",
                },
            },
            # RX info FIFO
            {
                "core_name": "iob_fifo_async",
                "instance_name": "rx_info_fifo",
                "instance_description": "RX info FIFO: carries the frame info word {crc_err, length[10:0]} from the MII RX to the system clock domain.",
                "parameters": {
                    "W_DATA_W": 12,
                    "R_DATA_W": 12,
                    "ADDR_W": 1,
                },
                "connect": {
                    "w_clk_en_rst_s": "info_fifo_w_clk_en_rst_s",
                    "w_data_i": "info_fifo_w_data",
                    "w_full_o": "info_fifo_w_full",
                    "w_empty_o": "z",
                    "w_level_o": "z",
                    "r_clk_en_rst_s": "info_fifo_r_clk_en_rst_s",
                    "r_data_o": "info_fifo_r_data",
                    "r_full_o": "z",
                    "r_empty_o": "info_fifo_r_empty",
                    "r_level_o": "z",
                    "extmem_io": "info_fifo_extmem",
                },
            },
            {
                "core_name": "iob_ram_at2p",
                "instance_name": "rx_info_fifo_ram",
                "instance_description": "",
                "parameters": {
                    "ADDR_W": 1,
                    "DATA_W": 12,
                },
                "connect": {
                    "ram_at2p_s": "info_fifo_ram",
                },
            },
            {
                "core_name": "iob_ram_tdp",
                "instance_name": "buffer_descriptors",
                "instance_description": "Buffer descriptors memory.",
                "parameters": {
                    "ADDR_W": "BD_NUM_LOG2 + 1",
                    "DATA_W": 32,
                    "MEM_NO_READ_ON_WRITE": 1,
                },
                "connect": {
                    "clk_i": "bd_ram_clk",
                    "port_a_io": "bd_ram_port_a",
                    "port_b_io": "bd_ram_port_b",
                },
            },
            # Data transfer
            {
                "core_name": "iob_eth_dt",
                "instance_name": "data_transfer",
                "instance_description": "Manages data transfers between ethernet modules and interfaces.",
                "parameters": {
                    "AXI_ADDR_W": "AXI_ADDR_W",
                    "AXI_DATA_W": "AXI_DATA_W",
                    "AXI_LEN_W": "AXI_LEN_W",
                    "AXI_ID_W": "AXI_ID_W",
                    # "BURST_W": "BURST_W",
                    "BUFFER_W": "`IOB_ETH_BUFFER_W",
                    "BD_ADDR_W": "BD_NUM_LOG2 + 1",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "csrs_control_i": "dt_csrs_control",
                    "buffer_descriptors_io": "dt_buffer_descriptors",
                    "tx_front_end_io": "dt_tx_front_end",
                    "rx_back_end_io": "dt_rx_back_end",
                    "axi_m": "axi_m",
                    "no_dma_io": "dt_no_dma",
                    "interrupts_o": "dt_interrupts",
                },
            },
            # MII Management
            {
                "core_name": "iob_eth_mii_management",
                "instance_name": "mii_management",
                "instance_description": "Controls MII management signals.",
                "parameters": {
                    "FPGA_TOOL": "FPGA_TOOL",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "mii_reg_i": "mii_reg",
                    "mii_status_o": "mii_status",
                    "management_io": "mii_management",
                },
            },
            # No-auto csrs logic
            {
                "core_name": "iob_eth_logic",
                "instance_name": "eth_logic",
                "instance_description": "Extra ethernet logic for interface between CSRs and Data Transfer block.",
                "parameters": {
                    "BUFFER_W": "BUFFER_W",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "eth_logic_io": "eth_logic",
                },
            },
            # For simulation
            {
                "core_name": "iob_tasks",
                "dest_dir": "hardware/simulation/src",
                "instantiate": False,
            },
        ],
        "sw_modules": [
            {
                "core_name": "iob_coverage_analyze",
                "instance_name": "iob_coverage_analyze_inst",
            },
            {
                "core_name": "iob_linux_device_drivers",
                # The 'compatible' property is set as "opencores,ethoc" to match
                # the Linux ethoc driver's of_match_table.
                "compatible_str": "opencores,ethoc",
                # Extra device tree properties specific to this peripheral.
                # See: https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/net/opencores-ethoc.txt
                #
                # NOTE: The 'reg' property is auto-generated with a single memory region for the
                # CSR registers. The opencores,ethoc binding also supports an optional second
                # memory region for dedicated packet RAM. If your design has a separate memory
                # region for packet buffers, it should be added as a second entry:
                #   reg = <BASE_ADDR REG_SIZE PKT_MEM_BASE PKT_MEM_SIZE>;
                # Without it, the Linux ethoc driver allocates DMA coherent buffers automatically.
                "dts_extra_properties": f"""
        // Interrupt parent: phandle to the Platform-Level Interrupt Controller (PLIC).
        // Must match the PLIC peripheral name in the system device tree.
        interrupt-parent = < &PLIC0 >;
        // PLIC source ID for this Ethernet core's interrupt line.
        interrupts = <{PLIC_SOURCE_ID}>;
        // System clock reference, used to compute the MII management (MDIO) clock divider.
        // The driver derives the MDIO clock by dividing this frequency.
        clocks = <&sys_clk>;
        // PHY interface mode. Must match the hardware wiring.
        // Options: "mii", "rmii", "rgmii", "rgmii-id", "rgmii-rxid", "rgmii-txid", "gmii"
        phy-mode = "rgmii-rxid";

        // --- Optional properties below (uncomment as needed) ---

        // MAC address. If omitted, the driver reads it from hardware registers,
        // or generates a random address if the registers are also unset.
        //local-mac-address = [AA BB CC DD EE FF];

        // Reference to an external PHY node (not used when the driver probes
        // PHYs via MDIO bus scanning, which is the default).
        //phy-handle = <&phy0>;

        // MDIO bus with PHY children (needed only with phy-handle above).
        //mdio {{
        //    #address-cells = <1>;
        //    #size-cells = <0>;
        //
        //    phy0: ethernet-phy@1 {{
        //        reg = <1>;
        //    }};
        //}};
""",
            },
        ],
        "snippets": [
            {
                "verilog_code": """
   reg  [31:0] int_source_reg;

   // Interrupt events
   reg         tx_irq_dly;
   reg         rx_irq_dly;
   wire        tx_frame_event;
   wire        rx_frame_event;
   wire [31:0] int_source_set_val;

   // Connect write outputs to read (loopback for SW-writable registers)
   assign moder_rd         = moder_wr;
   assign int_mask_rd      = int_mask_wr;
   assign ipgt_rd          = ipgt_wr;
   assign ipgr1_rd         = ipgr1_wr;
   assign ipgr2_rd         = ipgr2_wr;
   assign packetlen_rd     = packetlen_wr;
   assign collconf_rd      = collconf_wr;
   assign tx_bd_num_rd     = tx_bd_num_wr;
   assign ctrlmoder_rd     = ctrlmoder_wr;
   assign miimoder_rd      = miimoder_wr;
   assign miicommand_rd    = mii_miicommand_clr ? 32'd0 : miicommand_wr;
   assign miiaddress_rd    = miiaddress_wr;
   assign miitx_data_rd    = miitx_data_wr;
    // miirx_data readback comes from MII management module
    assign miirx_data_rd    = mii_miirx_data;
   assign mac_addr0_rd     = mac_addr0_wr;
   assign mac_addr1_rd     = mac_addr1_wr;
   assign eth_hash0_adr_rd = eth_hash0_adr_wr;
   assign eth_hash1_adr_rd = eth_hash1_adr_wr;
   assign eth_txctrl_rd    = eth_txctrl_wr;

   // Core-to-CSR write paths (core can update some registers)
   assign moder_wstrb         = 4'h0;
   assign int_mask_wstrb      = 4'h0;
   assign ipgt_wstrb          = 4'h0;
   assign ipgr1_wstrb         = 4'h0;
   assign ipgr2_wstrb         = 4'h0;
   assign packetlen_wstrb     = 4'h0;
   assign collconf_wstrb      = 4'h0;
   assign tx_bd_num_wstrb     = 4'h0;
   assign ctrlmoder_wstrb     = 4'h0;
   assign miimoder_wstrb      = 4'h0;
   // miicommand is self-cleared by MII management (MII module writes 0 to CSR)
   assign miicommand_wstrb          = mii_miicommand_clr ? 4'hf : 4'h0;
   assign miiaddress_wstrb    = 4'h0;
   assign miitx_data_wstrb    = 4'h0;
    // miirx_data is updated by MII management on frame completion
    assign miirx_data_wstrb    = mii_miicommand_clr ? 4'hf : 4'h0;
   assign mac_addr0_wstrb     = 4'h0;
   assign mac_addr1_wstrb     = 4'h0;
   assign eth_hash0_adr_wstrb = 4'h0;
   assign eth_hash1_adr_wstrb = 4'h0;
   assign eth_txctrl_wstrb    = 4'h0;

   assign mii_tx_er_o      = 1'b0;  //TODO
   //assign ... = mii_rx_er_i;  //TODO

   //assign ... = mii_col_i;  //TODO
   //assign ... = mii_crs_i;  //TODO



   // iob_acc i/o
   assign iob_acc_rst = 1'b0;
   assign iob_acc_incr = -21'd1;

   assign phy_rst = phy_rst_cnt_o[20];
   assign phy_rstn_o     = ~phy_rst;
   assign phy_rst_val_rd = phy_rst;

   // Interrupt controller
   // Edge detection on tx_irq / rx_irq (DT outputs are level)
   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i) begin
         tx_irq_dly <= 1'b0;
         rx_irq_dly <= 1'b0;
      end else if (cke_i) begin
         tx_irq_dly <= tx_irq;
         rx_irq_dly <= rx_irq;
      end
   end
   assign tx_frame_event = tx_irq & ~tx_irq_dly;
   assign rx_frame_event = rx_irq & ~rx_irq_dly;

   // Hardware events to set in int_source
   // bit 0: TXF (frame transmitted)
   // bit 1: TXE (transmit error) - not used yet
   // bit 2: RXF (frame received)
   // bit 3: RXE (receive error) - not used yet
   // bit 4: BUSY (MII busy) - not used as event
   assign int_source_set_val = {27'd0, 1'b0, 1'b0, rx_frame_event, 1'b0, tx_frame_event};

    // int_source register: write-1-to-clear + HW event OR-in
    assign int_source_ready_wrrd  = 1'b1;
    assign int_source_rdata_wrrd  = int_source_reg;

    // Register rvalid to persist through WAIT_RVALID (same pattern as tx_bd_cnt)
    wire int_source_rvalid_nxt = int_source_valid_wrrd & ~(|int_source_wstrb_wrrd);
    reg  int_source_rvalid_wrrd_reg;
    always @(posedge clk_i, posedge arst_i) begin
       if (arst_i)
          int_source_rvalid_wrrd_reg <= 1'b0;
       else if (cke_i)
          int_source_rvalid_wrrd_reg <= int_source_rvalid_nxt;
    end
    assign int_source_rvalid_wrrd = int_source_rvalid_wrrd_reg;

   always @(posedge clk_i, posedge arst_i) begin
      if (arst_i)
         int_source_reg <= 32'd0;
      else if (cke_i) begin
         if (int_source_valid_wrrd && |int_source_wstrb_wrrd)
            int_source_reg <= (int_source_reg & ~int_source_wdata_wrrd) | int_source_set_val;
         else
            int_source_reg <= int_source_reg | int_source_set_val;
      end
   end

    // Combined interrupt output: masked int_source
    assign inta_o = |(int_source_reg & int_mask_wr);

    // miistatus: direct readback from MII management hardware (no register)
    assign miistatus_ready_wrrd  = 1'b1;
    assign miistatus_rdata_wrrd  = mii_miistatus;

    // Register rvalid to persist through WAIT_RVALID (same pattern as tx_bd_cnt)
    wire miistatus_rvalid_nxt = miistatus_valid_wrrd & ~(|miistatus_wstrb_wrrd);
    reg  miistatus_rvalid_wrrd_reg;
    always @(posedge clk_i, posedge arst_i) begin
       if (arst_i)
          miistatus_rvalid_wrrd_reg <= 1'b0;
       else if (cke_i)
          miistatus_rvalid_wrrd_reg <= miistatus_rvalid_nxt;
    end
    assign miistatus_rvalid_wrrd = miistatus_rvalid_wrrd_reg;

   assign bd_ram_port_a_addr = bd_addr_wrrd[2+:(BD_NUM_LOG2+1)];
   assign dt_csrs_control_rx_en = moder_wr[0];
   assign dt_csrs_control_tx_en = moder_wr[1];
   assign dt_csrs_control_tx_bd_num = tx_bd_num_wr[BD_NUM_LOG2-1:0];

""",
            },
        ],
    }

    attributes_dict["superblocks"] = [
        # Simulation wrapper
        {
            "core_name": "iob_eth_sim",
            "dest_dir": "hardware/simulation/src",
            "csr_if": CSR_IF,
        },
    ]

    return attributes_dict
