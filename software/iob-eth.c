#include "iob-eth.h"
#include "printf.h"

/* Embedded includes */
#include "stdint.h"
#include "iob-lib.h"
#include "iob-eth.h"
#include "iob_eth_swreg.h"
#include "printf.h"

#include "iob-eth-platform.h"

/*******************************************/
/********** EMBEDDED DRIVERS ***************/
/*******************************************/

#define PREAMBLE_PTR     0
#define SDF_PTR          (PREAMBLE_PTR + PREAMBLE_LEN)
#define MAC_DEST_PTR     (SDF_PTR + 1)
#define MAC_SRC_PTR      (MAC_DEST_PTR + MAC_ADDR_LEN)
//#define TAG_PTR          (MAC_SRC_PTR + MAC_ADDR_LEN) // Optional - not supported
#define ETH_TYPE_PTR     (MAC_SRC_PTR + MAC_ADDR_LEN)
#define PAYLOAD_PTR      (ETH_TYPE_PTR + 2)

#define TEMPLATE_LEN     (PAYLOAD_PTR)

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
    printf("%02x ", (unsigned char) TEMPLATE[MAC_SRC_PTR+i]);
  }
  printf("\nDest: ");
  for(i=0; i < MAC_ADDR_LEN; i++){
    printf("%02x ", (unsigned char) TEMPLATE[MAC_DEST_PTR+i]);
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
  int size_int = size/4 + (size%4 > 0); // ceil()
  int *buffer_int = (int*) buffer;
  int i = 0;
  int eth_data_payload_addr = ETH_DATA + TEMPLATE_LEN/4;

  for( i=0; i<size_int; i++){
      IO_SET(base, eth_data_payload_addr + i, buffer_int[i]);
  }
}

void eth_get_rx_buffer(char* buffer,int size){
  /* skip MAC DST ADDR, MAC SRC ADDR and ETH TYPE from rx buffer */
  /* the PREAMBLE and SDF are not stored into the rx buffer */
  int rx_data_offset = PAYLOAD_PTR - MAC_DEST_PTR;

  for(int i = 0; i < size; i++){
    buffer[i] = eth_get_data(i+rx_data_offset);
  }
}

void eth_init_frame(void) {
  int i;
  int *template_int = (int*) TEMPLATE;
  
  for (i = 0; i < TEMPLATE_LEN/4; i++) {
    IO_SET(base, ETH_DATA + i, template_int[i]);
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



/*******************************************/
/*********** COMMON DRIVERS ****************/
/*******************************************/

#define MAX(A,B) ((A) > (B) ? (A) : (B)) 
#define RCV_TIMEOUT 500000

static char buffer[ETH_NBYTES+HDR_LEN];

static void SyncAckFirst(){
  while(1){
    // Send frame
    eth_send_frame(buffer,ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack

    // Wait to receive ack
    if(eth_rcv_frame(buffer,ETH_MINIMUM_NBYTES,RCV_TIMEOUT) == ETH_DATA_RCV)
      break;
  }
}

static void SyncAckLast(){
  // Wait to receive frame
  while(1){
    // Wait to receive ack
    if(eth_rcv_frame(buffer,ETH_MINIMUM_NBYTES,RCV_TIMEOUT) == ETH_DATA_RCV)
      break;
  }

  eth_send_frame(buffer,ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack
}

static unsigned int eth_rcv_file_impl(char *data, int size) {
  int num_frames = ((size - 1) / ETH_NBYTES) + 1;
  unsigned int bytes_to_receive;
  unsigned int count_bytes = 0;
  int i, j;

  // Loop to receive intermediate data frames
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_receive = size - count_bytes;
     else bytes_to_receive = ETH_NBYTES;

     // wait to receive frame
     while(eth_rcv_frame(&data[count_bytes], bytes_to_receive, RCV_TIMEOUT));

     // send data back as ack
     eth_send_frame(&data[count_bytes], MAX(bytes_to_receive,ETH_MINIMUM_NBYTES));

     // update byte counter
     count_bytes += bytes_to_receive;
  }

  return count_bytes;
}

static unsigned int eth_send_file_impl(char *data, int size) {
  int num_frames = ((size - 1) / ETH_NBYTES) + 1;
  unsigned int bytes_to_send;
  unsigned int count_bytes = 0;
  unsigned int error_bytes = 0;
  int i,j;

  // Loop to send data
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_send = size - count_bytes;
     else bytes_to_send = ETH_NBYTES;

     // send frame
     eth_send_frame(&data[count_bytes], MAX(bytes_to_send,ETH_MINIMUM_NBYTES));

     // wait to receive frame as ack
     while(eth_rcv_frame(buffer, bytes_to_send, RCV_TIMEOUT));

     for(int i = 0; i < bytes_to_send; i++){
      if(buffer[i] != data[count_bytes + i]){
        error_bytes += 1;
      }
     }

     // update byte counter
     count_bytes += bytes_to_send;
  }

  printf("File transmitted with %d errors...\n",error_bytes);

  return count_bytes;
}

unsigned int eth_rcv_file(char *data, int size) {

  SyncAckLast();

  return eth_rcv_file_impl(data,size);
}

unsigned int eth_send_file(char *data, int size) {

  SyncAckFirst();

  return eth_send_file_impl(data,size);
}

unsigned int eth_rcv_variable_file(char *data) {
  int size = 0;

  SyncAckLast();

  // Receive file size
  while(eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, RCV_TIMEOUT));

  // Send data back as ack
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);
  size = *((int*) buffer);

  return eth_rcv_file_impl(data,size);
}

unsigned int eth_send_variable_file(char *data, int size) {
  
  SyncAckFirst();

  // Send size
  *((int*) buffer) = size;
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);

  // Wait for ack
  while(eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, RCV_TIMEOUT));

  // Transfer file
  return eth_send_file_impl(data,size);
}

void eth_print_status(void) {
  printf("tx_ready = %x\n", eth_tx_ready());
  printf("rx_ready = %x\n", eth_rx_ready());
  printf("phy_dv_detected = %x\n", eth_phy_dv());
  printf("phy_clk_detected = %x\n", eth_phy_clk());
  printf("rx_wr_addr = %x\n", eth_rx_wr_addr());
  printf("CRC = %x\n", eth_get_crc());
}

void print_buffer(char *buffer, int size){
    if(buffer == NULL || size < 1){
        printf("DEBUG print buffer: invalid inputs\n");
        return;
    }
    int i = 0, ch = 0;
    char HexTable[16] = "0123456789abcdef";
    printf("\tDEBUG: Buffer:");
    for( i=0; i<size; i++){
        ch = (int) ((unsigned char) buffer[i]);
        printf("%c%c ", HexTable[ch >> 4], HexTable[ch & 0xF]);
    }
    printf("\n\n");
    return;
}

