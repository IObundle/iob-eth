# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

CORE := iob_eth

SIMULATOR ?= icarus
SYNTHESIZER ?= yosys
LINTER ?= spyglass
BOARD ?= iob_ku040_db_g
CSR_IF ?= iob

#
# Fill PY_PARAMS if not defined
ifeq ($(PY_PARAMS),)
ifneq ($(CSR_IF),)
PY_PARAMS:=$(PY_PARAMS):csr_if=$(CSR_IF)
endif
# Remove first char (:) from PY_PARAMS
PY_PARAMS:=$(shell echo $(PY_PARAMS) | cut -c2-)
endif # ifndef PY_PARAMS

BUILD_DIR ?= $(shell nix-shell --run "py2hwsw $(CORE) print_build_dir --py_params '$(PY_PARAMS)'")
VERSION ?=$(shell cat $(CORE).py | grep version | cut -d '"' -f 4)

#------------------------------------------------------------
# SETUP
#------------------------------------------------------------

setup:
	nix-shell --run "py2hwsw $(CORE) setup --no_verilog_lint --py_params '$(PY_PARAMS)' $(EXTRA_ARGS)"

.PHONY: setup

#------------------------------------------------------------
# SIMULATION
#------------------------------------------------------------

sim-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-build"

sim-run: clean setup
	nix-shell --run "make -C $(BUILD_DIR) sim-run"

sim-waves:
	nix-shell --run "make -C $(BUILD_DIR) sim-waves"

sim-test: sim-run

.PHONY: sim-build sim-run sim-waves sim-test


# TODO: update targets below
#------------------------------------------------------------
# FPGA
#------------------------------------------------------------

VIVADO_TIMING_SUMMARY=$(BUILD_DIR)/hardware/fpga/reports/*timing_summary.rpt
VIVADO_UTILIZATION=$(BUILD_DIR)/hardware/fpga/reports/*utilization.rpt
VIVADO_LOG=$(BUILD_DIR)/hardware/fpga/reports/*vivado.log

QUARTUS_MAP=$(BUILD_DIR)/hardware/fpga/reports/*map.rpt
QUARTUS_FIT=$(BUILD_DIR)/hardware/fpga/reports/*fit.rpt
QUARTUS_STA=$(BUILD_DIR)/hardware/fpga/reports/*sta.rpt

QUARTUS_FIT_SUMMARY=$(BUILD_DIR)/hardware/fpga/reports/*fit.summary
QUARTUS_STA_SUMMARY=$(BUILD_DIR)/hardware/fpga/reports/*sta.summary

fpga-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR)/ fpga-build BOARD=$(BOARD)"
	set -e; file=$(VIVADO_TIMING_SUMMARY); if [ -f  $(VIVADO_TIMING_SUMMARY) ]; then cp $(VIVADO_TIMING_SUMMARY) ..; fi
	set -e; if [ -f  $(VIVADO_UTILIZATION) ]; then cp $(VIVADO_UTILIZATION) ..; fi
	if [ -f $(VIVADO_LOG) ]; then  grep -i critical $(VIVADO_LOG); fi; sleep 0;
	set -e; if [ -f $(QUARTUS_STA_SUMMARY) ]; then cp $(QUARTUS_STA_SUMMARY) ..; fi
	set -e; if [ -f $(QUARTUS_FIT_SUMMARY) ]; then cp $(QUARTUS_FIT_SUMMARY) ..; fi
	if [ -f $(QUARTUS_MAP) ]; then  grep -i critical $(QUARTUS_MAP); fi; sleep 0;
	if [ -f $(QUARTUS_FIT) ]; then  grep -i critical $(QUARTUS_FIT); fi; sleep 0;
	if [ -f $(QUARTUS_STA) ]; then  grep -i critical $(QUARTUS_STA); fi; sleep 0;

fpga-test:
	make clean setup fpga-build BOARD=iob_aes_ku040_db_g
	make clean setup fpga-build BOARD=iob_cyclonev_gt_dk

.PHONY: fpga-build fpga-test

#------------------------------------------------------------
# SYNTHESIS
#------------------------------------------------------------
syn-build: clean setup
	nix-shell --run "make -C $(BUILD_DIR) syn-build SYNTHESIZER=$(SYNTHESIZER)"

.PHONY: syn-build

#------------------------------------------------------------
# DOCUMENT BUILD
#------------------------------------------------------------
doc-build: clean
	nix-shell --run "make setup && make -C $(BUILD_DIR)/ doc-build"
	#xdg-open $(BUILD_DIR)/document/ug.pdf &

.PHONY: doc-build

PRIVILEGED_CMD = $(shell command -v doas > /dev/null 2>&1 && echo "doas" || command -v sudo > /dev/null 2>&1 && echo "sudo sh -c" || echo "su root -c")

# Create a virtual network interface
ETH_IF ?= eth10
virtual-network-if:
	$(PRIVILEGED_CMD) "modprobe dummy;\
	ip link add $(ETH_IF) type dummy;\
	ifconfig $(ETH_IF) up"

remove-virtual-network-if:
	su root -c "ip link del $(ETH_IF);\
	rmmod dummy"

.PHONY: virtual-network-if remove-virtual-network-if

clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt fusesoc_exports *.core
	@find . -name \*~ -delete

.PHONY: clean

fusesoc-export: clean setup
	nix-shell --run "py2hwsw $(CORE) export_fusesoc --build_dir '$(BUILD_DIR)' --py_params '$(PY_PARAMS)'"

.PHONY: fusesoc-export

define MULTILINE_TEXT
provider:
  name: url
  url: https://github.com/IObundle/iob-eth/releases/latest/download/$(CORE)_V$(VERSION).tar.gz
  filetype: tar
endef

# Generate independent fusesoc .core file. FuseSoC will obtain the Verilog sources from remote url with a pre-built build directory.
export MULTILINE_TEXT
fusesoc-core-file: fusesoc-export
	cp fusesoc_exports/$(CORE).core .
	# Append provider remote url to .core file
	printf "\n%s\n" "$$MULTILINE_TEXT" >> $(CORE).core
	echo "Generated independent $(CORE).core file."

.PHONY: fusesoc-core-file

# Release Artifacts

release-artifacts:
	make fusesoc-export
	tar -czf $(CORE)_V$(VERSION).tar.gz -C ./fusesoc_exports .

.PHONY: release-artifacts
