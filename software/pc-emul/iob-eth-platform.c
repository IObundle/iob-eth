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

static int data_socket = -1;
static int connection_socket = -1;
static int payload_size;

/* dest mac | src mac | eth type*/
static char TX_FRAME[14];

static char send_buffer[BUFFER_SIZE+14];

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

#if 0
void eth_send_frame(char *data, unsigned int size) {

  char buffer[BUFFER_SIZE+14];

  
  
  int ret = write(data_socket, buffer, size+14);
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

  return ETH_DATA_RCV;
}
#endif

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

