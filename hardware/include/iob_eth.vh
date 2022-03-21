//`define VCD

`define ETH_SIZE 8'd46

`define ETH_MAC_ADDR 48'h01606e11020f
`define ETH_RMAC_ADDR 48'h0123456789ab

// preamble
`define ETH_PREAMBLE 8'h55

// start frame delimiter
`define ETH_SFD 8'hD5

// frame type
`define ETH_TYPE_H 8'h60
`define ETH_TYPE_L 8'h00

`define ETH_NBYTES 1500

// Frame structure
`define PREAMBLE_LEN 9 // 7 + 2 bytes in order to align frame data
`define MAC_ADDR_LEN 6
`define HDR_LEN      (2*`MAC_ADDR_LEN + 2)

// RX and TX buffer parameters

`define ETH_RX_BUFFER_START 0 // In order to align frame data, start saving from byte 2 onwards
