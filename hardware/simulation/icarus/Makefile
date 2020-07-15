ETHERNET_DIR:=../../..

define:=-D
incdir:=-I

include ../simulation.mk

VC = iverilog
CFLAGS := -W all -g2005-sv $(INCLUDE) -DVCD

all: rmac $(VSRC) $(VHDR)
	$(VC) $(CFLAGS) $(VSRC)
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
