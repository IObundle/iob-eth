SHELL:=/bin/bash

ETHERNET_DIR:=.
include config.mk

.PHONY: corename \
	sim sim-test sim-clean \
	pc-test-eth test-eth \
	fpga \
	clean

#
# Build and run the system
#

corename:
	@echo "ETHERNET"

#
# SIMULATE
#

sim:
	make -C $(SIM_DIR) run

sim-test:
	make -C $(SIM_DIR) test

sim-clean:
	make -C $(SIM_DIR) clean-all

pc-test-eth:
	PC=1 python ./software/python/ethRcvData.py enp1 112233445566 ./data.bin 2048;
	PC=1 python ./software/python/ethRcvVariableData.py enp1 112233445566 ./data2.bin;
	PC=1 python ./software/python/ethSendData.py enp1 112233445566 ./data.bin;
	PC=1 python ./software/python/ethSendVariableData.py enp1 112233445566 ./data2.bin;
	rm -f data.bin
	rm -f data2.bin

run-eth-scripts:
	$(eval RMAC := $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed 's/://g'))
	source /opt/pyeth3/bin/activate; python ./software/python/ethRcvData.py $(RMAC_INTERFACE) $(RMAC) ./data.bin 2048; deactivate;
	source /opt/pyeth3/bin/activate; python ./software/python/ethRcvVariableData.py $(RMAC_INTERFACE) $(RMAC) ./data2.bin; deactivate;
	source /opt/pyeth3/bin/activate; python ./software/python/ethSendData.py $(RMAC_INTERFACE) $(RMAC) ./data.bin; deactivate;
	source /opt/pyeth3/bin/activate; python ./software/python/ethSendVariableData.py $(RMAC_INTERFACE) $(RMAC) ./data2.bin; deactivate;
	rm -f data.bin
	rm -f data2.bin

test-eth:
ifeq ($(ETH_SERVER),)
	make run-eth-scripts
else
	ssh $(ETH_USER)@$(ETH_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --force --exclude .git $(ROOT_DIR) $(ETH_USER)@$(ETH_SERVER):$(REMOTE_ROOT_DIR)
	bash -c "trap 'make kill-remote-eth' INT TERM KILL; ssh $(ETH_USER)@$(ETH_SERVER) 'cd $(REMOTE_ROOT_DIR)/submodules/ETHERNET; make test-eth'"
endif


kill-remote-eth:
	@$(eval ETH_PROC=pyeth3)
	@echo "INFO: Remote ethernet scripts will be killed"
	ssh $(ETH_USER)@$(ETH_SERVER) 'pkill -f $(ETH_PROC)'

fpga:
	make -C $(FPGA_DIR)

clean:
	make -C $(SIM_DIR) clean
	make -C $(FPGA_DIR) clean
	$(RM) *~

