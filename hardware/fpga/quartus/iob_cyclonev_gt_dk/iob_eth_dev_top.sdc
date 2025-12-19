# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

create_clock -name "clk" -add -period 20.0 [get_ports clk_i]

#Constraint Clock Transitions
# RX_CLK is 25MHz for 100Mbps operation according to Texas Instruments DP83867 datasheet
create_clock -name "tx_clk" -period 40 [get_ports {mii_tx_clk_i}]
create_clock -name "rx_clk" -period 40 [get_ports {mii_rx_clk_i}]

# Clock groups
set_clock_groups -asynchronous -group {clk} -group {rx_clk} -group {tx_clk}

# Clock periods
set clk_period 20.0
set eth_period 40.0

# Input delays
set clk_i_delay [expr $clk_period * 0.15]
set eth_i_delay [expr $eth_period * 0.15]

# Output delays
set clk_o_delay [expr $clk_period * 0.05]
set eth_o_delay [expr $eth_period * 0.05]

################################################################################
## Max skew constraints
################################################################################
set_max_skew -from [get_clocks {clk}] -to [get_clocks {rx_clk}] [expr $clk_period * 0.9]
set_max_skew -from [get_clocks {rx_clk}] -to [get_clocks {clk}] [expr $clk_period * 0.9]
set_max_skew -from [get_clocks {clk}] -to [get_clocks {tx_clk}] [expr $clk_period * 0.9]
set_max_skew -from [get_clocks {tx_clk}] -to [get_clocks {clk}] [expr $clk_period * 0.9]

################################################################################
## Reset
#################################################################################
set_false_path -from [get_ports {arst_i}] -to [get_clocks {*}]
