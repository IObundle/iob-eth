# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# This file is included in BUILD_DIR/sim/Makefile

ifeq ($(SIMULATOR),verilator)

# VSRC+=./src/iob_tasks.cpp ./src/iob_eth_csrs_emb_verilator.c
VLT_SRC+=../../software/src/iob_eth.c
VLT_SRC+=../../software/src/iob_eth_csrs.c
VLT_SRC+=$(wildcard ../../software/simulation/src/*_csrs.c)
VLT_SRC+=../../software/simulation/src/iob_dma.c
VLT_INCLUDES+=-I../../software/src
VLT_INCLUDES+=-I../../software/simulation/src
CPP_INCLUDES+=-I../../../software/src
CPP_INCLUDES+=-I../../../software/simulation/src

# verilator top module
VTOP:=$(NAME)_mem_wrapper

# Custom Coverage Analysis
CUSTOM_COVERAGE_FLAGS=cov_annotated
CUSTOM_COVERAGE_FLAGS+=-E iob_uut.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axistream_in.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axistream_out.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axistream_in_csrs.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axistream_out_csrs.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axis_s_axi_m_read.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axis_s_axi_m.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axis_s_axi_m_write.v
CUSTOM_COVERAGE_FLAGS+=-E iob_dma_csrs.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axis_s_axi_m_read_int.v
CUSTOM_COVERAGE_FLAGS+=-E iob_axis_s_axi_m_write_int.v
CUSTOM_COVERAGE_FLAGS+=-E tb_pbus_split.v
CUSTOM_COVERAGE_FLAGS+=-E iob_dma.v
CUSTOM_COVERAGE_FLAGS+=--waive ethernet_coverage.waiver
CUSTOM_COVERAGE_FLAGS+=--waived-tag
CUSTOM_COVERAGE_FLAGS+=-o ethernet_coverage.rpt

endif
