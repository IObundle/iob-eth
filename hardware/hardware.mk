include $(ETHERNET_DIR)/core.mk

#intercon
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
include $(INTERCON_DIR)/hardware/hardware.mk
SUBMODULES+=INTERCON
VHDR+=$(wildcard $(INTERCON_INC_DIR)/axi.vh)
endif

#lib
ifneq (LIB,$(filter LIB, $(SUBMODULES)))
INCLUDE+=$(incdir) $(LIB_DIR)/hardware/include
VHDR+=$(wildcard $(LIB_DIR)/hardware/include/*.vh)
SUBMODULES+=LIB
endif

#dma
ifneq (DMA,$(filter LIB, $(SUBMODULES)))
include $(DMA_DIR)/hardware/hardware.mk
SUBMODULES+=DMA
endif

#include
INCLUDE+=$(incdir) $(ETHERNET_INC_DIR)

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)


ifeq ($(SIM),1)
    DEFINE+=$(defmacro)SIM
endif

#define ETH_DMA
ifeq ($(ETH_DMA),1)
DEFINE+=$(defmacro)ETH_DMA 
endif