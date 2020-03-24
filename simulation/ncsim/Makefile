RTL_DIR := ../../rtl/src
INCLUDE_DIR := ../../rtl/include
TB_DIR := ../../rtl/testbench
TOP := $(TB_DIR)/iob_eth_tb.v

CFLAGS = -errormax 15 -incdir $(INCLUDE_DIR) -status -update -linedebug -sv -define ETH_SIZE=20 -define VCD
EFLAGS = -errormax 15 -access +wc -status
SFLAGS = -errormax 15 -status

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
VSRC := $(shell find $(RTL_DIR) -name '*.v') $(TOP)

all: rmac $(VSRC) $(VHEADERS)
	VSRC="$(VSRC)" CFLAGS="$(CFLAGS)" EFLAGS="$(EFLAGS)" SFLAGS="$(SFLAGS)" ./setup.sh

rmac:
	sed -i "/ETH_RMAC_ADDR/d" ../../c-driver/iob-eth.h ../../rtl/include/iob_eth_defs.vh
	ifconfig -a | grep -B 1 "ether" | sed '/inet/,+2d' | grep -A 1 ^"en" | grep "ether" | awk '{print $$2}' | sed 's/://g' | sed "s/^/#define ETH_RMAC_ADDR 0x/" >> ../../c-driver/iob-eth.h
	ifconfig -a | grep -B 1 "ether" | sed '/inet/,+2d' | grep -A 1 ^"en" | grep "ether" | awk '{print $$2}' | sed 's/://g' | sed "s/^/\`define ETH_RMAC_ADDR 48'h/" >> ../../rtl/include/iob_eth_defs.vh

clean:
	@rm -f *#
	@rm -f xtop.tcf
	@rm -f ncsim.key
	@rm -f *.log
	@rm -f *~ 
	@rm -rf INCA_libs
	@rm -f *.vcd
	@rm -rf xcelium.d
	sed -i "/ETH_RMAC_ADDR/d" ../../c-driver/iob-eth.h ../../rtl/include/iob_eth_defs.vh

.phony: all clean
