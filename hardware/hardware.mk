include $(ETHERNET_DIR)/core.mk

#include
INCLUDE+=$(incdir)$(ETHERNET_INC_DIR)

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

#sources
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

ifeq ($(SIM),1)
	DEFINE+=$(defmacro)SIM
endif
