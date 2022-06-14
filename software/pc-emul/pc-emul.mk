#ethernet common parameters
include $(ETHERNET_DIR)/software/software.mk

# add pc-emul sources
SRC+=$(ETHERNET_SW_DIR)/pc-emul/iob_eth_swreg_pc_emul.c

# clean socket file
clean-eth-socket:
	@rm -rf /tmp/tmpLocalSocket
