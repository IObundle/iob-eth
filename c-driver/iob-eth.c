#include "system.h"
#include "iob-eth.h"
#include "iob-uart.h"


char TX_FRAME [22];
unsigned int TX_NBYTES;
unsigned int RX_NBYTES;

bool eth_init(unsigned int tx_size, unsigned int rx_size)
{
  int i;

  //Preamble
  for(i=0; i < 7; i= i+1)
    TX_FRAME[i] = 0x55;

  //SFD
  TX_FRAME[7] = 0xD5;

  //frame sizes
  TX_NBYTES = tx_size;
  RX_NBYTES = rx_size;

  //set lengths of TX and RX
  MEMSET(ETH_BASE, ETH_TX_NBYTES, TX_NBYTES);
  MEMSET(ETH_BASE, ETH_RX_NBYTES, RX_NBYTES);

  //dest mac address
  unsigned long long int mac_addr = ETH_RMAC_ADDR;
  for(i=0; i < 6; i= i+1) {
    TX_FRAME[i+8] = mac_addr>>40;
    mac_addr = mac_addr<<8;
  }

  //source mac address
  mac_addr = ETH_MAC_ADDR;
  for(i=0; i < 6; i= i+1) {
    TX_FRAME[i+14] = mac_addr>>40;
    mac_addr = mac_addr<<8;
  }

  //eth type
  TX_FRAME[20] = 0x08;
  TX_FRAME[21] = 0x00;


  // check processor interface
  // write dummy register
  MEMSET(ETH_BASE, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(ETH_BASE, ETH_DUMMY) != 0xDEADBEEF)
    return false;
  else 
    return true;
}

void eth_send_frame(char *data) {
  int i;
  //wait for ready
  while(! (MEMGET(ETH_BASE, ETH_STATUS)&1)   );

  //write data to send
  for(i=0; i < 22; i = i+1) {
    MEMSET(ETH_BASE, (ETH_DATA + i), TX_FRAME[i]);
  }

  for(i=0; i < TX_NBYTES; i = i+1) {
    MEMSET(ETH_BASE, (ETH_DATA + 22 + i), data[i]);
  }

  // start sending
  MEMSET(ETH_BASE, ETH_CONTROL, ETH_SEND);
}

void eth_rcv_frame(char *data_rcv) {
  int i;
  // wait until rx ready
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>1)&1));

  for(i=0; i < RX_NBYTES; i = i+1)
    data_rcv[i] = MEMGET(ETH_BASE, (ETH_DATA + i +14));

  // send receive command
  MEMSET(ETH_BASE, ETH_CONTROL, ETH_RCV);
}
