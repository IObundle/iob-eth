#include "iob-eth.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdint.h>

#define BUFFER_SIZE 2048
#define SOCKET_NAME "/tmp/tmpLocalSocket"

static typedef enum IO_Type_t {
    io_get = 0,
    io_set = 1
} IO_Type

static int data_socket = -1;
static int connection_socket = -1;
static int payload_size;

/* dest mac | src mac | eth type*/
static char TX_FRAME[14];

static char send_buffer[BUFFER_SIZE+14];
static char rcv_buffer[BUFFER_SIZE+14];
static int rcv_size_reg = 0;

/* pc emulation functions */
void pc_eth_send(int value){
    // use correct bit width
    int send_int = value & 0x01;
    // TODO: trigger send message
    // don't check for send_int value
    return;
}

void pc_eth_rcvack(int value){
    // use correct bit width
    int rcvack_int = value & 0x01;
    // TODO: get ready to receive another message?
    // don't check for rcvack_int value
    return;
}

void pc_eth_softrst(int value){
    // use correct bit width
    int softrst_int = value & 0x01;
    // TODO: reset ethernet
    // don't check for softrst_int value
    return;
}

/* dummy is a read / write register to validate correct
 * access to SWREGs of the ethernet core */
int pc_eth_dummy(int value, IO_Type type){
    // use correct bit width
    int dummy_int = value & 0xFFFFFFFF;
    if(type == io_set)
        dummy_reg = dummy_int;
    else if(type == io_get)
        return dummy_reg;
    else
        return -1;
    return 0;
}

/* set TX_NBYTES */
void pc_eth_tx_nbytes(int value){
    // use correct bit width
    int tx_nbytes_int = value & ((1<<11)-1);
    tx_nbytes_reg = tx_nbytes_int;
    return;
}

/* set RX_NBYTES */
void pc_eth_rx_nbytes(int value){
    // use correct bit width
    int rx_nbytes_int = value & ((1<<11)-1);
    rx_nbytes_reg = rx_nbytes_int;
    return;
}

/* TODO: set dma address */
void pc_eth_dma_address(int value){
    return;
}

/* TODO: set dma len */
void pc_eth_dma_len(int value){
    return;
}

/* TODO: set dma run */
void pc_eth_dma_run(int value){
    return;
}

/* write data to sending frame
 * or
 * read data from received frame
 */
int pc_eth_data(int location, int value, IO_Type type){
    // use correct bit width
    int data_int = value & 0xFFFFFFFF;
    int location_int = location & ((1<<10)-1);
    if(type == io_set) {
        // write data to send buffer
        send_buffer[location_int] = data_int;
    } else if(type == io_get) {
        // read data from rcv buffer
        // TODO: check if we need to skip ETH Frame header
        return rcv_buffer[location_int];
    } else
        return -1;
    return 0;
}

int pc_eth_status(){
    // TODO: return status
    return 0x0001FFFF;
}

/* always return correct CRC value */
int pc_eth_crc(){
    return 0xc704dd7b;
}

/* return size of last received frame */
int pc_eth_rcv_size(){
    return rcv_size_reg;
}

/* Ethernet Core access simulation */

void MEM_SET(int type, int location, int value){
    return;
}

int MEM_GET(int type, int location){
    return 0;
}

void IO_SET(int base, int location, int value){
    switch(location){
        case ETH_SEND:
            pc_eth_send(value);
            break;
        case ETH_RCVACK:
            pc_eth_rcvack(value);
            break;
        case ETH_SOFTRST:
            pc_eth_softrst(value);
            break;
        case ETH_DUMMY:
            pc_eth_dummy(value, io_set);
            break;
        case ETH_TX_NBYTES:
            pc_eth_tx_nbytes(value);
            break;
        case ETH_RX_NBYTES:
            pc_eth_rx_nbytes(value);
            break;
        case ETH_DMA_ADDRESS:
            pc_eth_dma_address(value);
            break;
        case ETH_DMA_LEN:
            pc_eth_dma_len(value);
            break;
        case ETH_DMA_RUN:
            pc_eth_dma_run(value);
            break;
        default:
            pc_eth_dma_data(location, value, io_set);
            break;
    }
    return;
}

int IO_GET(int base, int location){
    int ret_val = 0;
    switch(location){
        case ETH_STATUS:
            ret_val = pc_eth_status();
            break;
        case ETH_DUMMY:
            ret_val = pc_eth_dummy(0, io_get);
            break;
        case ETH_CRC:
            ret_val = pc_eth_crc();
            break;
        case ETH_RCV_SIZE:
            ret_val = pc_eth_rcv_size();
            break;
        default:
            ret_val = pc_eth_data(location, 0, io_get);
            break;
    }
    return ret_val;
}



/* ******************************* */

void eth_init(int base_address)
{
  int i;
  struct sockaddr_un name;
  

  /* set TX_FRAME*/
  uint64_t mac_addr = ETH_MAC_ADDR;
  for(i=0;i<6;i++){
    TX_FRAME[i] = mac_addr << 8;
  }
  mac_addr = ETH_MAC_ADDR;
  for(i=0;i<6;i++){
    TX_FRAME[i+6] = mac_addr << 8;
  }
  TX_FRAME[12] = 0x08;
  TX_FRAME[13] = 0x00;

  /* set payload size*/
  payload_size = 46; 

  int ret = 0;

  /* remove socket if it exists*/
  unlink(SOCKET_NAME);

  /*create socket to receive connections */
  connection_socket = socket(AF_UNIX, SOCK_SEQPACKET, 0);
  /* check for errors */
  if(connection_socket == -1){
    perror("Failed to create socket");
    exit(EXIT_FAILURE);
  }
  /*clear structure*/
  memset(&name, 0, sizeof(struct sockaddr_un));


  /*bind socket*/
  name.sun_family = AF_UNIX;
  strncpy(name.sun_path, SOCKET_NAME, sizeof(name.sun_path) - 1);

  ret = bind(connection_socket, (const struct sockaddr*) &name, sizeof(struct sockaddr_un));
  /* check for errors */
  if(ret == -1){
    printf("Failed to bind socket");
    exit(EXIT_FAILURE);
  }

  /* wait for eth_comm connections */
  ret = listen(connection_socket, 1);
  /* check for errors */
  if(ret == -1){
    printf("Error in listen");
    exit(EXIT_FAILURE);
  }

  printf("Ethernet Core Initialized\n");

  memcpy(send_buffer, TX_FRAME, 14*sizeof(char));
}

void eth_send_frame(char *data, unsigned int size) {
  int i = 0;

  /* copy data to send buffer */
  for(i = 0; i < size; i++)
      send_buffer[i+14] = data[i];

  int ret = write(data_socket, send_buffer, size+14);
  /* check for errors */
  if(ret == -1){
    printf("Failed in eth_send_frame()");
    exit(EXIT_FAILURE);
  }
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {

  /* receive data */
  int ret = read(data_socket, data_rcv, size+18);
  /* check for errors */
  if(ret == -1){
    printf("Failed in eth_rcv_frame()");
    exit(EXIT_FAILURE);
  }
  printf("Received message: ret = %d\n", ret);

  /* shift from DST | SRC | ETH | Data | CRC to
  *            Data | CRC
  *            */
  int i = 0;
  for(i = 0; i < size; i++){
      data_rcv[i] = data_rcv[i+14];
  }
  for(; i<size+18; i++){
      data_rcv[i] = 0;
  }

  return ETH_DATA_RCV;
}

void eth_on_transfer_start(void){
  printf("Waiting for client connection...\n");

  /* accept connection */
  data_socket = accept(connection_socket, NULL, NULL);
  /* check for errors */
  if(data_socket == -1){
    printf("Failed to accept connection");
    exit(EXIT_FAILURE);
  }
}

void eth_set_rcvack(char value){
}

void eth_set_send(char value){
  int ret = write(data_socket, send_buffer, payload_size+14);
}

void eth_set_tx_buffer(char* buffer,int size){
  memcpy(&(send_buffer[14]), buffer, size*sizeof(char));
}

void eth_get_rx_buffer(char* buffer,int size){
  static char temp[BUFFER_SIZE];

  int readed = read(data_socket, temp, BUFFER_SIZE);

  memcpy(buffer,&temp[14],size);
}

int eth_get_crc(void){
  return 0xc704dd7b;
}

void eth_set_tx_payload_size(unsigned int size) {
  //set frame size
  payload_size = size;
}

int eth_get_status(void){
  return 0xffff;
}

int eth_get_status_field(char field){
  return 1;
}

void eth_printstatus() {
  printf("PC implementation, printing dummy values\n");
  printf("tx_ready = %x\n", 1);
  printf("rx_ready = %x\n", 1);
  printf("phy_dv_detected = %x\n", 1);
  printf("phy_clk_detected = %x\n", 1);
  printf("rx_wr_addr = %x\n", 1);
  printf("CRC = %x\n", 1);
}

