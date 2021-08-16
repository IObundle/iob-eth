#define ETH_PREAMBLE 0x55
#define ETH_SFD 0xD5
#define ETH_TYPE_H 0x60
#define ETH_TYPE_L 0x00

#define ETH_NBYTES 1500 // minimum ethernet payload excluding FCS  1022,1024,1026,1028 - not receiving last

#define PREAMBLE_LEN 9 // 7 + 2 bytes to align data transfers
#define MAC_ADDR_LEN 6
#define HDR_LEN      (2*MAC_ADDR_LEN + 2)
