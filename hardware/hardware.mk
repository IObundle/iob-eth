ifeq ($(filter ETHERNET, $(HW_MODULES)),)
include $(ETHERNET_DIR)/config.mk

USE_NETLIST ?=0

#add itself to MODULES list
HW_MODULES+=ETHERNET

#include submodule's hardware
$(foreach p, $(SUBMODULES), $(if $(filter $p, $(MODULES)),,$(eval include $($p_DIR)/hardware/hardware.mk)))

#include
INCLUDE+=$(incdir)$(ETHERNET_INC_DIR)
INCLUDE+=$(incdir)$(LIB_DIR)/hardware/include
INCLUDE+=$(incdir)$(AXI_DIR)/hardware/include

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

#selec mem modules to import
include $(MEM_DIR)/hardware/ram/iob_ram_t2p/hardware.mk

ifeq ($(SIM),1)
    DEFINE+=$(defmacro)SIM
endif

#define ETH_DMA
ifeq ($(ETH_DMA),1)
DEFINE+=$(defmacro)ETH_DMA 
VSRC+=$(ETHERNET_DIR)/submodules/DMA/hardware/src/dma_transfer.v
endif

# Verilator simulation
VERILATOR_FLAGS += --unroll-count 4096 # Allow for loop unrolling up to 4096
endif
