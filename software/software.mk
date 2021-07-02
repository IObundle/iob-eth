include $(ETHERNET_DIR)/core.mk

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

#define ETH_DMA
ifeq ($(ETH_DMA),1)
DEFINE+=$(defmacro)ETH_DMA 
endif

#define ETH_DEBUG_PRINT
ifeq ($(ETH_DEBUG_PRINT),1)
DEFINE+=$(defmacro)ETH_DEBUG_PRINT
endif

DEFINE+=$(defmacro)DDR_MEM=$(DDR_MEM)