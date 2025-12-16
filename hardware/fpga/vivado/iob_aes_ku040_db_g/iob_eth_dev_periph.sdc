# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# ----------------------------------------------------------------------------
# IOb_Eth Example Constrain File
# This file contains the ethernet core constraints for the AES-KU040-DB-G board.
# ----------------------------------------------------------------------------

#Constraint Clock Transitions
# RX_CLK is 25MHz for 100Mbps operation according to Texas Instruments DP83867 datasheet
create_clock -name "rx_eth_clk" -period 40 [get_ports {enet_rx_clk_i}]

## Ethernet #1 Interface (J1)
set_property PACKAGE_PIN D9 [get_ports enet_resetn_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_resetn_o]

set_property PACKAGE_PIN A10 [get_ports enet_rx_d0_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_d0_i]

set_property PACKAGE_PIN B10 [get_ports enet_rx_d1_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_d1_i]

set_property PACKAGE_PIN B11 [get_ports enet_rx_d2_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_d2_i]

set_property PACKAGE_PIN C11 [get_ports enet_rx_d3_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_d3_i]

set_property PACKAGE_PIN D11 [get_ports enet_rx_dv_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_dv_i]

set_property PACKAGE_PIN E11 [get_ports enet_rx_clk_i]
set_property IOSTANDARD LVCMOS18 [get_ports enet_rx_clk_i]

set_property PACKAGE_PIN H8 [get_ports enet_tx_d0_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_tx_d0_o]

set_property PACKAGE_PIN H9 [get_ports enet_tx_d1_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_tx_d1_o]

set_property PACKAGE_PIN J9 [get_ports enet_tx_d2_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_tx_d2_o]

set_property PACKAGE_PIN J10 [get_ports enet_tx_d3_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_tx_d3_o]

set_property PACKAGE_PIN G9 [get_ports enet_tx_en_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_tx_en_o]

set_property PACKAGE_PIN G10 [get_ports enet_gtx_clk_o]
set_property IOSTANDARD LVCMOS18 [get_ports enet_gtx_clk_o]

set_property IOB TRUE [get_ports enet_tx_d0_o]
set_property IOB TRUE [get_ports enet_tx_d1_o]
set_property IOB TRUE [get_ports enet_tx_d2_o]
set_property IOB TRUE [get_ports enet_tx_d3_o]
set_property IOB TRUE [get_ports enet_tx_en_o]
