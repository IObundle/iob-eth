//`define VCD

`define ETH_SIZE 8'd46
`define ETH_ADDR_W 12

`define ETH_MAC_ADDR 48'h01606e11020f
`define ETH_RMAC_ADDR 48'h0123456789ab

// preamble
`define ETH_PREAMBLE 8'h55

// start frame delimiter
`define ETH_SFD 8'hD5

// frame type
`define ETH_TYPE_H 8'h60
`define ETH_TYPE_L 8'h00

`define ETH_NBYTES (1024-18) // minimum ethernet payload excluding FCS

// Frame structure
`define PREAMBLE_LEN 9 // 7 + 2 bytes in order to align frame data
`define MAC_ADDR_LEN 6
`define HDR_LEN      (2*`MAC_ADDR_LEN + 2)

// RX and TX buffer and DMA parameters

`define ETH_RX_BUFFER_START 2 // In order to align frame data, start saving from byte 2 onwards
`define DMA_W_START 4 // First 4 DWORDS are the header, data starts from DWORD 4
`define DMA_R_START 6 // First 6 DWORDS are the template. 

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
