//START_TABLE sw_ethreg
`SWREG_R(ETH_STATUS, 32, 0) //Ethernet core status.
`SWREG_W(ETH_SEND, 1, 0) //Trigger ethernet transference.

`SWREG_W(ETH_RCVACK, 1, 0) //Signal frame reception
`SWREG_W(ETH_SOFTRST, 1, 0) //Soft reset core.
`SWREG_W(ETH_DUMMY, 32, 0) //Test register write and read. READ+WRITE?

`SWREG_W(ETH_TX_NBYTES, 1, 0) //Number of bytes for sent frames.
`SWREG_W(ETH_RX_NBYTES, 1, 0) //Number of bytes for received frames.

`SWREG_R(ETH_CRC, 32, 0) //CRC value.
`SWREG_R(ETH_RCV_SIZE, 32, 0) //Size of received data frame in bytes.
`SWREG_W(ETH_DMA_ADDRESS, 32, 0) //Address for DMA.
`SWREG_W(ETH_DMA_LEN, 32, 0) //Length for DMA bursts.
`SWREG_W(ETH_DMA_RUN, 1, 0) //Trigger DMA transference.
`SWREG_W(ETH_DATA, 32, 0) //Frame data (either send or receive). READ+WRITE? Default values?
