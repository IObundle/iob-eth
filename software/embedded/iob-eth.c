#include "iob-eth.h"

static int base;
static char TX_FRAME[30];

void eth_init(int base_address)
{
  int i;
  uint64_t mac_addr;

  //set base address
  base = base_address;
  
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
  IO_SET(base, ETH_SOFTRST, 1);
  IO_SET(base, ETH_SOFTRST, 0);

  //wait for PHY to produce rx clock 
  while(!((IO_GET(base, ETH_STATUS)>>3)&1));
  uart_puts((char *)"Ethernet RX clock detected\n");

  //wait for PLL to lock and produce tx clock 
  while(!((IO_GET(base, ETH_STATUS)>>15)&1));
  uart_puts((char*)"Ethernet TX PLL locked\n");

  //set initial payload size to Ethernet minimum excluding FCS
  IO_SET(base, ETH_TX_NBYTES, 46);
  IO_SET(base, ETH_RX_NBYTES, 46);

  // check processor interface
  // write dummy register
  IO_SET(base, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (IO_GET(base, ETH_DUMMY) != 0xDEADBEEF){
    uart_puts((char*)"Ethernet Init failed\n");
  }
  else{
    uart_puts((char*)"Ethernet Core Initialized\n");
  }
}

void eth_send_frame(char *data, unsigned int size) {
  int i;
  //wait for ready
  while(! (IO_GET(base, ETH_STATUS)&1)   );

  //set frame size
  IO_SET(base, ETH_TX_NBYTES, size);

  //write data to send
  //header
  for(i=0; i < 30; i = i+1) {
    IO_SET(base, (ETH_DATA + i), TX_FRAME[i]);
  }
  //payload
  for(i=0; i < size; i = i+1) {
    IO_SET(base, (ETH_DATA + 30 + i), data[i]);
  }

  // start sending
  IO_SET(base, ETH_SEND, ETH_SEND);
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {
  int i;

  // wait until data received
  while(!((IO_GET(base, ETH_STATUS)>>1)&1)) {
     timeout--;
     if (timeout==0){
       return ETH_NO_DATA;
     }
  }

  if( IO_GET(base, ETH_CRC) != 0xc704dd7b) {
    IO_SET(base, ETH_RCVACK, 1);
    uart_puts((char*)"Bad CRC\n");
    return ETH_NO_DATA;
  }

  for(i=0; i < (size+18); i = i+1)
    data_rcv[i] = IO_GET(base, (ETH_DATA + i));

  // send receive ack
  IO_SET(base, ETH_RCVACK, 1);
  
  return ETH_DATA_RCV;
}

void eth_set_rx_payload_size(unsigned int size) {
  //set frame size
  IO_SET(base, ETH_RX_NBYTES, size);
}


void eth_printstatus() {
  printf("tx_ready = %x\n", (IO_GET(base, ETH_STATUS)>>0)&1);
  printf("rx_ready = %x\n", (IO_GET(base, ETH_STATUS)>>1)&1);
  printf("phy_dv_detected = %x\n", (IO_GET(base, ETH_STATUS)>>2)&1);
  printf("phy_clk_detected = %x\n", (IO_GET(base, ETH_STATUS)>>3)&1);
  printf("rx_wr_addr = %x\n", (IO_GET(base, ETH_STATUS)>>4)&0xFFF0);
  printf("CRC = %x\n", IO_GET(base, ETH_CRC));
}

