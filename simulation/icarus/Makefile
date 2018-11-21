CC = iverilog
CFLAGS = -W all -I. -g2005-sv

SRC = iob_eth_rx.v iob_eth_tx.v iob_eth.v iob_eth_crc.v

TARGET = iob_eth

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC)
	./$@

clean:
	@rm -f *~ $(TARGET) *.vcd 

.phony: clean
