RTL_DIR := ../../rtl/src
INCLUDE_DIR := ../../rtl/include
TB_DIR := ../../rtl/testbench
TOP := $(TB_DIR)/iob_eth_tb.v

VC = iverilog
CFLAGS := -W all -I$(INCLUDE_DIR)  -g2005-sv -DVCD -DETH_SIZE=20

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
SRC := $(shell find $(RTL_DIR) -name '*.v') $(TOP)


all: $(SRC) $(VHEADERS)
	$(VC) $(CFLAGS) $(SRC)
	./a.out

clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out

.phony: all clean
