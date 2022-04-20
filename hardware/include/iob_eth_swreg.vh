//START_SWREG_TABLE ethernet
`IOB_SWREG_R(ETH_STATUS, 32, 0) //Ethernet core status flags.
`IOB_SWREG_W(ETH_SEND, 1, 0) //Trigger send operation.
`IOB_SWREG_W(ETH_RCVACK, 1, 0) //Acknowledge frame reception.
`IOB_SWREG_W(ETH_SOFTRST, 1, 0) //Reset ethernet core.
`IOB_SWREG_W(ETH_DUMMY_W, 32, 0) //Dummy SWREG for writting configuration.
`IOB_SWREG_R(ETH_DUMMY_R, 32, 0) //Dummy SWREG for reading configuration.
`IOB_SWREG_W(ETH_TX_NBYTES, 11, 46) //Number of bytes for outcomming frames. 
`IOB_SWREG_R(ETH_CRC, 32, 0) //CRC of last received frame.
`IOB_SWREG_R(ETH_RCV_SIZE, 11, 0) //Number of bytes of last received frame.
`IOB_SWMEM_W(ETH_DATA_WR, 8, 11) //TX Buffer.
`IOB_SWMEM_R(ETH_DATA_RD, 32, 9) //RX Buffer.
