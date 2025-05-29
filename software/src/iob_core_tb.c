/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#include "iob_axistream_in_csrs.h"
#include "iob_axistream_out_csrs.h"
#include "iob_dma.h"
#include "iob_dma_csrs.h"
#include "iob_eth.h"
#include "iob_eth_csrs.h"
#include "iob_eth_macros.h"

#include <stdio.h>

#define RAM_ADDR 4000
#define SPLIT_ADDR_W (14 - 2)

#undef ETH_NBYTES
#define ETH_NBYTES 1024
#define BUFF_SIZE (ETH_NBYTES + TEMPLATE_LEN)

void print_version(unsigned int version) {
  unsigned int major = version >> 16;
  unsigned int minor = version & 0xFF;
  printf("Version is %x.%x\n", major, minor);
}

void eth_vutb_init(int base_address) {
  // Initialize Ethernet in Loopback mode
  eth_init_mac(base_address, ETH_MAC_ADDR, ETH_MAC_ADDR);
  eth_reset_bd_memory();
}

int iob_core_tb() {

  int failed = 0;

  // print welcome message
  printf("IOB ETH testbench\n");

  // print the reset message
  printf("Reset complete\n");

  //
  // axistream_in connected to 1st master of split
  iob_axistream_in_csrs_init_baseaddr(0);
  // axistream_out connected to 2nd master of split
  iob_axistream_out_csrs_init_baseaddr(1 << SPLIT_ADDR_W);
  // dma connected to 3rd master of split
  iob_dma_csrs_init_baseaddr(2 << SPLIT_ADDR_W);
  // eth connected to 4th master of split
  eth_vutb_init(3 << SPLIT_ADDR_W);
  // iob_eth_csrs_init_baseaddr(3 << SPLIT_ADDR_W);

  unsigned int version;
  uint32_t i, word;

  // Check versions
  // read version 20 times to burn time
  for (i = 0; i < 20; i++) {

    version = iob_dma_csrs_get_version();
  }
  printf("DMA ");
  print_version(iob_dma_csrs_get_version());
  printf("ETH ");
  print_version(iob_eth_csrs_get_version());

  // prepare eth frame to send
  char send_buffer[BUFF_SIZE] = {0};
  char rcv_buffer[BUFF_SIZE] = {0};
  int ptr = 0;

  printf("1. Prepare Ethernet Frame\n");
  ptr += eth_prepare_frame(send_buffer);

  // fill payload
  for (i = 0; i < ETH_NBYTES; i++) {
    send_buffer[ptr++] = (char)(i / 4);
  }

  // load frame to AXI RAM

  // 1. CPU -> AXIS OUT -> AXIS IN data transfer
  printf("2.1. Configure AXIStream IN\n");
  iob_axistream_in_csrs_set_soft_reset(1);
  iob_axistream_in_csrs_set_soft_reset(0);
  iob_axistream_in_csrs_set_mode(1);
  iob_axistream_in_csrs_set_enable(1);

  printf("2.2. Configure AXIStream OUT\n");
  iob_axistream_out_csrs_set_soft_reset(1);
  iob_axistream_out_csrs_set_soft_reset(0);
  iob_axistream_out_csrs_set_mode(0);
  iob_axistream_out_csrs_set_nwords(ptr);
  iob_axistream_out_csrs_set_enable(1);

  printf("2.3. Write data to AXIStream OUT\n");

  // write data loop
  for (i = 0; i < ptr; i++) {
    iob_axistream_out_csrs_set_data(send_buffer[i]);
  }

  // wait for data in AXIS IN
  while (iob_axistream_in_csrs_get_nwords() < ptr)
    ;
  // 3. Configure AXIS IN -> DMA -> AXI RAM write operation
  printf("3.1. Configure DMA write transfer\n");
  iob_dma_csrs_set_w_burstlen(ptr);
  dma_write_transfer((uint32_t *)RAM_ADDR, ptr);

  // 4. Wait for DMA transfer complete
  printf("4. Wait for DMA write transfer complete...");
  while (dma_write_busy())
    ;
  printf("done!\n");

  // send frame
  printf("5. Send frame...\n");
  eth_send_frame_addr(ETH_NBYTES, RAM_ADDR);
  printf("\t\tdone!\n");

  // TODO:
  // 6. Receive Frame
  // 6.1 Set RX buffer pointer
  // 6.2 Receive frame

  // 7. Read data with DMA
  // 8. Validate data

  //
  // // 4. Configure AXIS OUT <- DMA <- AXI RAM read operation
  // printf("4.1. Configure AXIStream IN\n");
  // iob_axistream_in_csrs_set_soft_reset(1);
  // iob_axistream_in_csrs_set_soft_reset(0);
  // iob_axistream_in_csrs_set_mode(0);
  // iob_axistream_in_csrs_set_enable(1);
  //
  // printf("4.2. Configure AXIStream OUT\n");
  // iob_axistream_out_csrs_set_soft_reset(1);
  // iob_axistream_out_csrs_set_soft_reset(0);
  // iob_axistream_out_csrs_set_mode(1);
  // iob_axistream_out_csrs_set_nwords(NWORDS);
  // iob_axistream_out_csrs_set_enable(1);
  //
  // printf("4.3. Configure DMA read transfer\n");
  // iob_dma_csrs_set_r_burstlen(200);
  // dma_read_transfer((uint32_t *)RAM_ADDR, NWORDS);
  //
  // // 5. Wait for DMA transfer complete
  // printf("5. Wait for DMA read transfer complete...");
  // while (dma_read_busy())
  //   ;
  // printf("done!\n");
  //
  // // 6. Read data from AXIS IN and validate
  // printf("6. Read data from AXIStream IN\n");
  // // read data loop
  // for (i = 0; i < NWORDS; i = i + 1) {
  //   word = iob_axistream_in_csrs_get_data();
  //
  //   // check data
  //   if (word != i) {
  //     printf("Error: expected %d, got %d\n", i, word);
  //     failed = failed + 1;
  //   }
  // }
  //
  // printf("DMA test complete.\n");
  // printf("Size:%d(dec):%x(hex)\n", ETH_NBYTES, ETH_NBYTES);
  //
  // char send_buffer[ETH_NBYTES] = {0};
  // char rcv_buffer[ETH_NBYTES] = {0};
  //
  // send_buffer[0] = 0xef;
  // send_buffer[1] = 0xfe;
  // send_buffer[2] = 0xef;
  // send_buffer[3] = 0xfe;
  // for (int i = 4; i < ETH_NBYTES; i++) {
  //   send_buffer[i] = (char)(i / 4);
  // }
  //
  // // Send frame containing test data
  // printf("[INFO] Sending test data...\n");
  // eth_send_frame(send_buffer, ETH_NBYTES);
  // printf("\t\tdone!\n");
  //
  // // Receive loopback frame with test data
  // printf("[INFO] Receiving test data...\n");
  // while (eth_rcv_frame(rcv_buffer, ETH_NBYTES, 5000000))
  //   ; // Data in
  // printf("\t\tdone!\n");
  //
  // // Compare data
  // printf("[INFO] Check data...\n");
  // for (i = 0; i < ETH_NBYTES; i++) {
  //   if (rcv_buffer[i] != send_buffer[i]) {
  //     printf("Error: Byte[%d]: expected %x, got %x\n", i, send_buffer[i],
  //            rcv_buffer[i]);
  //     failed = failed + 1;
  //   }
  // }
  // if (failed == 0) {
  //   printf("\t\tSUCCESS: Test data correct!\n");
  // } else {
  //   printf("\t\tERROR: Found invalid test data\n");
  // }
  // printf("\n");
  return failed;
}
