# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

BUILD_DIR ?= ../../../../iob_eth_V0.1.0

# Run iob_eth's mii_management module along with a demo PHY model.
run: 
	make -C ../../.. setup
	nix-shell ../../../ --run 'iverilog -W all -g2005-sv -o miim_sim -I src -I $(BUILD_DIR)/hardware/src $(BUILD_DIR)/hardware/src/iob_eth_mii_management.v  $(BUILD_DIR)/hardware/src/iob_iobuf.v src/iob_miim_tb.v src/iob_phy_model.v; ./miim_sim'

.PHONY: run
