TOP_MODULE=iob_eth

# DEFAULT 
ETH_DMA ?= 0
DDR_MEM ?= 0x80000000

ifeq ($(ETH_DMA),1)
	ifeq ($(DDR_MEM),)
		$(error ETH_DMA set but DDR_MEM not set) 
	endif
endif

#ETHERNET PATHS
ETHERNET_HW_DIR:=$(ETHERNET_DIR)/hardware
ETHERNET_INC_DIR:=$(ETHERNET_HW_DIR)/include
ETHERNET_SRC_DIR:=$(ETHERNET_HW_DIR)/src
ETHERNET_FPGA_DIR:=$(ETHERNET_DIR)/fpga
ETHERNET_SW_DIR:=$(ETHERNET_DIR)/software
ETHERNET_PYTHON_DIR=$(ETHERNET_SW_DIR)/python
ETHERNET_SIM_DIR:=$(ETHERNET_HW_DIR)/simulation
ETHERNET_TB_DIR:=$(ETHERNET_HW_DIR)/testbench
SIM_DIR ?=$(ETHERNET_SIM_DIR)
SUBMODULES_DIR:=$(ETHERNET_DIR)/submodules

# SUBMODULE PATHS
LIB_DIR ?=$(ETHERNET_DIR)/submodules/LIB
MEM_DIR ?=$(ETHERNET_DIR)/submodules/MEM
DMA_DIR ?=$(ETHERNET_DIR)/submodules/DMA
AXI_DIR ?=$(ETHERNET_DIR)/submodules/AXI

#DEFAULT FPGA FAMILY
FPGA_FAMILY ?=CYCLONEV-GT
FPGA_FAMILY_LIST ?=CYCLONEV-GT XCKU

#DEFAULT DOC
DOC ?=pb
DOC_LIST ?=pb ug

# VERSION
VERSION ?=0.1
VLINE ?="V$(VERSION)"
ETHERNET_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
