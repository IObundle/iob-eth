RTL_DIR := ../../src
INCLUDE_DIR := ../../include
TB_DIR := ../../testbench
TOP := $(TB_DIR)/iob_eth_tb.v

VC = iverilog
CFLAGS := -W all -I$(INCLUDE_DIR)  -g2005-sv -DVCD

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
SRC := $(shell find $(RTL_DIR) -name '*.v') $(TOP)

all: rmac $(SRC) $(VHEADERS)
	$(VC) $(CFLAGS) $(SRC)
	./a.out

#define ETH_RMAC_ADDR for verilog, needs env variable RMAC_INTERFACE
rmac:
	$(eval RMAC = $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed "s/://g"))
	$(eval PREFACE = "-DETH_RMAC_ADDR=48")
	$(eval RMAC_DEFINE = $(PREFACE)\'$(RMAC))
	$(eval CFLAGS = $(CFLAGS) $(RMAC_DEFINE))

clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out

.phony: all clean
