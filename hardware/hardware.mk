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
VHDR+=iob_eth_swreg_def.vh iob_eth_swreg_gen.vh

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

#selec mem modules to import
include $(LIB_DIR)/hardware/iob_reg/hardware.mk
include $(MEM_DIR)/hardware/ram/iob_ram_t2p_asym/hardware.mk

# Verilator simulation
VERILATOR_FLAGS += --unroll-count 4096 # Allow for loop unrolling up to 4096
endif
