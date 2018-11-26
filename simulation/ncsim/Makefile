RTL_DIR := ../../rtl
INCLUDE_DIR := $(RTL_DIR)

CFLAGS = -errormax 15 -incdir $(INCLUDE_DIR) -status -update -linedebug -sv
EFLAGS = -errormax 15 -access +wc -status
SFLAGS = -errormax 15 -status

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
SRC := $(shell find $(RTL_DIR) -name '*.v')

all: $(SRC) $(HEADERS)
	ncvlog $(CFLAGS) $(SRC)
	ncelab $(EFLAGS) worklib.iob_eth_tb:module
	ncsim  $(SFLAGS) worklib.iob_eth_tb:module

clean:
	@rm -f *#
	@rm -f xtop.tcf
	@rm -f ncsim.key
	@rm -f *.log
	@rm -f *~ 
	@rm -rf INCA_libs
	@rm -f *.vcd

.phony: all clean
