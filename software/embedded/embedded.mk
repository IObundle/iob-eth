#ethernet common parameters
include $(ETHERNET_DIR)/software/software.mk

#submodules
ifneq (INTERCON,$(filter INTERCON, $(SUBMODULES)))
SUBMODULES+=INTERCON
INTERCON_DIR ?=$(DMA_DIR)/submodules/INTERCON
include $(INTERCON_DIR)/software/software.mk
endif

#headers
HDR+=eth_mem_map.h \
eth_frame_struct.h

#embedded sources
SRC+=$(ETHERNET_SW_DIR)/embedded/iob-eth-platform.c

eth_mem_map.h: $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh
	@sed -n 's/`ETH_ADDR_W//p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`/#/g' | sed "s/'d//g" > ./$@

eth_frame_struct.h: $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh
	@sed -n '/ ETH_PREAMBLE /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed "s/8'h/0x/g" | sed 's/`//g' > ./$@
	@sed -n '/ ETH_SFD /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed "s/8'h/0x/g" | sed 's/`//g' >> ./$@
	@sed -n '/ ETH_TYPE_H /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed "s/8'h/0x/g" | sed 's/`//g' >> ./$@
	@sed -n '/ ETH_TYPE_L /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed "s/8'h/0x/g" | sed 's/`//g' >> ./$@
	@echo '' >> ./$@
	@sed -n '/ ETH_NBYTES /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed 's/`//g' >> ./$@
	@echo '' >> ./$@
	@sed -n '/ PREAMBLE_LEN /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed 's/`//g' >> ./$@
	@sed -n '/ MAC_ADDR_LEN /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed 's/`//g' >> ./$@
	@sed -n '/ HDR_LEN /p' $(ETHERNET_DIR)/hardware/include/iob_eth_defs.vh | sed 's/`define/#define/g' | sed 's/`//g' >> ./$@
