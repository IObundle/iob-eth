# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# TODO: this is the iob_eth_dev.sdc
# when iob_eth is top module

create_clock -name "clk" -add -period 10.0 [get_ports clk_i]
set_property CFGBVS VCCO [current_design]
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk_i]

#Constraint Clock Transitions
# RX_CLK is 25MHz for 100Mbps operation according to Texas Instruments DP83867 datasheet
create_clock -name "tx_clk" -period 40 [get_ports {mii_tx_clk_i}]
set_property HD.CLK_SRC BUFGCTRL_X0Y1 [get_ports mii_tx_clk_i]
create_clock -name "rx_clk" -period 40 [get_ports {mii_rx_clk_i}]
set_property HD.CLK_SRC BUFGCTRL_X0Y2 [get_ports mii_rx_clk_i]

# Clock groups
set_clock_groups -asynchronous -group {clk} -group {rx_clk} -group {tx_clk}

# Clock periods
set clk_period 10.0
set eth_period 40.0

# Input delays
set clk_i_delay [expr $clk_period * 0.15]
set eth_i_delay [expr $eth_period * 0.15]

# Output delays
set clk_o_delay [expr $clk_period * 0.05]
set eth_o_delay [expr $eth_period * 0.05]
