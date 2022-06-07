SHELL:=/bin/bash

ETHERNET_DIR:=.
include config.mk

.PHONY: sim sim-test sim-clean \
	pc-eth run-eth-scripts\
	fpga \
	clean

#
# Build and run the system
#

#
# SIMULATE
#

sim:
	make -C $(SIM_DIR) run

sim-test:
	make -C $(SIM_DIR) test

sim-clean:
	make -C $(SIM_DIR) clean-all

pc-eth:
	$(eval RMAC := $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed 's/://g'))
	PC=1 python3 ./software/example_python.py $(RMAC_INTERFACE) $(RMAC) ./data.bin 2048 ./data2.bin
	rm -f data.bin
	rm -f data2.bin

run-eth-scripts:
	$(eval RMAC := $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed 's/://g'))
	source /opt/pyeth3/bin/activate; python3 ./software/example_python.py $(RMAC_INTERFACE) $(RMAC) ./data.bin 2048 ./data2.bin; deactivate;
	rm -f data.bin
	rm -f data2.bin

fpga:
	make -C $(FPGA_DIR)

clean:
	make -C $(SIM_DIR) clean
	$(RM) *~

