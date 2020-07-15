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
	make -C $(SIM_DIR)

fpga:
	make -C $(FPGA_DIR)

clean:
	make -C $(SIM_DIR) clean
	make -C $(FPGA_DIR) clean
	$(RM) *~

.PHONY: sim fpga clean
