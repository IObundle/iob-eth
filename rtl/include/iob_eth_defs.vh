//`define DEBUG
`define ETH_SIZE 20

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

// Custom frame size
//`define ETH_SIZE 11'd1152

// Medium Access Control Addresses
`define ETH_MAC_ADDR_W 48
//`define ETH_MAC_ADDR 48'h00aa0062c606
`define ETH_MAC_ADDR 48'hFF00FF00FF00

// TRX States
`define ETH_IDLE 3'd0
`define ETH_L_NIBBLE 3'd1
`define ETH_H_NIBBLE 3'd2

// Memory map
`define ETH_STATUS           `ETH_ADDR_W'd0
`define ETH_CONTROL          `ETH_ADDR_W'd1
//`define ETH_INTRRPT_EN `ETH_ADDR_W'd2

`define ETH_TX_DATA          `ETH_ADDR_W'h1000

`define ETH_RX_DATA          `ETH_ADDR_W'h1800

`define ETH_MAC_ADDR_LO      `ETH_ADDR_W'd5
`define ETH_MAC_ADDR_HI      `ETH_ADDR_W'd6

`define ETH_DEST_MAC_ADDR_LO `ETH_ADDR_W'd7
`define ETH_DEST_MAC_ADDR_HI `ETH_ADDR_W'd8

`define ETH_SRC_MAC_ADDR_LO  `ETH_ADDR_W'd9
`define ETH_SRC_MAC_ADDR_HI  `ETH_ADDR_W'd10

`define ETH_RES_PHY          `ETH_ADDR_W'd11
`define ETH_DUMMY            `ETH_ADDR_W'd12

// Memory type
`define ETH_ALT_MEM_TYPE
