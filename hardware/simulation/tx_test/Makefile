# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

# Standalone testbench for the iob_eth_tx module.
ETH_LIB ?= ../../../../iob_eth_V0.1.0
ETH_SRC := $(ETH_LIB)/hardware/src
ETH_SIM_SRC := $(ETH_LIB)/hardware/simulation/src

SIM := tx_sim

# iob_eth_tx plus the modules it and the testbench depend on.
VSRC := $(ETH_SRC)/iob_eth_tx.v \
	$(ETH_SRC)/iob_eth_crc.v \
	$(ETH_SRC)/iob_fifo_async.v \
	$(ETH_SRC)/iob_gray_counter.v \
	$(ETH_SRC)/iob_gray2bin.v \
	$(ETH_SRC)/iob_sync.v \
	$(ETH_SRC)/iob_asym_converter.v \
	$(ETH_SRC)/iob_reg_ca.v \
	$(ETH_SRC)/iob_reg_cae.v \
	$(ETH_SRC)/iob_reg_car.v \
	$(ETH_SRC)/iob_reg_care.v \
	$(ETH_SRC)/iob_sync_reg_a.v \
	$(ETH_SRC)/iob_ram_at2p.v \
	src/iob_eth_tx_tb.v

VINCS := -I src -I $(ETH_SRC) -I $(ETH_SIM_SRC)

# Compile and run the testbench.
run:
	nix-shell ../../../ --run 'iverilog -W all -g2005-sv -s iob_eth_tx_tb -o $(SIM) $(VINCS) $(VSRC); ./$(SIM)'

clean:
	rm -f $(SIM) *.vcd

.PHONY: run clean
