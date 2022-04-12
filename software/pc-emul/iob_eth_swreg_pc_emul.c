/* PC Emulation of ETHERNET peripheral */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>

#include "iob-eth.h"
#include "iob_eth_swreg.h"

#define BUFFER_SIZE 2048
#define SOCKET_NAME "/tmp/tmpLocalSocket"

static int data_socket = -1;
static int connection_socket = -1;

/* dest mac | src mac | eth type*/
static char TX_FRAME[14];

static char send_buffer[BUFFER_SIZE];
static char rcv_buffer[BUFFER_SIZE];
static char rcv_buffer_int[BUFFER_SIZE];
static int rcv_size_reg = 0;
static uint16_t tx_nbytes_reg = 0;
static uint32_t dummy_reg = 0;

/* pc emulation functions 
 * this AF_UNIX socket is used to emulate the ethernet communication
 * a Raw Ethernet Frame has the following fields:
 * [ Preamble | SFD | DST MAC | SRC MAC | ETH Type | Payload Data | CRC (implicit) ]
 * but the pc-emul version only sends and receives:
 * [ DST MAC | SRC MAC | ETH Type | Payload Data | CRC (implicit) ]
 * (the preamble and SDF bytes are not transfered)
 */
void ETH_SET_SEND(uint8_t value){
    // write data to socket
    if(value){
        int wret = -1;
        // by default try to write data
        wret = send(data_socket, (send_buffer+MAC_DEST_PTR), tx_nbytes_reg, MSG_NOSIGNAL);
    }
    return;
}

void ETH_SET_RCVACK(uint8_t value){
    // no action needed for ack in pc emul
    return;
}

/* Reset AF_UNIX Socket
 */
void ETH_SET_SOFTRST(uint8_t value){
    // use correct bit width
    if(value) {
        struct sockaddr_un name;
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
        printf("Waiting for client connection...\n");

        /* accept connection */
        data_socket = accept(connection_socket, NULL, NULL);
        /* check for errors */
        if(data_socket == -1){
            printf("Failed to accept connection\n");
            exit(EXIT_FAILURE);
        }
    }
    return;
}

/* dummy is a read / write register to validate correct
 * access to SWREGs of the ethernet core */
void ETH_SET_DUMMY_W(uint32_t value) {
    dummy_reg = value;
}

uint32_t ETH_GET_DUMMY_R() {
    return dummy_reg;
}

/* set TX_NBYTES */
void ETH_SET_TX_NBYTES(uint16_t value) {
    // use correct bit width
    tx_nbytes_reg = value - MAC_DEST_PTR; // discount PREAMBLE and SDF bytes
    return;
}

/* write data to sending frame
 * or
 * read data from received frame
 */
void ETH_SET_DATA_WR(uint16_t addr, uint32_t value) {
    // write data to send buffer
    int *send_buffer_int = (int*) (send_buffer);
    send_buffer_int[addr] = value;
    return;
}

uint32_t ETH_GET_DATA_RD(uint16_t addr) {
    // read data from rcv buffer
    return *( ((int*)rcv_buffer) + addr);
}


uint32_t ETH_GET_STATUS() {
    // Emulate rx_ready() behaviour to receive data
    int ret = -1;
    ret = recv(data_socket, rcv_buffer_int, BUFFER_SIZE, MSG_DONTWAIT);
    int rx_status_mask = ~(0x0); /* all 1s */
    if ( ret < 1 ){
        /* nothing read -> rx_status == 0 */
        rx_status_mask = ~(1 << ETH_RX_READY);
    } else {
        /* save data received size */
        memcpy(rcv_buffer, rcv_buffer_int, ret);
    }

    return (0x0001FFFF & rx_status_mask);
}

/* always return correct CRC value */
uint32_t ETH_GET_CRC() {
    return 0xc704dd7b;
}

/* return size of last received frame */
uint16_t ETH_GET_RCV_SIZE() {
    return rcv_size_reg;
}

