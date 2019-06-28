//preamble
#define ETH_PREAMBLE 0x55

//start frame delimiter
#define ETH_SFD 0xD5

//frame type
#define ETH_TYPE_H 0x08
#define ETH_TYPE_L 0x00

#define ETH_MAC_ADDR 0x01606e11020f
#define ETH_RMAC_ADDR 0x309c231e624b

//commands

//memory map
#define ETH_STATUS           0
#define ETH_SEND             1
#define ETH_RCVACK           2
#define ETH_SOFTRST          4
#define ETH_DUMMY            5
#define ETH_TX_NBYTES        6
#define ETH_RX_NBYTES        7
#define ETH_CRC              8
#define ETH_DATA          2048

//core functions
void eth_init(int base);
void eth_send_frame(int base, char *data_to_send, unsigned int size);
void eth_rcv_frame(int base, char *data_rcv, unsigned int size);
void eth_set_rx_payload_size(int base, unsigned int size);
void eth_printstatus(int base);
