#include "stdint.h"
#include "interconnect.h"
#include "iob-eth.h"
#include "eth_mem_map.h"
#include "iob-uart.h"
#include "printf.h"
#include "iob-ila.h"

#define PREAMBLE_PTR     0
#define SDF_PTR          (PREAMBLE_PTR + PREAMBLE_LEN)
#define MAC_DEST_PTR     (SDF_PTR + 1)
#define MAC_SRC_PTR      (MAC_DEST_PTR + MAC_ADDR_LEN)
//#define TAG_PTR          (MAC_SRC_PTR + MAC_ADDR_LEN) // Optional - not supported
#define ETH_TYPE_PTR     (MAC_SRC_PTR + MAC_ADDR_LEN)
#define PAYLOAD_PTR      (ETH_TYPE_PTR + 2)

#define TEMPLATE_LEN     (PAYLOAD_PTR)

// Base address
static int base;

// Frame template
static char TEMPLATE[TEMPLATE_LEN];

//#define ETH_DEBUG_PRINT 1

void eth_init(int base_address) {
  int i,ret;
  uint64_t mac_addr;

  // set base address
  base = base_address;
  
  // Preamble
  for(i=0; i < PREAMBLE_LEN; i++)
    TEMPLATE[PREAMBLE_PTR+i] = ETH_PREAMBLE;

  // SFD
  TEMPLATE[SDF_PTR] = ETH_SFD;

  // dest mac address
#ifdef LOOPBACK
  mac_addr = ETH_MAC_ADDR;
#else
  mac_addr = ETH_RMAC_ADDR;
#endif
  for (i=0; i < MAC_ADDR_LEN; i++) {
    TEMPLATE[MAC_DEST_PTR+i] = mac_addr >> 40;
    mac_addr = mac_addr << 8;
  }

  // source mac address
  mac_addr = ETH_MAC_ADDR;
  for (i=0; i < MAC_ADDR_LEN; i++) {
    TEMPLATE[MAC_SRC_PTR+i] = mac_addr >> 40;
    mac_addr = mac_addr << 8;
  }

  // eth type
  TEMPLATE[ETH_TYPE_PTR]   = ETH_TYPE_H;
  TEMPLATE[ETH_TYPE_PTR+1] = ETH_TYPE_L;

  // reset core
  IO_SET(base, ETH_SOFTRST, 1);
  IO_SET(base, ETH_SOFTRST, 0);

  // wait for PHY to produce rx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 3) & 1));

  #ifdef ETH_DEBUG_PRINT
  uart_puts("Ethernet RX clock detected\n");
  #endif

  // wait for PLL to lock and produce tx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 15) & 1));

  #ifdef ETH_DEBUG_PRINT
  uart_puts("Ethernet TX PLL locked\n");
  #endif

  // set initial payload size to Ethernet minimum excluding FCS
  IO_SET(base, ETH_TX_NBYTES, 46);
  IO_SET(base, ETH_RX_NBYTES, 46);

  eth_init_frame();

  // check processor interface
  // write dummy register
  IO_SET(base, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (IO_GET(base, ETH_DUMMY) != 0xDEADBEEF) {
    #ifdef ETH_DEBUG_PRINT
    uart_puts("Ethernet Init failed\n");
    #endif
  } else {
    #ifdef ETH_DEBUG_PRINT
    uart_puts("Ethernet Core Initialized\n");
    #endif
  }
}

int eth_get_status(void) {
  return (IO_GET(base, ETH_STATUS));
}

int eth_get_status_field(char field) {
  if (field == ETH_RX_WR_ADDR) {
    return ((IO_GET(base, ETH_STATUS) >> field) & 0x7FFF);
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

int eth_get_rcv_size(void) {
  return (IO_GET(base, ETH_RCV_SIZE));
}

char eth_get_data(int i) {
  int data = (IO_GET(base, (ETH_DATA + i / 4)));

  data >>= (8 * (i % 4));

  return ((char) data & 0xff);
}

#define ETH_DMA_WRITE_TO_MEM  0
#define ETH_DMA_READ_FROM_MEM 1

#define DWORD_ALIGN(val) ((val + 0x3) & ~0x3)

void eth_set_tx_buffer(char* buffer,int size){
  if(((int) buffer) >= DDR_MEM){
    while(eth_get_status_field(ETH_DMA_READY) != 1);

    IO_SET(base,ETH_DMA_ADDRESS, (((int) buffer) - DDR_MEM)); // Memory address
    IO_SET(base,ETH_DMA_LEN,size);  // Length
    IO_SET(base,ETH_DMA_RUN,ETH_DMA_WRITE_TO_MEM); // DMA run

    while(eth_get_status_field(ETH_DMA_READY) != 1);
  } else {
    int* buffer_int = (int*) buffer;

    for (int i = 0; i < (DWORD_ALIGN(size) / 4) - 1; i++) {
      IO_SET(base,ETH_DATA + TEMPLATE_LEN + i * 4,buffer_int[i]);
    }
  }
}

void eth_get_rx_buffer(char* buffer,int size){

  if(((int) buffer) >= DDR_MEM){
    while(eth_get_status_field(ETH_DMA_READY) != 1);

    IO_SET(base,ETH_DMA_ADDRESS, (((int) buffer) - DDR_MEM));  // Memory address
    IO_SET(base,ETH_DMA_LEN,size); // Length
    IO_SET(base,ETH_DMA_RUN,ETH_DMA_READ_FROM_MEM); // DMA run

    while(eth_get_status_field(ETH_DMA_READY) != 1);
  } else {
    for(int i = 0; i < size; i++){
      buffer[i] = eth_get_data(i+16);
    }
  }

#if 0
  for(int i = 0; i < size + 8; i++){
    if((i % 16) == 0 && i > 0){
      printf("\n");
    }
    printf("%02x ",buffer[i]);
  }
  printf("\n");
#endif
}

void eth_init_frame(void) {
  int i;
  
  int* TEMPLATE_INT = (int*) TEMPLATE;

  for (i = 0; i < TEMPLATE_LEN / 4; i++) {
    IO_SET(base, ETH_DATA + i * 4, TEMPLATE_INT[i]);
  }
}
