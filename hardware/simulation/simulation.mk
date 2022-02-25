include $(ETHERNET_DIR)/hardware/hardware.mk

VCD ?=1

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

# Testbench sources
VSRC+=$(ETHERNET_TB_DIR)/iob_eth_tb.v
# VSRC+=$(ETHERNET_TB_DIR)/dma_tb.v

all: clean 
	make run

test: clean-testlog test1
	diff -q test.log test.expected

test1: clean
	make run VCD=0 TEST_LOG=">> test.log"

#clean test log only when tests begin
clean-testlog:
	@rm -f test.log

ethernet-sim-clean: 
	@rm -f *~ *.vcd *.v *.vh

clean-all: clean-testlog clean

.PHONY: run \
	test test1 \
	clean-testlog ethernet-sim-clean clean-all
