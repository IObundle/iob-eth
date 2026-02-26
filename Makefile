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
VERSION ?= $(shell nix-shell --run "py2hwsw $(CORE) print_core_version --py_params '$(PY_PARAMS)'")

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

# 
# FuseSoC Targets
#

fusesoc-export: clean setup
	nix-shell --run "py2hwsw $(CORE) export_fusesoc --build_dir '$(BUILD_DIR)' --py_params '$(PY_PARAMS)'"

.PHONY: fusesoc-export

# Check if the target is `fusesoc-core-file` and define variables for it
ifneq ($(filter fusesoc-%,$(MAKECMDGOALS)),)

FS_REPO_NAME := $(subst _,-,$(CORE))-fs

# Get the latest commit hash from the remote repository
# NOTE: If you do not have write permissions to the IObundle repo, change the REPO_URL to your fork
REPO_URL := https://github.com/IObundle/$(FS_REPO_NAME)
$(info FuseSoC repo URL $(REPO_URL))

LATEST_FS_COMMIT = $(shell git ls-remote $(REPO_URL) HEAD | awk '{print $$1}')

# Using .tar.gz file from releases tab. Supported by fusesoc tool, but not yet supported by https://cores.fusesoc.net/
# define MULTILINE_TEXT
# provider:
#   name: url
#   url: https://github.com/IObundle/$(subst _,-,$(CORE))/releases/latest/download/$(CORE)_V$(VERSION).tar.gz
#   filetype: tar
# endef
# Alternative: Using sources from *-fs repo. Supported by fusesoc tool and https://cores.fusesoc.net/
define MULTILINE_TEXT
provider:
  name: github
  user: IObundle
  repo: $(FS_REPO_NAME)
  version: $(LATEST_FS_COMMIT)
endef
export MULTILINE_TEXT

endif

# NOTE: If you want to run this target from ghactions, you need to give it write permissions to the *-fs repo using a Personal Access Token (PAT).
# You need to generate a PAT to acces the *-fs repo:
#  - As org owner/admin of the *-fs repo, go to Settings > Developer settings > Fine-grained tokens > Generate new token.
#    - Select Repository access > Only select repositories (include both source and target repos).
#    - Grant Contents > Read & write (minimum for commits).
# Then you need add that PAT as a secret of this one (so that secrets.TARGET_REPO_PAT) becomes available.
#  - Add the PAT as a secret: Settings > Secrets and variables > Actions > New repository secret (name it e.g., TARGET_REPO_PAT).
# Finally, in the 'env' section of ci.yml, add: `PAT: ${{ secrets.TARGET_REPO_PAT }}`
#  - You can now use this url to have write permissions: `git clone https://x-access-token:${PAT}@github.com/your-org/target-repo.git`
#
# Automatically update *-fs repo with latest sources
fusesoc-update-fs-repo: fusesoc-export
	git clone $(REPO_URL) $(FS_REPO_NAME)
	# Delete all contents except .git directory
	find $(FS_REPO_NAME) -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
	# Copy fusesoc_exports contents to FS_REPO_NAME root
	cp -r fusesoc_exports/* $(FS_REPO_NAME)/
	# Commit and push
	export CUR_COMMIT=$(shell git rev-parse HEAD);\
	cd $(FS_REPO_NAME) && \
	git config user.name "ghactions[bot]" && \
	git config user.email "ci@iobundle.com" && \
	git add . && \
	git commit --allow-empty -m "Auto-update from main repo ($$CUR_COMMIT)" && \
	git push origin main;
	@echo "FS repo updated successfully"

.PHONY: fusesoc-core-file

# Generate standalone FuseSoC .core file that references pre-built sources from a remote source using 'provider' section.
fusesoc-core-file: fusesoc-update-fs-repo # fusesoc-export
	cp fusesoc_exports/$(CORE).core .
	# Append provider remote url to .core file
	printf "\n%s\n" "$$MULTILINE_TEXT" >> $(CORE).core
	echo "Generated independent $(CORE).core file (with 'provider' section)."

.PHONY: fusesoc-core-file

fusesoc-sign: fusesoc-core-file
	mkdir -p fusesoc_sign/lib
	cp $(CORE).core fusesoc_sign/lib
	nix-shell --run "cd fusesoc_sign;\
	fusesoc library add lib;\
	fusesoc core sign $(CORE) ~/.ssh/iob-fusesoc-sign-key\
	"

.PHONY: fusesoc-sign

# Cores published must have a 'description' with less than 256 characters, otherwise it fails to publish to cores.fusesoc.net
fusesoc-publish: fusesoc-sign
	nix-shell --run "cd fusesoc_sign;\
	fusesoc core show $(CORE);\
	fusesoc-publish $(CORE) https://cores.fusesoc.net/\
	"

.PHONY: fusesoc-publish

# Release Artifacts

release-artifacts:
	make fusesoc-export
	tar -czf $(CORE)_V$(VERSION).tar.gz -C ./fusesoc_exports .

.PHONY: release-artifacts
