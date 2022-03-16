//address width
`define ETH_ADDR_W 12

//address macros
// Memory map
`define ETH_STATUS           `ETH_ADDR_W'd0
`define ETH_SEND             `ETH_ADDR_W'd1
`define ETH_RCVACK           `ETH_ADDR_W'd2
`define ETH_SOFTRST          `ETH_ADDR_W'd4
`define ETH_DUMMY            `ETH_ADDR_W'd5
`define ETH_TX_NBYTES        `ETH_ADDR_W'd6
`define ETH_RX_NBYTES        `ETH_ADDR_W'd7
`define ETH_CRC              `ETH_ADDR_W'd8
`define ETH_RCV_SIZE         `ETH_ADDR_W'd9
`define ETH_DMA_ADDRESS      `ETH_ADDR_W'd10
`define ETH_DMA_LEN          `ETH_ADDR_W'd11
`define ETH_DMA_RUN          `ETH_ADDR_W'd12
`define ETH_DATA             `ETH_ADDR_W'd2048
