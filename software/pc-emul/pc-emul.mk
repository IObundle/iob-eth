ifeq ($(filter ETHERNET, $(SW_MODULES)),)

#add itself to MODULES list
SW_MODULES+=ETHERNET

#ethernet common parameters
include $(ETHERNET_DIR)/software/software.mk

#embedded headers
HDR+=$(ETHERNET_SW_DIR)/pc-emul/iob-eth-platform.h
INCLUDE+=$(incdir)$(ETHERNET_SW_DIR)/pc-emul

endif
