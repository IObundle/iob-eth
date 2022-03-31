################################################################################
# Ethernet Targets for System top level Makefiles
#
# Include this file or the targets in System top level makefile to run example 
# scripts.
#
################################################################################

#
# PC Emul Targets
#
## Build and run PC-Emul in parallel with Ethernet scripts
pc-emul-eth:
	make -j2 pc-emul-parallel

pc-emul-parallel: pc-emul-int pc-eth-int

# Run pc-emul, write prints to pc-emul.log
pc-emul-int:
	make pc-emul > pc-emul.log

# Run python scripts, write prints to pc-eth.log
pc-eth-int:
	make -C $(ETHERNET_DIR) pc-eth > pc-eth.log


