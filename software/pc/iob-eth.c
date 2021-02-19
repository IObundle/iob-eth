#include "iob-eth.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define BUFFER_SIZE ETH_DATA
#define SOCKET_NAME "./tmpLocalSocket"

static int data_socket = -1;
static int payload_size;

/* dest mac | src mac | eth type*/
static char TX_FRAME[14];

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

  int connection_socket = 0;
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
    uart_puts("Failed to bind socket");
    exit(EXIT_FAILURE);
  }

  uart_puts("Waiting for client connection...\n");

  /* wait for eth_comm connections */
  ret = listen(connection_socket, 1);
  /* check for errors */
  if(ret == -1){
    uart_puts("Error in listen");
    exit(EXIT_FAILURE);
  }

  /* accept connection */
  data_socket = accept(connection_socket, NULL, NULL);
  /* check for errors */
  if(data_socket == -1){
    uart_puts("Failed to accept connection");
    exit(EXIT_FAILURE);
  }

  uart_puts("Ethernet Core Initialized\n");
}

void eth_send_frame(char *data, unsigned int size) {

  char buffer[BUFFER_SIZE+14];

  memcpy(buffer, TX_FRAME, 14*sizeof(char));

  memcpy(&(buffer[14]), data, size*sizeof(char));
  
  int ret = write(data_socket, buffer, size+14);
  /* check for errors */
  if(ret == -1){
    uart_puts("Failed in eth_send_frame()");
    exit(EXIT_FAILURE);
  }
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {

  /* receive data */
  int ret = read(data_socket, data_rcv, size+18);
  /* check for errors */
  if(ret == -1){
    uart_puts("Failed in eth_rcv_frame()");
    exit(EXIT_FAILURE);
  }
  printf("Received message: ret = %d\n", ret);

  return ETH_DATA_RCV;
}

void eth_set_rx_payload_size(unsigned int size) {
  //set frame size
  payload_size = size;
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

