ETHERNET_SW_DIR:=$(ETHERNET_DIR)/software

#include
INCLUDE+=-I$(ETHERNET_SW_DIR)

#headers
HDR+=$(ETHERNET_SW_DIR)/*.h

#define ETH_RMAC_ADDR
ifneq ($(SIM),)
DEFINE+=$(define)ETH_RMAC_ADDR=0x0123456789ab
else
DEFINE+=$(define)ETH_RMAC_ADDR=0x$(RMAC_ADDR)
endif
