# SPDX-FileCopyrightText: 2025 IObundle, Lda
#
# SPDX-License-Identifier: MIT
#
# Py2HWSW Version 0.81 has generated this code (https://github.com/IObundle/py2hwsw).

# Clock Enable, Reset
set_input_delay -clock {clk} $clk_i_delay [get_ports {cke_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {arst_i}]
# AXI
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_araddr_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arvalid_o}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_arready_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_rdata_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_rresp_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_rvalid_i}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_rready_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arid_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arlen_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arsize_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arburst_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arlock_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arcache_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_arqos_o}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_rid_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_rlast_i}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awaddr_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awvalid_o}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_awready_i}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_wdata_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_wstrb_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_wvalid_o}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_wready_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_bresp_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_bvalid_i}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_bready_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awid_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awlen_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awsize_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awburst_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awlock_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awcache_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_awqos_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {axi_wlast_o}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {axi_bid_i}]
# Interrupts
set_output_delay -clock {clk} $clk_o_delay [get_ports {inta_o}]
# PHY RSTN
set_output_delay -clock {rx_clk} $eth_o_delay [get_ports {phy_rstn_o}]
# MII interface
set_output_delay -clock {tx_clk} $eth_o_delay [get_ports {mii_txd_o[*]}]
set_output_delay -clock {tx_clk} $eth_o_delay [get_ports {mii_tx_en_o}]
set_output_delay -clock {tx_clk} $eth_o_delay [get_ports {mii_tx_er_o}]
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_rxd_i[*]}]
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_rx_dv_i}]
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_rx_er_i}]
# Currently unused inputs / inouts / outputs
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_crs_i}]
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_col_i}]
set_input_delay -clock {rx_clk} $eth_i_delay [get_ports {mii_mdio_io}]
set_output_delay -clock {rx_clk} $eth_o_delay [get_ports {mii_mdio_io}]
set_output_delay -clock {tx_clk} $eth_o_delay [get_ports {mii_mdc_o}]
# CSRS Interface
set_input_delay -clock {clk} $clk_i_delay [get_ports {csrs_iob_valid_i}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {csrs_iob_addr_i[*]}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {csrs_iob_wdata_i[*]}]
set_input_delay -clock {clk} $clk_i_delay [get_ports {csrs_iob_wstrb_i[*]}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {csrs_iob_rvalid_o}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {csrs_iob_rdata_o[*]}]
set_output_delay -clock {clk} $clk_o_delay [get_ports {csrs_iob_ready_o}]

# Max delays between clock domains
set_max_delay -from {clk} -to {rx_clk} [expr $clk_period * 0.9 ]
set_max_delay -from {rx_clk} -to {clk} [expr $clk_period * 0.9 ]
set_max_delay -from {clk} -to {tx_clk} [expr $clk_period * 0.9 ]
set_max_delay -from {tx_clk} -to {clk} [expr $clk_period * 0.9 ]
