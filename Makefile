#
# IObundle, lda: ethernet core
#
SIM_DIR = hardware/simulation/icarus
#SIM_DIR = hardware/simulation/ncsim
FPGA_DIR= hardware/fpga/altera/cyclone_v_gt/quartus_18.0
#
# Build and run the system
#
sim:
	make -C $(SIM_DIR) run

sim-waves: $(SIM_DIR)/../waves.gtkw $(SIM_DIR)/iob_eth.vcd
	gtkwave -a $^ &

$(SIM_DIR)/../waves.gtkw $(SIM_DIR)/iob_eth.vcd:
	make sim INIT_MEM=$(INIT_MEM) USE_DDR=$(USE_DDR) RUN_DDR=$(RUN_DDR) VCD=$(VCD)

pc-test-eth:
	PC=1 python ./software/python//ethRcvData.py enp1 112233445566 ./data.bin 2048;
	PC=1 python ./software/python//ethRcvVariableData.py enp1 112233445566 ./data2.bin;
	PC=1 python ./software/python//ethSendData.py enp1 112233445566 ./data.bin;
	PC=1 python ./software/python//ethSendVariableData.py enp1 112233445566 ./data2.bin;
	rm -f data.bin
	rm -f data2.bin	

test-eth:
	$(eval RMAC := $(shell ethtool -P $(RMAC_INTERFACE) | awk '{print $$3}' | sed 's/://g'))
	@source /opt/pyeth/bin/activate; python ./software/python//ethRcvData.py $(RMAC_INTERFACE) $(RMAC) ./data.bin 2048; deactivate;
	@source /opt/pyeth/bin/activate; python ./software/python//ethRcvVariableData.py $(RMAC_INTERFACE) $(RMAC) ./data2.bin; deactivate;
	@source /opt/pyeth/bin/activate; python ./software/python//ethSendData.py $(RMAC_INTERFACE) $(RMAC) ./data.bin; deactivate;
	@source /opt/pyeth/bin/activate; python ./software/python//ethSendVariableData.py $(RMAC_INTERFACE) $(RMAC) ./data2.bin; deactivate;
	rm -f data.bin
	rm -f data2.bin

fpga:
	make -C $(FPGA_DIR)

clean:
	make -C $(SIM_DIR) clean
	make -C $(FPGA_DIR) clean
	$(RM) *~

.PHONY: sim fpga clean
