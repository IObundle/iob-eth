// Preamble
#define ETH_PREAMBLE 0x55

// Start Frame Delimiter
#define ETH_SFD 0xD5

// Frame type
#define ETH_TYPE_H 0x08
#define ETH_TYPE_L 0x00

#define ETH_MAC_ADDR 0x01606e11020f
#define ETH_RMAC_ADDR 0x309c231e624b

//commands
#define ETH_SEND 1
#define ETH_RCV 2

// Memory map
#define ETH_STATUS           0
#define ETH_CONTROL          1

#define ETH_DUMMY            5

#define ETH_TX_NBYTES        6
#define ETH_RX_NBYTES        7


#define ETH_DATA          2048

//init and test routine
int eth_init(void);

void eth_send_frame(char *data_to_send, unsigned int size);
void eth_rcv_frame(char *data_rcv, unsigned int size);
