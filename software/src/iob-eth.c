#include "stdint.h"
#include "printf.h"
#include "iob-eth.h"
#include <stdlib.h>

// Frame template (includes every field of the frame before the payload)
static char TEMPLATE[TEMPLATE_LEN];

/*******************************************/
/********** AUXILIAR FUNCTIONS *************/
/*******************************************/

/* read integer value
 * return number of bytes read */
static int get_int(char *ptr, unsigned int *i_val) {
    *i_val = (unsigned char) ptr[3];
    *i_val <<= 8;
    *i_val += (unsigned char) ptr[2];
    *i_val <<= 8;
    *i_val += (unsigned char) ptr[1];
    *i_val <<= 8;
    *i_val += (unsigned char) ptr[0];
    return sizeof(int);
}

/* write integer value to ptr position */
static void set_int(char *ptr, unsigned int i_val) {
    ptr[0] = i_val & 0xFF;
    i_val >>= 8;
    ptr[1] = i_val & 0xFF;
    i_val >>= 8;
    ptr[2] = i_val & 0xFF;
    i_val >>= 8;
    ptr[3] = i_val & 0xFF;
    return;
}

static void print_buffer(char *buffer, int size){
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

/*******************************************/
/*********** ETHERNET DRIVERS **************/
/*******************************************/

void eth_init(int base_address) {
#ifdef LOOPBACK
	eth_init_mac(base_address, ETH_MAC_ADDR, ETH_MAC_ADDR);
#else
	eth_init_mac(base_address, ETH_MAC_ADDR, ETH_RMAC_ADDR);
#endif
}

void eth_init_mac(int base_address, uint64_t mac_addr, uint64_t dest_mac_addr) {
  int i,ret;

  // set base address
  IOB_ETH_INIT_BASEADDR(base_address);
  
  // Preamble
  for(i=0; i < PREAMBLE_LEN; i++)
    TEMPLATE[PREAMBLE_PTR+i] = ETH_PREAMBLE;

  // SFD
  TEMPLATE[SDF_PTR] = ETH_SFD;

  // dest mac address
  for (i=0; i < MAC_ADDR_LEN; i++) {
    TEMPLATE[MAC_DEST_PTR+i] = dest_mac_addr >> 40;
    dest_mac_addr = dest_mac_addr << 8;
  }

  // source mac address
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
  //IOB_ETH_SET_SOFTRST(1);
  //IOB_ETH_SET_SOFTRST(0);

  //// wait for PHY to produce rx clock 
  //while (!((IOB_ETH_GET_STATUS() >> 3) & 1));

  //#ifdef ETH_DEBUG_PRINT
  //printf("Ethernet RX clock detected\n");
  //#endif

  //// wait for PLL to lock and produce tx clock 
  //while (!((IOB_ETH_GET_STATUS() >> 15) & 1));

  //#ifdef ETH_DEBUG_PRINT
  //printf("Ethernet TX PLL locked\n");
  //#endif

  //// set initial payload size to Ethernet minimum excluding FCS
  //IOB_ETH_SET_TX_NBYTES(46);

  //// check processor interface
  //// write dummy register
  //IOB_ETH_SET_DUMMY_W(0xDEADBEEF);

  //// read and check result
  //if (IOB_ETH_GET_DUMMY_R() != 0xDEADBEEF) {
  //  printf("Ethernet Init failed\n");
  //} else {
  //  printf("Ethernet Core Initialized\n");
  //}
}

// Get payload size from given buffer descriptor
unsigned short int eth_get_payload_size(unsigned int idx) {
  return IOB_ETH_GET_BD(idx<<1)>>16;
}

// Set payload size in given buffer descriptor
void eth_set_payload_size(unsigned int idx, unsigned int size) {
    IOB_ETH_SET_BD(idx<<1, (IOB_ETH_GET_BD(idx<<1) & 0x0000ffff) | size<<16 );
}

void eth_send_frame(char *data, unsigned int size) {
  int i;

  // wait for ready
  while(!eth_tx_ready(0));

  // Alloc memory for frame
  char *frame_ptr = (char *) malloc(TEMPLATE_LEN+size);

  // Copy template to frame
  for (i=0; i < TEMPLATE_LEN; i++)
    frame_ptr[i] = TEMPLATE[i];

  // Copy payload to frame
  for (i=0; i < size; i++)
    frame_ptr[i+TEMPLATE_LEN] = data[i];

  /* Buffer descriptor configuration */
    
  // set frame size
  eth_set_payload_size(0, TEMPLATE_LEN+size);

  // Set ready bit; Enable CRC and PAD; Set as last descriptor
  eth_set_ready(0, 1);
  eth_set_crc(0, 1);
  eth_set_pad(0, 1);
  eth_set_wr(0, 1);

  // start sending
  eth_send(1);

  // wait for ready
  while(!eth_tx_ready(0));

  // Disable transmission and free memory
  eth_send(0);
  free(frame_ptr);

  return;
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {
  int i;
  int cnt = timeout;

  // Alloc memory for frame
  char *frame_ptr = (char *) malloc(TEMPLATE_LEN+ETH_NBYTES);

  // Copy template to frame
  for (i=0; i < TEMPLATE_LEN; i++)
    frame_ptr[i] = TEMPLATE[i];

  // Mark empty; Set as last descriptor.
  eth_set_empty(0, 1);
  eth_set_wr(0, 1);

  // Enable reception
  eth_receive(1);

  // wait until data received
  while (!eth_rx_ready(0)) {
     timeout--;
     if (!timeout) {
       eth_receive(0);
       return ETH_NO_DATA;
     }
  }

  if(eth_bad_crc(0)) {
    eth_ack();
    eth_receive(0);
    printf("Bad CRC\n");
    return ETH_INVALID_CRC;
  }

  // Copy payload to return array
  for (i=0; i < size; i++) {
    data_rcv[i] = frame_ptr[i+TEMPLATE_LEN];
  }

  free(frame_ptr);
  
  // send receive ack
  eth_ack();

  // Disable reception
  eth_receive(0);
  
  return ETH_DATA_RCV;
}



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
  get_int(buffer, &size);

  return eth_rcv_file_impl(data,size);
}

unsigned int eth_send_variable_file(char *data, int size) {
  
  SyncAckFirst();

  // Send size
  set_int(buffer, size);
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);

  // Wait for ack
  while(eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, RCV_TIMEOUT));

  // Transfer file
  return eth_send_file_impl(data,size);
}

void eth_print_status(void) {
  printf("tx_ready = %x\n", eth_tx_ready(0));
  printf("rx_ready = %x\n", eth_rx_ready(0));
  printf("Bad CRC = %x\n", eth_bad_crc(0));
}

