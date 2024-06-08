#
# This file is included in BUILD_DIR/sim/Makefile
#

ifeq ($(SIMULATOR),verilator)

VSRC+=./src/iob_tasks.cpp ./src/iob_eth_swreg_emb_verilator.c

# verilator top module
VTOP:=$(NAME)_mem_wrapper

endif
