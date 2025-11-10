/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#include "iob_eth_tb_driver.h"
#include "iob_eth.h"
#include "iob_eth_defines.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static FILE *eth2soc_fd;
static FILE *soc2eth_fd;

static void cpu_initeth(int base_address);
static void relay_frame_file_2_eth();
static void relay_frame_eth_2_file(int frame_size);

// Call this function once at start up
void eth_setup(int base_address) {
  // configure eth
  cpu_initeth(base_address);

  while ((eth2soc_fd = fopen("./eth2soc", "rb")) == NULL)
    ;
  fclose(eth2soc_fd);
  soc2eth_fd = fopen("./soc2eth", "wb");
}

// Call this function in main loop to keep relaying frames form file to core and
// vice versa
void eth_relay_frames() {
  int rx_nbytes_reg = 0;

  // Relay ethernet frames from core to file
  rx_nbytes_reg = iob_eth_csrs_get_rx_nbytes();
  if (rx_nbytes_reg) {
    // printf("$eth2file sending %d bytes.\n", rx_nbytes_reg); // DEBUG
    relay_frame_eth_2_file(rx_nbytes_reg);
    // printf("$eth2file_done\n"); // DEBUG
  }
  // Relay ethernet frames from file to core
  if (eth_tx_ready(0)) {
    // Try to open file
    eth2soc_fd = fopen("./eth2soc", "rb");
    if (!eth2soc_fd) {
      // wait 1 ms and try again
      usleep(1000);
      eth2soc_fd = fopen("./eth2soc", "rb");
      if (!eth2soc_fd) {
        fclose(soc2eth_fd);
        exit(1);
      }
    }
    // Read file contents
    relay_frame_file_2_eth();
  }
}

//
// Local functions
//

static void relay_frame_file_2_eth() {
  unsigned char size_l, size_h, frame_byte;
  unsigned short int frame_size;
  unsigned int i, n;

  // Read frame size (2 bytes)
  n = fscanf(eth2soc_fd, "%c%c", &size_l, &size_h);
  // Continue if size read successfully
  if (n == 2) {
    frame_size = (size_h << 8) | size_l;
    // printf("$file2eth received %d bytes.\n", frame_size); // DEBUG
    //  wait for ready
    while (!eth_tx_ready(0))
      ;
    // set frame size
    eth_set_payload_size(0, frame_size);
    // Set ready bit
    eth_set_ready(0, 1);

    // Read RAW frame from binary encoded file, byte by byte
    for (i = 0; i < frame_size; i = i) {
      n = fscanf(eth2soc_fd, "%c", &frame_byte);
      if (n > 0) {
        iob_eth_csrs_set_frame_word(frame_byte);
        i = i + 1;
      }
    }
    fclose(eth2soc_fd);
    // Delete frame from file
    eth2soc_fd = fopen("./eth2soc", "wb");
    // printf("$file2eth_done\n"); // DEBUG
  } // n != 0
  fclose(eth2soc_fd);
}

static void relay_frame_eth_2_file(int frame_size) {
  char frame_byte;
  unsigned int i;

  // Write two bytes with frame size
  fprintf(soc2eth_fd, "%c%c", frame_size & 0xff, (frame_size >> 8) & 0x07);

  // Read frame bytes from core and write to file
  for (i = 0; i < frame_size; i = i + 1) {
    frame_byte = iob_eth_csrs_get_frame_word();
    fprintf(soc2eth_fd, "%c", frame_byte);
  }
  fflush(soc2eth_fd);

  // Wait for BD status update (via ready/empty bit)
  while (!eth_rx_ready(64))
    ;

  // Check bad CRC
  if (eth_bad_crc(64))
    printf("Bad CRC!\n");

  // Mark empty to allow receive next frame
  eth_set_empty(64, 1);
}

static void cpu_initeth(int base_address) {
  // RMAC and MAC flipped: testbench ethernet peripheral emulates console
  eth_init_mac(base_address, ETH_RMAC_ADDR, ETH_MAC_ADDR);
  eth_reset_bd_memory();

  /**** Configure receiver *****/
  // Mark empty; Set as last descriptor; Enable interrupt.
  eth_set_empty(64, 1);
  eth_set_wr(64, 1);
  eth_set_interrupt(64, 1);

  // Enable reception
  eth_receive(1);

  /**** Configure transmitter *****/
  // Enable CRC and PAD; Set as last descriptor; Enable interrupt.
  eth_set_crc(0, 1);
  eth_set_pad(0, 1);
  eth_set_wr(0, 1);
  eth_set_interrupt(0, 1);

  // enable transmission
  eth_send(1);
}
