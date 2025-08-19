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

#define SEND_RAM_ADDR 4000
#define RCV_RAM_ADDR 2000
#define SPLIT_ADDR_W (14 - 2)
#define TIMEOUT (100000)

#undef ETH_NBYTES
#define ETH_NBYTES 1500
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
  // axistream_in connected to 1st manager of split
  iob_axistream_in_csrs_init_baseaddr(0);
  // axistream_out connected to 2nd manager of split
  iob_axistream_out_csrs_init_baseaddr(1 << SPLIT_ADDR_W);
  // dma connected to 3rd manager of split
  iob_dma_csrs_init_baseaddr(2 << SPLIT_ADDR_W);
  // eth connected to 4th manager of split
  eth_vutb_init(3 << SPLIT_ADDR_W);
  // iob_eth_csrs_init_baseaddr(3 << SPLIT_ADDR_W);

  unsigned int version;
  uint32_t i;

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
  int axis_out_nwords = 0;

  printf("1. Prepare Ethernet Frame\n");
  ptr += eth_prepare_frame(send_buffer);

  // fill payload
  for (i = 0; i < ETH_NBYTES; i++) {
    send_buffer[ptr++] = (char)(i & 0xFF);
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
  axis_out_nwords = (ptr + 3) / 4; // round up to next 4-byte word
  iob_axistream_out_csrs_set_nwords(axis_out_nwords);
  iob_axistream_out_csrs_set_enable(1);

  printf("2.3. Write data to AXIStream OUT\n");

  // write data loop
  uint32_t d32 = 0;
  for (i = 0; i < ptr; i += 4) {
    d32 = (((uint32_t)send_buffer[i] & 0xFF) << 24) |
          (((uint32_t)send_buffer[i + 1] & 0xFF) << 16) |
          (((uint32_t)send_buffer[i + 2] & 0xFF) << 8) |
          ((uint32_t)send_buffer[i + 3] & 0xFF);
    iob_axistream_out_csrs_set_data(d32);
  }

  // wait for data in AXIS IN
  while (iob_axistream_in_csrs_get_nwords() < axis_out_nwords)
    ;
  // 3. Configure AXIS IN -> DMA -> AXI RAM write operation
  printf("3.1. Configure DMA write transfer\n");
  // Limit burst length to max of 255 words
  uint32_t burstlen = axis_out_nwords;
  if (burstlen > 255) {
    burstlen = 255;
  }
  iob_dma_csrs_set_w_burstlen(burstlen);
  dma_write_transfer((uint32_t *)SEND_RAM_ADDR, axis_out_nwords);

  // 4. Wait for DMA transfer complete
  printf("4. Wait for DMA write transfer complete...\n");
  while (dma_write_busy())
    ;
  printf("done!\n");

  // send frame
  printf("5. Send frame...\n");
  eth_send_frame_addr(ETH_NBYTES, SEND_RAM_ADDR);
  printf("\t\tdone!\n");

  printf("6. Receive frame...\n");
  // eth_rcv_frame_addr(data_rcv, size, timeout, frame_addr);
  eth_rcv_frame_addr(ETH_NBYTES, TIMEOUT, RCV_RAM_ADDR);
  printf("\t\tdone!\n");

  // 7. Configure AXIS OUT <- DMA <- AXI RAM read operation
  printf("7.1. Configure AXIStream IN\n");
  iob_axistream_in_csrs_set_soft_reset(1);
  iob_axistream_in_csrs_set_soft_reset(0);
  iob_axistream_in_csrs_set_mode(0);
  iob_axistream_in_csrs_set_enable(1);

  printf("7.2. Configure AXIStream OUT\n");
  iob_axistream_out_csrs_set_soft_reset(1);
  iob_axistream_out_csrs_set_soft_reset(0);
  iob_axistream_out_csrs_set_mode(1);
  iob_axistream_out_csrs_set_nwords(axis_out_nwords);
  iob_axistream_out_csrs_set_enable(1);

  printf("7.3. Configure DMA read transfer\n");
  iob_dma_csrs_set_r_burstlen(burstlen);
  dma_read_transfer((uint32_t *)RCV_RAM_ADDR, axis_out_nwords);

  // 8. Wait for DMA transfer complete
  printf("8. Wait for DMA read transfer complete...");
  while (dma_read_busy())
    ;
  printf("done!\n");

  // 9. Read data from AXIS IN and validate
  printf("9. Read data from AXIStream IN\n");
  // read data loop
  uint32_t rcv_32 = 0;
  uint32_t b = 0;
  for (i = 0; i < ptr; i += 4) {
    rcv_32 = iob_axistream_in_csrs_get_data();
    d32 = (((uint32_t)send_buffer[i] & 0xFF) << 24) |
          (((uint32_t)send_buffer[i + 1] & 0xFF) << 16) |
          (((uint32_t)send_buffer[i + 2] & 0xFF) << 8) |
          ((uint32_t)send_buffer[i + 3] & 0xFF);

    // check data
    if (rcv_32 != d32) {
      printf("Error: expected %x, got %x\n", d32, rcv_32);
      failed = failed + 1;
    }
  }

  printf("Ethernet Loopback test complete.\n");
  printf("Size:%d(dec):%x(hex)\n", ETH_NBYTES, ETH_NBYTES);
  if (failed == 0) {
    printf("\t\tSUCCESS: Test data correct!\n");
  } else {
    printf("\t\tERROR: Found invalid test data\n");
  }
  printf("\n");

  return failed;
}
