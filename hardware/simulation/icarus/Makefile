ETHERNET_DIR:=../../..

defmacro:=-D
incdir:=-I

include ../simulation.mk

VC = iverilog
CFLAGS := -W all -g2005-sv $(INCLUDE) -DVCD

all: $(VSRC) $(VHDR)
	$(VC) $(CFLAGS) $(VSRC)
	./a.out

clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out

.phony: all clean
