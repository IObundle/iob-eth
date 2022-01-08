ETHERNET_DIR:=../../..

defmacro:=-D
incdir:=-I

include ../simulation.mk

DEFINE+=$(defmacro)VCD

VLOG:=iverilog -W all -g2005-sv

run:
	$(VLOG) $(INCLUDE) $(DEFINE) $(VSRC)
	./a.out
	
clean:
	@rm -f *.vcd 
	@rm -f *#
	@rm -f *~ 
	@rm -f a.out

.phony: all clean
