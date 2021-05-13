ETHERNET_SW_DIR:=$(ETHERNET_DIR)/software

#include
INCLUDE+=-I$(ETHERNET_SW_DIR)

#headers
HDR+=$(ETHERNET_SW_DIR)/*.h

#sources
SRC+=$(ETHERNET_SW_DIR)/iob-eth.c

#define ETH_RMAC_ADDR
ifneq ($(SIM),)
DEFINE+=$(defmacro)ETH_RMAC_ADDR=0x0123456789ab
else
DEFINE+=$(defmacro)ETH_RMAC_ADDR=0x$(RMAC_ADDR)
endif
