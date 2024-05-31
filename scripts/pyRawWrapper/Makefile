
all: compile set-capabilities

compile:
	gcc -Wall -lcap pyRawWrapper.c -o pyRawWrapper
	chmod 750 pyRawWrapper

set-capabilities:
	@echo "Setting CAP_NET_RAW capability..."
	sudo setcap cap_net_raw,cap_setpcap=p pyRawWrapper

.PHONY: all compile set-capabilities
