include $(ETHERNET_DIR)/config.mk

USE_NETLIST ?=0

#add itself to MODULES list
MODULES+=$(shell make -C $(ETHERNET_DIR) corename | grep -v make)

#include submodule's hardware
$(foreach p, $(SUBMODULES), $(if $(filter $p, $(MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#include
INCLUDE+=$(incdir) $(ETHERNET_INC_DIR)

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

VSRC+=$(ETHERNET_DIR)/submodules/MEM/hardware/ram/t2p_ram/iob_t2p_ram.v
VSRC+=$(ETHERNET_DIR)/submodules/DMA/hardware/src/dma_transfer.v

ifeq ($(SIM),1)
    DEFINE+=$(defmacro)SIM
endif

#define ETH_DMA
ifeq ($(ETH_DMA),1)
DEFINE+=$(defmacro)ETH_DMA 
endif
