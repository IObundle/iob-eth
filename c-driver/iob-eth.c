#include "iob-eth.h"
#include "iob-uart.h"

#define MEMSET(base, location, value) (*((volatile int*) (base + (sizeof(int)) * location)) = value)
#define MEMGET(base, location)        (*((volatile int*) (base + (sizeof(int)) * location)))

char TX_FRAME [22];
int TX_NBYTES;
int RX_NBYTES;
int BASE;

int ethInit(unsigned int base, unsigned int tx_nbytes, unsigned int rx_nbytes)
{
  int i;
  TX_NBYTES = tx_nbytes;
  RX_NBYTES = rx_nbytes;
  BASE = base;
  //#######Set some default values for transmission frame####
  //Prepare preamble for transmission
  for(i=0; i < 7; i= i+1)
    TX_FRAME[i] = 0x55;

  //sfd
  TX_FRAME[7] = 0xD5;

  //dest mac address
  unsigned long long int mac_addr = ETH_MAC_ADDR;

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

  //set lengths of TX and NX
  MEMSET(base, ETH_TX_NBYTES, TX_NBYTES);
  MEMSET(base, ETH_RX_NBYTES, RX_NBYTES);

  // check processor interface
  // write dummy register
  MEMSET(base, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(base, ETH_DUMMY) != 0xDEADBEEF)
    return -1;
  return 0;
}

void send_frame(char data[]) {
  int i;
  //wait for ready
  while(! (MEMGET(BASE, ETH_STATUS)&1)   );

  //write data to send
  for(i=0; i < 22; i = i+1) {
    MEMSET(BASE, (ETH_DATA + i), TX_FRAME[i]);
  }

  for(i=22; i < (TX_NBYTES+22); i = i+1) {
    MEMSET(BASE, (ETH_DATA + i), data[i-22]);
  }

  // start sending
  MEMSET(BASE, ETH_CONTROL, ETH_SEND);
}

void rcv_frame(char data_rcv[]) {
  int i;
  // wait until rx ready
  while(!((MEMGET(BASE, ETH_STATUS)>>1)&1));

  for(i=0; i < (RX_NBYTES+14); i = i+1)
    data_rcv[i] = MEMGET(BASE, (ETH_DATA + i));

  // send receive command
  MEMSET(BASE, ETH_CONTROL, ETH_RCV);
}
