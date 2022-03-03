#include "stdint.h"
#include "iob-lib.h"
#include "iob-eth.h"
#include "eth_mem_map.h"
#include "printf.h"

#define PREAMBLE_PTR     0
#define SDF_PTR          (PREAMBLE_PTR + PREAMBLE_LEN)
#define MAC_DEST_PTR     (SDF_PTR + 1)
#define MAC_SRC_PTR      (MAC_DEST_PTR + MAC_ADDR_LEN)
//#define TAG_PTR          (MAC_SRC_PTR + MAC_ADDR_LEN) // Optional - not supported
#define ETH_TYPE_PTR     (MAC_SRC_PTR + MAC_ADDR_LEN)
#define PAYLOAD_PTR      (ETH_TYPE_PTR + 2)

#define TEMPLATE_LEN     (PAYLOAD_PTR)

#define ETH_DMA_WRITE_TO_MEM  0
#define ETH_DMA_READ_FROM_MEM 1

#define DWORD_ALIGN(val) ((val + 0x3) & ~0x3)

#define ETH_DEBUG_PRINT 1

// Base address
static int base;

// Frame template
static char TEMPLATE[TEMPLATE_LEN];

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

  #ifdef ETH_DEBUG_PRINT
  printf("\nSender:");
  for(i=0; i < MAC_ADDR_LEN; i++){
    printf("%02x ",TEMPLATE[MAC_SRC_PTR+i]);
  }
  printf("\nDest: ");
  for(i=0; i < MAC_ADDR_LEN; i++){
    printf("%02x ",TEMPLATE[MAC_DEST_PTR+i]);
  }
  printf("\n");
  #endif

  // eth type
  TEMPLATE[ETH_TYPE_PTR]   = ETH_TYPE_H;
  TEMPLATE[ETH_TYPE_PTR+1] = ETH_TYPE_L;

  // reset core
  IO_SET(base, ETH_SOFTRST, 1);
  IO_SET(base, ETH_SOFTRST, 0);

  // wait for PHY to produce rx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 3) & 1));

  #ifdef ETH_DEBUG_PRINT
  printf("Ethernet RX clock detected\n");
  #endif

  // wait for PLL to lock and produce tx clock 
  while (!((IO_GET(base, ETH_STATUS) >> 15) & 1));

  #ifdef ETH_DEBUG_PRINT
  printf("Ethernet TX PLL locked\n");
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
    printf("Ethernet Init failed\n");
  } else {
    printf("Ethernet Core Initialized\n");
  }
}

void eth_on_transfer_start(void){
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
  IO_SET(base, ETH_TX_NBYTES, (size + TEMPLATE_LEN));
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

void eth_set_tx_buffer(char* buffer,int size){
  int dma_transfer = 0,dma_address = 0;

#ifdef ETH_DMA
  if(((int) buffer) >= DDR_MEM){
    dma_transfer = 1;
  }
  dma_address = (((int) buffer) - DDR_MEM);
#endif

  if(dma_transfer) {
    while(eth_get_status_field(ETH_DMA_READY) != 1);

    IO_SET(base,ETH_DMA_ADDRESS, dma_address);     // Memory address
    IO_SET(base,ETH_DMA_LEN,size);                 // Length
    IO_SET(base,ETH_DMA_RUN,ETH_DMA_WRITE_TO_MEM); // DMA run

    while(eth_get_status_field(ETH_DMA_READY) != 1);
  } else {
    if(((int) buffer) % 4 == 0){
      int* buffer_int = (int*) buffer;

      for (int i = 0; i < DWORD_ALIGN(size) / 4; i++)
        IO_SET(base,ETH_DATA + TEMPLATE_LEN + i * 4,buffer_int[i]);
    }
    else
    {
      union {int32_t i32; int8_t i8[4];} data;
      for (int i = 0; i < DWORD_ALIGN(size) / 4; i++) {
        for(int j = 0; j < 4; j++)
          data.i8[j] = buffer[i*4+j];

        IO_SET(base,ETH_DATA + TEMPLATE_LEN + i * 4,data.i32);
      }
    }
  }
}

void eth_get_rx_buffer(char* buffer,int size){
  int dma_transfer = 0,dma_address = 0;

#ifdef ETH_DMA
  if(((int) buffer) >= DDR_MEM){
    dma_transfer = 1;
  }
  dma_address = (((int) buffer) - DDR_MEM);
#endif

  if(dma_transfer){
    while(eth_get_status_field(ETH_DMA_READY) != 1);

    IO_SET(base,ETH_DMA_ADDRESS,dma_address);       // Memory address
    IO_SET(base,ETH_DMA_LEN,size);                  // Length
    IO_SET(base,ETH_DMA_RUN,ETH_DMA_READ_FROM_MEM); // DMA run

    while(eth_get_status_field(ETH_DMA_READY) != 1);
  } else {
    for(int i = 0; i < size; i++){
      buffer[i] = eth_get_data(i+16);
    }
  }
}

void eth_init_frame(void) {
  int i;
  
  int* TEMPLATE_INT = (int*) TEMPLATE;

  for (i = 0; i < TEMPLATE_LEN / 4; i++) {
    IO_SET(base, ETH_DATA + i * 4, TEMPLATE_INT[i]);
  }
}

void eth_send_frame(char *data, unsigned int size) {
  int i;

  // wait for ready
  while(!eth_tx_ready());

  // set frame size
  eth_set_tx_payload_size(size);

  // payload
  eth_set_tx_buffer(data,size);

  // start sending
  eth_send();

  return;
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {
  int i;
  int cnt = timeout;

  // wait until data received
  while (!eth_rx_ready()) {
     timeout--;
     if (!timeout) {
       return ETH_NO_DATA;
     }
  }

  if(eth_get_crc() != 0xc704dd7b) {
    eth_ack();
    printf("Bad CRC\n");
    return ETH_INVALID_CRC;
  }

  eth_get_rx_buffer(data_rcv,size);
  
  // send receive ack
  eth_ack();
  
  return ETH_DATA_RCV;
}
