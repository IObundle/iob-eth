//`define VCD

`define ETH_SIZE 8'd46
`define ETH_ADDR_W 12

`define ETH_MAC_ADDR 48'h01606e11020f
`define ETH_RMAC_ADDR 48'h0123456789ab

// Memory map
`define ETH_STATUS           `ETH_ADDR_W'd0
`define ETH_SEND             `ETH_ADDR_W'd1
`define ETH_RCVACK           `ETH_ADDR_W'd2
`define ETH_SOFTRST          `ETH_ADDR_W'd4
`define ETH_DUMMY            `ETH_ADDR_W'd5
`define ETH_TX_NBYTES        `ETH_ADDR_W'd6
`define ETH_RX_NBYTES        `ETH_ADDR_W'd7
`define ETH_CRC              `ETH_ADDR_W'd8
`define ETH_DATA             `ETH_ADDR_W'd2048
