#include <stdint.h>
#include "system.h"
#include "iob-eth.h"
#include "iob-uart.h"

char TX_FRAME [30];

void eth_init()
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

  //reset core
  MEMSET(ETH_BASE, ETH_SOFTRST, 1);

  //wait for PHY to produce rx clock 
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>3)&1));
  uart_puts("Ethernet RX clock detected\n");

  //wait for PLL to lock and produce tx clock 
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>15)&1));
  uart_puts("Ethernet TX PLL locked\n");

  //set initial payload size to Ethernet minimum excluding FCS
  MEMSET(ETH_BASE, ETH_TX_NBYTES, 46);
  MEMSET(ETH_BASE, ETH_RX_NBYTES, 46);

  // check processor interface
  // write dummy register
  MEMSET(ETH_BASE, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(ETH_BASE, ETH_DUMMY) != 0xDEADBEEF)
    uart_puts("Ethernet Init failed\n");
  else
    uart_puts("Ethernet Core Initialized\n");
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
  MEMSET(ETH_BASE, ETH_SEND, ETH_SEND);
}

void eth_rcv_frame(char *data_rcv, unsigned int size) {
  int i;
  // wait until data received
  while(!((MEMGET(ETH_BASE, ETH_STATUS)>>1)&1));

  for(i=0; i < (size+18); i = i+1)
    data_rcv[i] = MEMGET(ETH_BASE, (ETH_DATA + i));

  // send receive ack
  MEMSET(ETH_BASE, ETH_RCVACK, 1);
}

void eth_set_rx_payload_size(unsigned int size) {
  //set frame size
  MEMSET(ETH_BASE, ETH_RX_NBYTES, size);
}


void eth_printstatus(){
  uart_printf("tx_ready = %x\n", (MEMGET(ETH_BASE, ETH_STATUS)>>0)&1);
  uart_printf("rx_ready = %x\n", (MEMGET(ETH_BASE, ETH_STATUS)>>1)&1);
  uart_printf("phy_dv_detected = %x\n", (MEMGET(ETH_BASE, ETH_STATUS)>>2)&1);
  uart_printf("phy_clk_detected = %x\n", (MEMGET(ETH_BASE, ETH_STATUS)>>3)&1);
  uart_printf("rx_wr_addr = %x\n", (MEMGET(ETH_BASE, ETH_STATUS)>>4)&0xFFF0);
  uart_printf("CRC = %x\n", MEMGET(ETH_BASE, ETH_CRC));
}

