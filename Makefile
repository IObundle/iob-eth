#
# IObundle, lda: ethernet core
#
SIM_DIR = simulation/icarus
#SIM_DIR = simulation/ncsim
FPGA_DIR=fpga/altera/cyclone_v_gt/quartus_18.0
#
# Build and run the system
#
sim:
	make -C $(SIM_DIR)

fpga:
	make -C $(GT_DIR)

clean:
	make -C $(GT_DIR) clean
	make -C simulation/icarus clean
	make -C simulation/ncsim clean
	$(RM) *~

.PHONY: sim fpga clean
