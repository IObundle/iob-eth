// Start Frame Delimiter 
`define SFD 8'hD5

// Medium Access Control Address
`define MAC_ADDR 48'h00aa0062c606

// machine states
`define IDLE 3'd0
`define L_NIBBLE 3'd1
`define H_NIBBLE 3'd2
`define CHK_CRC 3'd3
