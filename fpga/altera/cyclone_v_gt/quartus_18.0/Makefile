VSRC := \
../../../../rtl/src/iob_eth.v \
../../../../rtl/src/iob_eth_crc.v\
../../../../rtl/src/iob_eth_rx.v \
../../../../rtl/src/iob_eth_tx.v \

INCLUDE := \
../../../../rtl/include/iob_eth_defs.vh\

all: iob_eth-iob_eth.qxp

iob_eth-iob_eth.qxp: $(VSRC) $(INCLUDE)
	quartus_map --read_settings_files=on --write_settings_files=off iob_eth -c iob_eth
	quartus_cdb --read_settings_files=off --write_settings_files=off iob_eth -c iob_eth --merge=on
	quartus_cdb iob_eth -c iob_eth --incremental_compilation_export=iob_eth.qxp --incremental_compilation_export_partition_name=Top --incremental_compilation_export_post_synth=on --incremental_compilation_export_post_fit=off --incremental_compilation_export_routing=on --incremental_compilation_export_flatten=on

clean: 
	quartus_sh --clean iob_eth
	@rm -f *.qarlog *.qws *.qxp *~
	@rm -rf db incremental_db output_files

.PHONY: all clean
