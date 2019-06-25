#include <stdint.h>
#include "system.h"
#include "iob-eth.h"
#include "iob-uart.h"

char TX_FRAME [30];

int eth_init()
{
  int i;
  uint64_t mac_addr;

  //Preamble
  for(i=0; i < 15; i= i+1)
    TX_FRAME[i] = 0x55;

  //SFD
  TX_FRAME[15] = 0xD5;

  //dest mac address
#ifdef LOOPBACK
  mac_addr = ETH_MAC_ADDR;
#else
  mac_addr = ETH_RMAC_ADDR;
#endif
  for(i=0; i < 6; i= i+1) {
    TX_FRAME[i+16] = mac_addr>>40;
    mac_addr = mac_addr<<8;
  }

  //source mac address
  mac_addr = ETH_MAC_ADDR;
  for(i=0; i < 6; i= i+1) {
    TX_FRAME[i+22] = mac_addr>>40;
    mac_addr = mac_addr<<8;
  }

  //eth type
  TX_FRAME[28] = 0x08;
  TX_FRAME[29] = 0x00;

  //set initial payload size to Ethernet minimum excluding FCS
  MEMSET(ETH_BASE, ETH_TX_NBYTES, 42);
  MEMSET(ETH_BASE, ETH_RX_NBYTES, 42);

  // check processor interface
  // write dummy register
  MEMSET(ETH_BASE, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(ETH_BASE, ETH_DUMMY) != 0xDEADBEEF)
    return -1;
  else 
    return 0;
}

void eth_send_frame(char *data, unsigned int size) {
  int i;
  //wait for ready
  while(! (MEMGET(ETH_BASE, ETH_STATUS)&1)   );

  //set frame size
  MEMSET(ETH_BASE, ETH_TX_NBYTES, size);

  //write data to send
  //header
  for(i=0; i < 30; i = i+1) {
    MEMSET(ETH_BASE, (ETH_DATA + i), TX_FRAME[i]);
  }
  //payload
  for(i=0; i < size; i = i+1) {
    MEMSET(ETH_BASE, (ETH_DATA + 30 + i), data[i]);
  }

  // start sending
  MEMSET(ETH_BASE, ETH_CONTROL, ETH_SEND);
}

void eth_rcv_frame(char *data_rcv, unsigned int size) {
  int i;
  // wait until rx ready
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>1)&1));

  //set frame size
  MEMSET(ETH_BASE, ETH_RX_NBYTES, size);

  for(i=0; i < size; i = i+1)
    data_rcv[i] = MEMGET(ETH_BASE, (ETH_DATA + i));

  // send receive command
  MEMSET(ETH_BASE, ETH_CONTROL, ETH_RCV);
}

void eth_printstatus(){
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>2)&1));
  uart_puts("RX_DV has been asserted.\n");
  uart_printf("CRC = %x\n", MEMGET(ETH_BASE, ETH_CRC));
}

