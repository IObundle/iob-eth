include $(VERSAT_CNN_DIR)/core.mk

#include
INCLUDE+=-I$(ETHERNET_SW_DIR)

#headers
HDR+=$(ETHERNET_SW_DIR)/*.h

#sources
SRC+=$(ETHERNET_SW_DIR)/iob-eth.c

#define ETH_RMAC_ADDR
ifneq ($(SIM),)
DEFINE+=$(defmacro)ETH_RMAC_ADDR=0x001200feaa00
else
DEFINE+=$(defmacro)ETH_RMAC_ADDR=0x$(RMAC_ADDR)
endif
