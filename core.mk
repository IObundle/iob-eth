CORE_NAME:=ETHERNET
IS_CORE:=1
USE_NETLIST ?=0
TOP_MODULE:=iob_eth

# Test file for simulation
ETHERNET_SIM_TEST ?= iob_eth_tb.v

# DEFAULT 
ETH_DMA ?= 1
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
ETHERNET_SUBMODULES_DIR:=$(ETHERNET_DIR)/submodules

INTERCON_INC_DIR:=$(ETHERNET_SUBMODULES_DIR)/INTERCON/hardware/include
LIB_INC_DIR:=$(ETHERNET_SUBMODULES_DIR)/LIB/hardware/include

#SUBMODULES
ETHERNET_SUBMODULES:=TEX DMA LIB INTERCON MEM
$(foreach p, $(ETHERNET_SUBMODULES), $(eval $p_DIR ?=$(ETHERNET_SUBMODULES_DIR)/$p))

REMOTE_ROOT_DIR ?=sandbox/iob-eth

#SIMULATION
SIMULATOR ?=icarus
SIM_SERVER ?=localhost
SIM_USER ?=$(USER)
SIM_DIR ?=hardware/simulation/$(SIMULATOR)

#FPGA
FPGA_FAMILY ?=XCKU
FPGA_USER ?=$(USER)
FPGA_SERVER ?=pudim-flan.iobundle.com
ifeq ($(FPGA_FAMILY),XCKU)
        FPGA_COMP:=vivado
        FPGA_PART:=xcku040-fbva676-1-c
else #default; ifeq ($(FPGA_FAMILY),CYCLONEV-GT)
        FPGA_COMP:=quartus
        FPGA_PART:=5CGTFD9E5F35C7
endif
FPGA_DIR ?= $(ETHERNET_DIR)/hardware/fpga/$(FPGA_COMP)
ifeq ($(FPGA_COMP),vivado)
FPGA_LOG:=vivado.log
else ifeq ($(FPGA_COMP),quartus)
FPGA_LOG:=quartus.log
endif

#ASIC
ASIC_NODE ?=umc130
ASIC_SERVER ?=micro5.lx.it.pt
ASIC_COMPILE_ROOT_DIR ?=$(ROOT_DIR)/sandbox/iob-eth
ASIC_USER ?=user14
ASIC_DIR ?=hardware/asic/$(ASIC_NODE)

XILINX ?=1
INTEL ?=1

VERSION = 0.1

VLINE:="V$(VERSION)"
$(CORE_NAME)_version.txt:
ifeq ($(VERSION),)
	$(error "variable VERSION is not set")
endif
	echo $(VLINE) > version.txt
