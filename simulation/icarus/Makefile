RTL_DIR := ../../rtl/src
INCLUDE_DIR := ../../rtl/include
TB_DIR := ../../rtl/testbench
TOP := $(TB_DIR)/iob_eth_tb.v

VC = iverilog
CFLAGS := -W all -I$(INCLUDE_DIR)  -g2005-sv -DVCD

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
SRC := $(shell find $(RTL_DIR) -name '*.v') $(TOP)


all: rmac $(SRC) $(VHEADERS)
	$(VC) $(CFLAGS) $(SRC)
	./a.out

rmac:
	sed -i "/ETH_RMAC_ADDR/d" ../../c-driver/iob-eth.h ../../rtl/include/iob_eth_defs.vh
	ifconfig -a | grep -B 1 "ether" | sed '/inet/,+2d' | grep -A 1 ^"en" | grep "ether" | awk '{print $$2}' | sed 's/://g' | sed "s/^/#define ETH_RMAC_ADDR 0x/" >> ../../c-driver/iob-eth.h
	ifconfig -a | grep -B 1 "ether" | sed '/inet/,+2d' | grep -A 1 ^"en" | grep "ether" | awk '{print $$2}' | sed 's/://g' | sed "s/^/\`define ETH_RMAC_ADDR 48'h/" >> ../../rtl/include/iob_eth_defs.vh

clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out
	sed -i "/ETH_RMAC_ADDR/d" ../../c-driver/iob-eth.h ../../rtl/include/iob_eth_defs.vh

.phony: all clean
