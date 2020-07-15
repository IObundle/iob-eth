RTL_DIR := ../../src
INCLUDE_DIR := ../../include
TB_DIR := ../../testbench
TOP := $(TB_DIR)/iob_eth_tb.v

CFLAGS = -errormax 15 -incdir $(INCLUDE_DIR) -status -update -linedebug -sv -define ETH_SIZE=20 -define VCD
EFLAGS = -errormax 15 -access +wc -status
SFLAGS = -errormax 15 -status

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
VSRC := $(shell find $(RTL_DIR) -name '*.v') $(TOP)

all: rmac $(VSRC) $(VHEADERS)
	VSRC="$(VSRC)" CFLAGS="$(CFLAGS)" EFLAGS="$(EFLAGS)" SFLAGS="$(SFLAGS)" ./setup.sh

#define ETH_RMAC_ADDR for verilog, needs env variable RMAC_INTERFACE
rmac:
	$(eval RMAC = $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed "s/://g"))
	$(eval PREFACE = "-DETH_RMAC_ADDR=48")
	$(eval RMAC_DEFINE = $(PREFACE)\'$(RMAC))
	$(eval CFLAGS = $(CFLAGS) $(RMAC_DEFINE))

clean:
	@rm -f *#
	@rm -f xtop.tcf
	@rm -f ncsim.key
	@rm -f *.log
	@rm -f *~ 
	@rm -rf INCA_libs
	@rm -f *.vcd
	@rm -rf xcelium.d

.phony: all clean
