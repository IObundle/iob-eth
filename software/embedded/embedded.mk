ifeq ($(filter ETHERNET, $(SW_MODULES)),)

#add itself to MODULES list
SW_MODULES+=ETHERNET

#ethernet common parameters
include $(ETHERNET_DIR)/software/software.mk

# add embedded sources
SRC+=iob_eth_swreg_emb.c

iob_eth_swreg_emb.c: iob_eth_swreg.h
	
endif
