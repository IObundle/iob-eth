ETHERNET_SW_DIR:=$(ETHERNET_DIR)/software

#include
INCLUDE+=-I$(ETHERNET_SW_DIR)

#headers
HDR+=$(ETHERNET_SW_DIR)/*.h

#define ETH_RMAC_ADDR
DEFINE+=$(define)ETH_RMAC_ADDR=0x$(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed "s/://g")

