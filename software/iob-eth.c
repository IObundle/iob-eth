#include "iob-eth.h"
#include "iob-uart.h"
#include "printf.h"

#define RCV_TIMEOUT 5000

static char buffer[ETH_NBYTES+HDR_LEN];

void eth_send_frame(char *data, unsigned int size) {
  int i;

  // wait for ready
  while(!eth_tx_ready());

  // write data to send
  // init frame
  eth_init_frame();

  // set frame size
  eth_set_tx_payload_size(22 + size); // 22 

  // payload
  eth_set_tx_buffer(data,size);

  eth_set_tx_payload_size(HDR_LEN + size + 7); // payload + HDR + 8 bytes from preamble (7-0x55 and 1-0xD5) (instead of payload size, think its the number of elements from the buffer to send) 
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
    uart_puts("Bad CRC\n");
    return ETH_INVALID_CRC;
  }

  printf("%d\n",eth_get_rcv_size());

  eth_set_rx_payload_size(eth_get_rcv_size()+14); // DMA end address, since we skip the first 14 bytes, need to add 14 more
  eth_get_rx_buffer(data_rcv,size);

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
     while(eth_rcv_frame(&data[count_bytes], bytes_to_receive, RCV_TIMEOUT));

     // send data back as ack
     eth_send_frame(&data[j*ETH_NBYTES], bytes_to_receive);

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

