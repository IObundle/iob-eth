#define ETH_PREAMBLE 0x55
#define ETH_SFD 0xD5
#define ETH_TYPE_H 0x60
#define ETH_TYPE_L 0x00

#define ETH_NBYTES (1024-18) // minimum ethernet payload excluding FCS

#define PREAMBLE_LEN 9 // 7 + 2 bytes to align data transfers
#define MAC_ADDR_LEN 6
#define HDR_LEN      (2*MAC_ADDR_LEN + 2)
