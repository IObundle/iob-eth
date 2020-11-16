ETHERNET_HW_DIR:=$(ETHERNET_DIR)/hardware

#include
ETHERNET_INC_DIR:=$(ETHERNET_HW_DIR)/include
INCLUDE+=$(incdir) $(ETHERNET_INC_DIR)

#headers
VHDR+=$(wildcard $(ETHERNET_INC_DIR)/*.vh)

#sources
ETHERNET_SRC_DIR:=$(ETHERNET_HW_DIR)/src
VSRC+=$(wildcard $(ETHERNET_SRC_DIR)/*.v)

ifeq ($(SIM),1)
	DEFINE += $(defmacro) SIM
endif
