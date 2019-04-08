// Preamble
#define ETH_PREAMBLE 0x55

// Start Frame Delimiter
#define ETH_SFD 0xD5

// Frame type
#define ETH_TYPE 0x08

// Custom frame size
//#define ETH_SIZE 1152

// Memory map
#define ETH_STATUS           0
#define ETH_CONTROL          1

#define ETH_MAC_ADDR_LO      3
#define ETH_MAC_ADDR_HI      4

#define ETH_DEST_MAC_ADDR_LO 5
#define ETH_DEST_MAC_ADDR_HI 6

#define ETH_SRC_MAC_ADDR_LO  7
#define ETH_SRC_MAC_ADDR_HI  8

#define ETH_RES_PHY          9
#define ETH_DUMMY            10

#define ETH_TX_DATA          20
#define ETH_RX_DATA          1520

/*Return 0 in case of successful init or -1 in case of failure*/
int ethInit(unsigned int);
