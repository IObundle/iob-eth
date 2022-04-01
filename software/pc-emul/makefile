#
# pc-emul/makefile
#
# This makefile overrides some pc-emul/Makefile targets
# copy this file to $(PC_DIR)
#
# Based on the GNU Make manual example:
# https://www.gnu.org/software/make/manual/html_node/Overriding-Makefiles.html
#
# See also:
# https://www.gnu.org/software/make/manual/html_node/Makefile-Names.html
#

ROOT_DIR:=../..
include ../software.mk

#
# Override original targets
#
all: build 
	make -j2 run-parallel

clean:
	@rm -rf soc.log ethernet.log
	@$(MAKE) -f Makefile $@
	
#
# Added targets
#
run-parallel: run-int run-eth-int
	

run-int:
	@$(MAKE) -f Makefile run > soc.log

run-eth-int:
	@$(MAKE) -C $(ETHERNET_DIR) pc-eth > ethernet.log

#
# Run target from original makefile
#
%: force
	@$(MAKE) -f Makefile $@

force: ;
