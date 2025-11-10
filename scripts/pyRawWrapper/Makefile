# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


all: compile set-capabilities

compile:
	gcc -Wall pyRawWrapper.c -o pyRawWrapper -lcap
	chmod 750 pyRawWrapper

PRIVILEGED_CMD = $(shell command -v doas > /dev/null 2>&1 && echo "doas" || command -v sudo > /dev/null 2>&1 && echo "sudo sh -c" || echo "su root -c")

set-capabilities:
	@echo "Setting CAP_NET_RAW capability..."
	$(PRIVILEGED_CMD) "setcap cap_net_raw,cap_setpcap=p pyRawWrapper"

.PHONY: all compile set-capabilities
