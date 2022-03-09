#include "iob-eth.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>

#include "eth_mem_map.h"

#define BUFFER_SIZE 2048
#define SOCKET_NAME "/tmp/tmpLocalSocket"

typedef enum IO_Type_t {
    io_get = 0,
    io_set = 1
} IO_Type;

static int data_socket = -1;
static int connection_socket = -1;

/* dest mac | src mac | eth type*/
static char TX_FRAME[14];

static char send_buffer[BUFFER_SIZE+14];
static char rcv_buffer[BUFFER_SIZE+14];
static int rcv_size_reg = 0;
static int tx_nbytes_reg = 0, rx_nbytes_reg = 0;
static int dummy_reg = 0;

/* pc emulation functions */
void pc_eth_send(int value){
    // use correct bit width
    int send_int = value & 0x01;
    // write data to socket
    if(send_int){
        int wret = -1;
        // by default try to write data
        wret = send(data_socket, (send_buffer+MAC_DEST_PTR), tx_nbytes_reg, MSG_NOSIGNAL);
    }
    return;
}

void pc_eth_rcvack(int value){
    // use correct bit width
    int rcvack_int = value & 0x01;
    // no action needed for ack in pc emul
    return;
}

/* Reset AF_UNIX Socket
 * this AF_UNIX socket is used to emulate the ethernet communication
 * the payload in the messages send has the contents of a Raw Ethernet Frame:
 * [ Preamble | SFD | DST MAC | SRC MAC | ETH Type | Payload Data | CRC (implitic) ]
 */
void pc_eth_softrst(int value){
    // use correct bit width
    int softrst_int = value & 0x01;
    if(softrst_int) {
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

        printf("Ethernet Core Initialized\n");

    }
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
    tx_nbytes_reg = tx_nbytes_int - MAC_DEST_PTR; // discount PREAMBLE and SDF bytes
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
    /* int location_int = location & ((1<<12)-1); */
    int location_int = location - ETH_DATA;
    if(type == io_set) {
        // write data to send buffer
        send_buffer[location_int] = (char) data_int;
    } else if(type == io_get) {
        // read data from rcv buffer
        return *( ((int*)rcv_buffer) + location_int);
    } else
        return -1;
    return 0;
}

int pc_eth_status(){
    // Emulate rx_ready() behaviour to receive data
    int ret = -1;
    ret = recv(data_socket, rcv_buffer_int, BUFFER_SIZE, MSG_DONTWAIT);
    int rx_status_mask = ~(0x0); /* all 1s */
    if ( ret < 1 ){
        /* nothing read -> rx_status == 0 */
        rx_status_mask = ~(1 << ETH_RX_READY);
    } else {
        /* received data -> rx_status == 0 */
        rx_nbytes_reg = ret;
        /* save data received size */
        memcpy(rcv_buffer, rcv_buffer_int, ret);
    }

    return (0x0001FFFF & rx_status_mask);
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
            pc_eth_data(location, value, io_set);
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

/* Temporary functions */
void eth_on_transfer_start(void){
    printf("Waiting for client connection...\n");

    /* accept connection */
    data_socket = accept(connection_socket, NULL, NULL);
    /* check for errors */
    if(data_socket == -1){
        printf("Failed to accept connection\n");
        exit(EXIT_FAILURE);
    }
    return;
}

