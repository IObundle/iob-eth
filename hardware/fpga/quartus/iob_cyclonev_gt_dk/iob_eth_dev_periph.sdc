# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# ----------------------------------------------------------------------------
# IOb_Eth Example Constrain File
#
# This file contains the ethernet core constraints for the CYCLONEV-GT-DK board.
# ----------------------------------------------------------------------------

#Constraint Clock Transitions
# RX_CLK is 25MHz for 100Mbps operation according to Texas Instruments DP83867 datasheet
create_clock -name "rx_eth_clk" -period 40 [get_ports {enet_rx_clk_i}]
