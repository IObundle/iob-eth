#include <stdint.h>
#include "iob-uart.h"
#include "printf.h"

#ifndef IO_SET
#define IO_SET(base, location, value) (*((volatile int*) (base + (sizeof(int)) * location)) = value)
#endif

#ifndef IO_GET
#define IO_GET(base, location)        (*((volatile int*) (base + (sizeof(int)) * location)))
#endif

//memory map
#define ETH_STATUS           0
#define ETH_SEND             1
#define ETH_RCVACK           2
#define ETH_SOFTRST          4
#define ETH_DUMMY            5
#define ETH_TX_NBYTES        6
#define ETH_RX_NBYTES        7
#define ETH_CRC              8
#define ETH_DATA          2048

//preamble
#define ETH_PREAMBLE 0x55

//start frame delimiter
#define ETH_SFD 0xD5

//frame type
#define ETH_TYPE_H 0x08
#define ETH_TYPE_L 0x00

#define ETH_MAC_ADDR 0x01606e11020f

#define ETH_NO_DATA -1
#define ETH_DATA_RCV 0

//driver functions
void eth_init(int base);

void eth_send_frame(char *data_to_send, unsigned int size);

/* Function name: eth_rcv_frame
 * Inputs:
 * 	- data_rcv: char array where data received will be saved
 * 	- size: number of bytes to be received
 * 	- timeout: number of cycles (approximately) in which the data should be received
 * Output: 
 * 	- Return -1 if timeout occurs (no data received), or 0 if data is
 * 	successfully received
 */
int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout);

void eth_set_rx_payload_size(unsigned int size);

void eth_printstatus();
