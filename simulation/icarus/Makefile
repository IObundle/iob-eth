RTL_DIR := ../../rtl
INCLUDE_DIR := $(RTL_DIR)


VC = iverilog
CFLAGS := -W all -I$(INCLUDE_DIR)  -g2005-sv

VHEADERS := $(shell find $(INCLUDE_DIR) -name '*.vh')
SRC := $(shell find $(RTL_DIR) -name '*.v')


all: $(SRC) $(VHEADERS)
	$(VC) $(CFLAGS) -o $@ $(SRC)
	./$@

clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out

.phony: all clean
