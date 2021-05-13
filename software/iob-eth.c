#include "iob-eth.h"
#include "iob-uart.h"
#include "printf.h"

#define RCV_TIMEOUT 5000

char buffer[ETH_NBYTES];

void eth_send_frame(char *data, unsigned int size) {
  int i;

  // wait for ready
  while(!eth_tx_ready());

  // set frame size
  eth_set_tx_payload_size(size);

  // write data to send
  // header
  eth_set_header();

  // payload
  for (i=0; i < size; i++) {
    //IO_SET(base, (ETH_DATA + 30 + i), data[i]);
    eth_set_data(i, data[i]);
  }

  // start sending
  eth_send();

  return;
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {
  int i;
  int cnt = timeout;

  // wait until data received
  while (!eth_rx_ready()) {
     timeout--;
     if (!timeout) {
       return ETH_NO_DATA;
     }
  }

  if(eth_get_crc() != 0xc704dd7b) {
    eth_ack();
    //uart_puts((char*)"Bad CRC\n");
    return ETH_NO_DATA;
  }

  for(i=0; i < size; i++) {
    //data_rcv[i] = IO_GET(base, (ETH_DATA + i));
    data_rcv[i] = eth_get_data(i);
  }

  // send receive ack
  eth_ack();
  
  return ETH_DATA_RCV;
}

unsigned int eth_rcv_file(char *data, int size) {
  int num_frames = size/ETH_NBYTES;
  unsigned int bytes_to_receive;
  unsigned int count_bytes = 0;
  int i, j;

  if (size % ETH_NBYTES) num_frames++;

  // Loop to receive intermediate data frames
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_receive = size - count_bytes;
     else bytes_to_receive = ETH_NBYTES;

     // wait to receive frame
     while(eth_rcv_frame(buffer, bytes_to_receive, RCV_TIMEOUT));

     // save in DDR
     for(i = 0; i < bytes_to_receive; i++) {
       data[j*ETH_NBYTES + i] = buffer[14+i];
     }

     // send data back as ack
     eth_send_frame(&buffer[14], bytes_to_receive);

     // update byte counter
     count_bytes += bytes_to_receive;
  }

  return count_bytes;
}

unsigned int eth_send_file(char *data, int size) {
  int num_frames = size/ETH_NBYTES;
  unsigned int bytes_to_send;
  unsigned int count_bytes = 0;
  int j;

  if (size % ETH_NBYTES) num_frames++;

  // Loop to send data
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_send = size - count_bytes;
     else bytes_to_send = ETH_NBYTES;

     // send frame
     eth_send_frame(&data[j*ETH_NBYTES], bytes_to_send);

     // wait to receive frame as ack
     if(j != (num_frames-1)) while(eth_rcv_frame(buffer, bytes_to_send, RCV_TIMEOUT));

     // update byte counter
     count_bytes += bytes_to_send;
  }

  return count_bytes;
}

void eth_print_status(void) {
  printf("tx_ready = %x\n", eth_tx_ready());
  printf("rx_ready = %x\n", eth_rx_ready());
  printf("phy_dv_detected = %x\n", eth_phy_dv());
  printf("phy_clk_detected = %x\n", eth_phy_clk());
  printf("rx_wr_addr = %x\n", eth_rx_wr_addr());
  printf("CRC = %x\n", eth_get_crc());
}

