include $(ETHERNET_DIR)/core.mk

#include
INCLUDE+=$(incdir)$(ETHERNET_INC_DIR)

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

VHDR+=$(wildcard $(INTERCON_INC_DIR)/axi.vh)

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

ifeq ($(SIM),1)
    DEFINE+=$(defmacro)SIM
endif

#define ETH_DMA
ifeq ($(ETH_DMA),1)
DEFINE+=$(defmacro)ETH_DMA 
endif