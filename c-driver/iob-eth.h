// Preamble
#define ETH_PREAMBLE 0x55

// Start Frame Delimiter
#define ETH_SFD 0xD5

// Frame type
#define ETH_TYPE_H 0x08
#define ETH_TYPE_L 0x00

#define ETH_MAC_ADDR 0x00aa0062c606

// Custom frame size
//#define ETH_SIZE 1152

// Memory map
#define ETH_STATUS           0
#define ETH_CONTROL          1

#define ETH_MAC_ADDR_LO      2
#define ETH_MAC_ADDR_HI      3

#define ETH_RES_PHY          4
#define ETH_DUMMY            5

#define ETH_DATA          2048

//init and test routine
int ethInit(unsigned int);
