# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# ----------------------------------------------------------------------------
# IOb_Eth Example Constrain File
#
# This file contains the ethernet core constraints for the AES-KU040-DB-G board.
# ----------------------------------------------------------------------------

set_global_assignment -name SDC_FILE quartus/$BOARD/iob_eth_dev.sdc
# Only timinig constraint from .sdc file is is:
# create_clock -period 40 [get_ports {enet_rx_clk_i}]

set_location_assignment PIN_AN9 -to enet_resetn_o
set_location_assignment PIN_AM10 -to enet_rx_clk_i
set_location_assignment PIN_AP7 -to enet_gtx_clk_o
set_location_assignment PIN_AK14 -to enet_rx_d0_i
set_location_assignment PIN_AL10 -to enet_rx_d1_i
set_location_assignment PIN_AJ14 -to enet_rx_d2_i
set_location_assignment PIN_AK12 -to enet_rx_d3_i
set_location_assignment PIN_AH14 -to enet_rx_dv_i
set_location_assignment PIN_AB14 -to enet_tx_d0_o
set_location_assignment PIN_AD15 -to enet_tx_d1_o
set_location_assignment PIN_AB15 -to enet_tx_d2_o
set_location_assignment PIN_AB13 -to enet_tx_d3_o
set_location_assignment PIN_AC14 -to enet_tx_en_o

set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_resetn_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_clk_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_gtx_clk_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_d0_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_d1_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_d2_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_d3_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_rx_dv_i
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_tx_d0_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_tx_d1_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_tx_d2_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_tx_d3_o
set_instance_assignment -name IO_STANDARD "2.5-V" -to enet_tx_en_o

#Force registers into IOBs
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to *
set_instance_assignment -name FAST_INPUT_REGISTER ON -to *
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to *

