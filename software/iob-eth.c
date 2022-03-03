#include "iob-eth.h"
#include "printf.h"

#define MAX(A,B) ((A) > (B) ? (A) : (B)) 
#define RCV_TIMEOUT 500000

static char buffer[ETH_NBYTES+HDR_LEN];

static void SyncAckFirst(){
  while(1){
    // Send frame
    eth_send_frame(buffer,ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack

    // Wait to receive ack
    if(eth_rcv_frame(buffer,ETH_MINIMUM_NBYTES,RCV_TIMEOUT) == ETH_DATA_RCV)
      break;
  }
}

static void SyncAckLast(){
  // Wait to receive frame
  while(1){
    // Wait to receive ack
    if(eth_rcv_frame(buffer,ETH_MINIMUM_NBYTES,RCV_TIMEOUT) == ETH_DATA_RCV)
      break;
  }

  eth_send_frame(buffer,ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack
}

static unsigned int eth_rcv_file_impl(char *data, int size) {
  int num_frames = ((size - 1) / ETH_NBYTES) + 1;
  unsigned int bytes_to_receive;
  unsigned int count_bytes = 0;
  int i, j;

  // Loop to receive intermediate data frames
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_receive = size - count_bytes;
     else bytes_to_receive = ETH_NBYTES;

     // wait to receive frame
     while(eth_rcv_frame(&data[count_bytes], bytes_to_receive, RCV_TIMEOUT));

     // send data back as ack
     eth_send_frame(&data[count_bytes], MAX(bytes_to_receive,ETH_MINIMUM_NBYTES));

     // update byte counter
     count_bytes += bytes_to_receive;
  }

  return count_bytes;
}

static unsigned int eth_send_file_impl(char *data, int size) {
  int num_frames = ((size - 1) / ETH_NBYTES) + 1;
  unsigned int bytes_to_send;
  unsigned int count_bytes = 0;
  unsigned int error_bytes = 0;
  int i,j;

  // Loop to send data
  for(j = 0; j < num_frames; j++) {

     // check if it is last packet (has less data that full payload size)
     if(j == (num_frames-1)) bytes_to_send = size - count_bytes;
     else bytes_to_send = ETH_NBYTES;

     // send frame
     eth_send_frame(&data[count_bytes], MAX(bytes_to_send,ETH_MINIMUM_NBYTES));

     // wait to receive frame as ack
     while(eth_rcv_frame(buffer, bytes_to_send, RCV_TIMEOUT));

     for(int i = 0; i < bytes_to_send; i++){
      if(buffer[i] != data[count_bytes + i]){
        error_bytes += 1;
      }
     }

     // update byte counter
     count_bytes += bytes_to_send;
  }

  printf("File transmitted with %d errors...\n",error_bytes);

  return count_bytes;
}

unsigned int eth_rcv_file(char *data, int size) {
  eth_on_transfer_start();

  SyncAckLast();

  return eth_rcv_file_impl(data,size);
}

unsigned int eth_send_file(char *data, int size) {
  eth_on_transfer_start();

  SyncAckFirst();

  return eth_send_file_impl(data,size);
}

unsigned int eth_rcv_variable_file(char *data) {
  int size = 0;

  eth_on_transfer_start();

  SyncAckLast();

  // Receive file size
  while(eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, RCV_TIMEOUT));

  // Send data back as ack
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);
  size = *((int*) buffer);

  return eth_rcv_file_impl(data,size);
}

unsigned int eth_send_variable_file(char *data, int size) {
  eth_on_transfer_start();
  
  SyncAckFirst();

  // Send size
  *((int*) buffer) = size;
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);

  // Wait for ack
  while(eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, RCV_TIMEOUT));

  // Transfer file
  return eth_send_file_impl(data,size);
}

void eth_print_status(void) {
  printf("tx_ready = %x\n", eth_tx_ready());
  printf("rx_ready = %x\n", eth_rx_ready());
  printf("phy_dv_detected = %x\n", eth_phy_dv());
  printf("phy_clk_detected = %x\n", eth_phy_clk());
  printf("rx_wr_addr = %x\n", eth_rx_wr_addr());
  printf("CRC = %x\n", eth_get_crc());
}

