#include "stdint.h"
#include "interconnect.h"
#include "iob-eth.h"
#include "iob-uart.h"

// memory map
#define ETH_STATUS           0
#define ETH_SEND             1
#define ETH_RCVACK           2
#define ETH_SOFTRST          4
#define ETH_DUMMY            5
#define ETH_TX_NBYTES        6
#define ETH_RX_NBYTES        7
#define ETH_CRC              8
#define ETH_DATA          2048

// Frame structure
#define PREAMBLE_SZ 15
#define MAC_ADDR_SZ 6
#define HDR_SZ      (PREAMBLE_SZ + 1 + 2*MAC_ADDR_SZ + 2)

#define PREAMBLE_PTR    0
#define SDF_PTR         (PREAMBLE_PTR + PREAMBLE_SZ)
#define MAC_DEST_PTR    (SDF_PTR + 1)
#define MAC_SRC_PTR     (MAC_DEST_PTR + MAC_ADDR_SZ)
//#define TAG_PTR         (MAC_SRC_PTR + MAC_ADDR_SZ) // Optional - not supported
#define ETH_TYPE_PTR    (MAC_SRC_PTR + MAC_ADDR_SZ)
#define PAYLOAD_PTR     (ETH_TYPE_PTR + 2)
#define CRC(payload_sz) (PAYLOAD_PTR + (payload_sz))

int base;
char HEADER[HDR_SZ];

void eth_init(int base_address) {
  int i;
  uint64_t mac_addr;

  // set base address
  base = base_address;
  
  // Preamble
  for(i=0; i < PREAMBLE_SZ; i++)
    HEADER[PREAMBLE_PTR+i] = ETH_PREAMBLE;

  // SFD
  HEADER[SDF_PTR] = ETH_SFD;

  // dest mac address
#ifdef LOOPBACK
  mac_addr = ETH_MAC_ADDR;
#else
  mac_addr = ETH_RMAC_ADDR;
#endif
  for (i=0; i < MAC_ADDR_SZ; i++) {
    HEADER[MAC_DEST_PTR+i] = mac_addr >> 40;
    mac_addr = mac_addr << 8;
  }

  // source mac address
  mac_addr = ETH_MAC_ADDR;
  for (i=0; i < MAC_ADDR_SZ; i++) {
    HEADER[MAC_SRC_PTR+i] = mac_addr >> 40;
    mac_addr = mac_addr << 8;
  }
  
  // eth type
  HEADER[ETH_TYPE_PTR]   = ETH_TYPE_H;
  HEADER[ETH_TYPE_PTR+1] = ETH_TYPE_L;

  // reset core
  IO_SET(base, ETH_SOFTRST, 1);
  IO_SET(base, ETH_SOFTRST, 0);

  // wait for PHY to produce rx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 3) & 1));
  uart_puts((char *)"Ethernet RX clock detected\n");

  // wait for PLL to lock and produce tx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 15) & 1));
  uart_puts((char*)"Ethernet TX PLL locked\n");

  // set initial payload size to Ethernet minimum excluding FCS
  IO_SET(base, ETH_TX_NBYTES, 46);
  IO_SET(base, ETH_RX_NBYTES, 46);

  // check processor interface
  // write dummy register
  IO_SET(base, ETH_DUMMY, 0xDEADBEEF);

  // set RX frame size
  IO_SET(base, ETH_RX_NBYTES, ETH_NBYTES);

  // read and check result
  if (IO_GET(base, ETH_DUMMY) != 0xDEADBEEF) {
    uart_puts((char*)"Ethernet Init failed\n");
  } else {
    uart_puts((char*)"Ethernet Core Initialized\n");
  }
}

int eth_get_status(void) {
  return (IO_GET(base, ETH_STATUS));
}

int eth_get_status(char field) {
  if (field == ETH_RX_WR_ADDR) {
    return ((IO_GET(base, ETH_STATUS) >> field) & 0xFFF0);
  } else {
    return ((IO_GET(base, ETH_STATUS) >> field) & 0x0001);
  }
}

void eth_set_send(char value) {
  IO_SET(base, ETH_SEND, value);
}

void eth_set_rcvack(char value) {
  IO_SET(base, ETH_RCVACK, value);
}

void eth_set_soft_rst(char value) {
  IO_SET(base, ETH_SOFTRST, value);
}

void eth_set_tx_payload_size(unsigned int size) {
  IO_SET(base, ETH_TX_NBYTES, size);
}

void eth_set_rx_payload_size(unsigned int size) {
  IO_SET(base, ETH_RX_NBYTES, size);
}

int eth_get_crc(void) {
  return (IO_GET(base, ETH_CRC));
}

void eth_set_data(int i, char data) {
  IO_SET(base, (ETH_DATA + HDR_SZ + i), data);
}

char eth_get_data(int i) {
  return (IO_GET(base, (ETH_DATA + i)));
}

void eth_set_header(void) {
  int i;

  for (i=0; i < HDR_SZ; i++) {
    IO_SET(base, (ETH_DATA + i), HEADER[i]);
  }
}
