// Data and address widths
`define ETH_DATA_W 8
`define ETH_ADDR_W 13
`define ETH_BUF_ADDR_W 11
`define ETH_CRC_W 32

// Preamble
`define ETH_PREAMBLE 8'h55

// Start Frame Delimiter 
`define ETH_SFD 8'hD5

// Frame type
`define ETH_TYPE 8'h08


// Medium Access Control Addresses
`define ETH_MAC_ADDR_W 48
`define ETH_MAC_ADDR 48'h00aa0062c606

// TRX States
`define ETH_IDLE 3'd0
`define ETH_L_NIBBLE 3'd1
`define ETH_H_NIBBLE 3'd2

// Memory map
`define ETH_STATUS `ETH_ADDR_W'd0
`define ETH_CONTROL `ETH_ADDR_W'd1
`define ETH_INTRRPT_EN `ETH_ADDR_W'd2

`define ETH_TX_DATA `ETH_ADDR_W'h1000
`define ETH_TX_NBYTES `ETH_ADDR_W'd3

`define ETH_RX_DATA `ETH_ADDR_W'h1800
`define ETH_RX_NBYTES `ETH_ADDR_W'd4

`define ETH_MAC_ADDR_LO  `ETH_ADDR_W'd5
`define ETH_MAC_ADDR_HI  `ETH_ADDR_W'd6

`define ETH_DEST_MAC_ADDR_LO `ETH_ADDR_W'd7
`define ETH_DEST_MAC_ADDR_HI `ETH_ADDR_W'd8

// Memory type
`define ETH_ALT_MEM_TYPE


//Test and its size
`define DEBUG
`define ETH_TEST_SIZE 20

