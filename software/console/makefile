#
# console/GNUmakefile
#
# This makefile overrides some console/Makefile targets
# copy this file to $(CONSOLE_DIR)
#
# Based on the GNU Make manual example:
# https://www.gnu.org/software/make/manual/html_node/Overriding-Makefiles.html
#
# See also:
# https://www.gnu.org/software/make/manual/html_node/Makefile-Names.html
#

ROOT_DIR=../..
include $(ROOT_DIR)/config.mk

#
# Override original targets
#
run: 
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
	make -C $(ETHERNET_DIR) run-eth-scripts > ethernet.log

#
# Run target from original makefile
#
%: force
	@$(MAKE) -f Makefile $@

force: ;
