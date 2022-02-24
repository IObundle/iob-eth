################################################################################
# Ethernet Targets for System top level Makefiles
#
# Include this file or the targets in System top level makefile to run example 
# scripts.
#
################################################################################

## Run Build, load and run FPGA Console in parallel with Ethernet scripts
fpga-run-eth:
	make -j2 fpga-run-eth-parallel

fpga-eth-parallel: run-fpga-int run-eth-int

# Write FPGA Console prints to fpga.log
run-fpga-int:
	make fpga-run > fpga.log

# Write Ethernet scripts prints to ethernet.log
run-eth-int:
	make run-eth > ethernet.log

# Run iob-eth core example targets
run-eth:
	make -C $(ETHERNET_DIR) run-eth ROOT_DIR=$(ROOT_DIR)/../../ REMOTE_ROOT_DIR=$(REMOTE_ROOT_DIR)
