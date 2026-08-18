/*
 * SPDX-FileCopyrightText: 2026 IObundle
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include "iob_eth.h"
#include "iob_eth_defines.h"
#include <stddef.h>
#include <stdio.h>

// Frame template (includes every field of the frame before the payload)
static char TEMPLATE[TEMPLATE_LEN];

// Function to flush cache (clean + invalidate)
static void (*flush_cache)(void *, size_t) = NULL;
static int (*printf_func)(const char *format, ...) = &printf;
// Functions to alloc and free memory
static void *(*mem_alloc)(size_t) = &malloc;
static void (*mem_free)(void *) = &free;

/*******************************************/
/********** AUXILIAR FUNCTIONS *************/
/*******************************************/

/* read integer value
 * return number of bytes read */
static int get_int(char *ptr, unsigned int *i_val) {
  *i_val = (unsigned char)ptr[3];
  *i_val <<= 8;
  *i_val += (unsigned char)ptr[2];
  *i_val <<= 8;
  *i_val += (unsigned char)ptr[1];
  *i_val <<= 8;
  *i_val += (unsigned char)ptr[0];
  return sizeof(int);
}

/* write integer value to ptr position */
static void set_int(char *ptr, unsigned int i_val) {
  ptr[0] = i_val & 0xFF;
  i_val >>= 8;
  ptr[1] = i_val & 0xFF;
  i_val >>= 8;
  ptr[2] = i_val & 0xFF;
  i_val >>= 8;
  ptr[3] = i_val & 0xFF;
  return;
}

static void print_buffer(char *buffer, int size) {
  if (buffer == NULL || size < 1) {
    printf_func("DEBUG print buffer: invalid inputs\n");
    return;
  }
  int i = 0, ch = 0;
  char HexTable[17] = "0123456789abcdef";
  printf_func("\tDEBUG: Buffer:");
  for (i = 0; i < size; i++) {
    ch = (int)((unsigned char)buffer[i]);
    printf_func("%c%c ", HexTable[ch >> 4], HexTable[ch & 0xF]);
  }
  printf_func("\n\n");
  return;
}

/*******************************************/
/*********** ETHERNET DRIVERS **************/
/*******************************************/

// IEEE 802.3 Clause 22 PHY register addresses
#define PHY_BMCR 0       // Basic Mode Control Register
#define PHY_MII_STATUS 1 // MII Status Register
#define PHY_PHY_ID_HI 2  // PHY Identifier High
#define PHY_PHY_ID_LO 3  // PHY Identifier Low
#define PHY_ANAR 4       // Auto-Negotiation Advertisement Register
#define PHY_ANLPAR 5     // Auto-Negotiation Link Partner Ability Register
#define PHY_CTRL1000 9   // 1000BASE-T Control Register (Clause 22)

// BMCR bits (speed encoding: {bit13, bit6} = 00:10M, 01:100M, 10:1000M)
#define BMCR_RESET (1 << 15)
#define BMCR_SPEED100 (1 << 6)
#define BMCR_ANENABLE (1 << 12)
#define BMCR_RESTART_AUTONEG (1 << 9)
#define BMCR_FULL_DUPLEX (1 << 8)

// 1000BASE-T Control (GBCR) bits
#define CTRL1000_ADVERTISE_1000_FD (1 << 9)
#define CTRL1000_ADVERTISE_1000_HD (1 << 8)

// MII Status bits
#define MII_STATUS_LINK (1 << 2)
#define MII_STATUS_AUTONEG_COMPLETE (1 << 5)

// ANAR bits
#define ANAR_PROTOCOL_802_3 (1 << 0)
#define ANAR_100BASE_TX_HD (1 << 7)
#define ANAR_100BASE_TX_FD (1 << 8)

// Simple busy-wait delay of ~1 ms, scaled with the system clock so the
// elapsed time is the same regardless of the CPU frequency (no OS timers
// available in baremetal)
static void mii_delay(uint32_t system_freq) {
  volatile int i;
  for (i = 0; i < (int)(system_freq / 1000); i++)
    ;
}

// Wait until the MII management interface is idle
// returns 0 on success, -1 on timeout
static int mii_wait_idle(void) {
  int timeout = 1000000;
  while (timeout-- && (iob_eth_csrs_get_miistatus() & MIISTATUS_BUSY))
    ;
  return timeout > 0 ? 0 : -1;
}

// Read a Clause 22 PHY register
// returns 0 on success, -1 on timeout
static int mii_read(int phy, int reg, uint16_t *val) {
  iob_eth_csrs_set_miiaddress(MIIADDRESS_ADDR(phy, reg));
  iob_eth_csrs_set_miicommand(MIICOMMAND_READ);
  if (mii_wait_idle())
    return -1;
  *val = iob_eth_csrs_get_miirx_data() & 0xffff;
  iob_eth_csrs_set_miicommand(0);
  return 0;
}

// Write a Clause 22 PHY register
// returns 0 on success, -1 on timeout
static int mii_write(int phy, int reg, uint16_t val) {
  iob_eth_csrs_set_miiaddress(MIIADDRESS_ADDR(phy, reg));
  iob_eth_csrs_set_miitx_data(val);
  iob_eth_csrs_set_miicommand(MIICOMMAND_WRITE);
  if (mii_wait_idle())
    return -1;
  iob_eth_csrs_set_miicommand(0);
  return 0;
}

// Configure the PHY to only advertise 100BASE-TX and force the link to
// 100 Mbps. The iob_eth core is a MII core and only works at 10/100 Mbps.
// When the board is connected to a gigabit switch with auto-negotiation
// enabled, the PHY would otherwise link at 1000 Mbps and the core cannot
// decode the data.
void eth_init_phy(uint32_t system_freq) {
  int i, retry, phy = -1;
  uint16_t val, id_hi;

  // Wait for the PHY to be released from reset by the core
  while (iob_eth_csrs_get_phy_rst_val())
    ;

  // Configure MII management clock divider so that MDC <= 2.5 MHz
  iob_eth_csrs_set_miimoder(MIIMODER_CLKDIV(system_freq / 2500000));

  // Scan the MDIO bus for the PHY (read PHY ID high register). Reject both
  // 0xffff (no device pulls the line low) and 0x0000 (a floating line with no
  // pull-up) as "not present".
  for (i = 0; i < 32; i++) {
    if (!mii_read(i, PHY_PHY_ID_HI, &val) && val != 0xffff && val != 0x0000) {
      phy = i;
      id_hi = val;
      break;
    }
  }
  if (phy < 0) {
    printf_func("ETH: PHY not found on MDIO bus\n");
    return;
  }
  mii_read(phy, PHY_PHY_ID_LO, &val);
  printf_func("ETH: PHY found at address %d (id 0x%04x:%04x)\n", phy, id_hi,
              val);

  // Diagnostic readbacks of the Clause 22 registers on this PHY
  mii_read(phy, PHY_BMCR, &val);
  printf_func("ETH: PHY BMCR (before)      = 0x%04x\n", val);
  mii_read(phy, PHY_ANAR, &val);
  printf_func("ETH: PHY ANAR (before)      = 0x%04x\n", val);
  mii_read(phy, PHY_CTRL1000, &val);
  printf_func("ETH: PHY GBCR (before)      = 0x%04x\n", val);
  mii_read(phy, PHY_MII_STATUS, &val);
  printf_func("ETH: PHY STATUS (before)    = 0x%04x\n", val);

  // Clear the 1000BASE-T advertisement (reg 9). A gigabit PHY advertises
  // 1000BASE-T via GBCR independently of ANAR (reg 4); with it left set the
  // link would negotiate 1000 Mbps, which the MII core cannot decode.
  mii_write(phy, PHY_CTRL1000, 0x0000);
  mii_read(phy, PHY_CTRL1000, &val);
  printf_func("ETH: PHY GBCR (after write) = 0x%04x\n", val);

  // Advertise only 100BASE-TX (full + half duplex) and restart auto-negotiation
  mii_write(phy, PHY_ANAR,
            ANAR_PROTOCOL_802_3 | ANAR_100BASE_TX_HD | ANAR_100BASE_TX_FD);
  mii_read(phy, PHY_ANAR, &val);
  printf_func("ETH: PHY ANAR (after write) = 0x%04x\n", val);
  // Speed bits are ignored while auto-negotiation is enabled; the negotiation
  // outcome is driven by the advertisements (GBCR + ANAR) above.
  mii_write(phy, PHY_BMCR, BMCR_ANENABLE | BMCR_RESTART_AUTONEG);
  mii_read(phy, PHY_BMCR, &val);
  printf_func("ETH: PHY BMCR (after write) = 0x%04x\n", val);

  // Wait for the link to come up (PHY re-negotiates with the switch). An
  // auto-negotiation restart takes ~2 s, so poll for a few seconds.
  for (retry = 0; retry < 2000; retry++) {
    if (!mii_read(phy, PHY_MII_STATUS, &val) && (val & MII_STATUS_LINK)) {
      printf_func("ETH: link up at 100 Mbps\n");
      mii_read(phy, PHY_ANLPAR, &val);
      printf_func("ETH: PHY ANLPAR = 0x%04x\n", val);
      return;
    }
    mii_delay(system_freq);
  }
  mii_read(phy, PHY_MII_STATUS, &val);
  printf_func("ETH: PHY STATUS (final)     = 0x%04x\n", val);
  mii_read(phy, PHY_ANLPAR, &val);
  printf_func("ETH: PHY ANLPAR (final)     = 0x%04x\n", val);
  printf_func("ETH: warning, no link detected after PHY configuration\n");
}

void eth_init(int base_address, uint32_t system_freq,
              void (*flush_cache_func)(void *start, size_t len),
              int (*printf_func_)(const char *format, ...)) {
  printf_func = printf_func_;
  eth_init_flush_cache(flush_cache_func);
#ifdef LOOPBACK
  eth_init_mac(base_address, ETH_MAC_ADDR, ETH_MAC_ADDR);
#else
  eth_init_mac(base_address, ETH_MAC_ADDR, ETH_RMAC_ADDR);
#endif
  eth_reset_bd_memory();
  eth_init_phy(system_freq);
}

void eth_init_flush_cache(void (*flush_cache_func)(void *, size_t)) {
  flush_cache = flush_cache_func;
}

// Use custom memory allocator
// Normally used to ensure that ethernet uses a memory region that is shared
// with the CPU. For example, in a system with various memories, ethernet may
// not have access to all of them. A custom allocator can be used to ensure that
// ethernet allocates and uses memory that it can access and shared with the CPU
void eth_init_mem_alloc(void *(*mem_alloc_func)(size_t),
                        void (*mem_free_func)(void *)) {
  mem_alloc = mem_alloc_func;
  mem_free = mem_free_func;
}

void eth_init_mac(int base_address, uint64_t mac_addr, uint64_t dest_mac_addr) {
  int i, ret;

  // set base address
  iob_eth_csrs_init_baseaddr(base_address);

  // dest mac address
  for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++) {
    TEMPLATE[MAC_DEST_PTR + i] = dest_mac_addr >> 40;
    dest_mac_addr = dest_mac_addr << 8;
  }

  // source mac address
  for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++) {
    TEMPLATE[MAC_SRC_PTR + i] = mac_addr >> 40;
    mac_addr = mac_addr << 8;
  }

#ifdef ETH_DEBUG_PRINT
  printf_func("\nSender: ");
  for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++) {
    printf_func("%02x ", (unsigned char)TEMPLATE[MAC_SRC_PTR + i]);
  }
  printf_func("\nDest: ");
  for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++) {
    printf_func("%02x ", (unsigned char)TEMPLATE[MAC_DEST_PTR + i]);
  }
  printf_func("\n");
#endif

  // eth type
  TEMPLATE[ETH_TYPE_PTR] = ETH_TYPE_H;
  TEMPLATE[ETH_TYPE_PTR + 1] = ETH_TYPE_L;

  //   // wait for PHY to produce rx clock
  //   while (!((iob_eth_csrs_get_status() >> 3) & 1))
  //     ;
  //
  // #ifdef ETH_DEBUG_PRINT
  //   printf_func("Ethernet RX clock detected\n");
  // #endif
  //
  //   // wait for PLL to lock and produce tx clock
  //   while (!((iob_eth_csrs_get_status() >> 15) & 1))
  //     ;
  //
  // #ifdef ETH_DEBUG_PRINT
  //   printf_func("Ethernet TX PLL locked\n");
  // #endif
  //
  //   // set initial payload size to Ethernet minimum excluding FCS
  //   iob_eth_csrs_set_tx_nbytes(46);
  //
  //   // check processor interface
  //   // write dummy register
  //   iob_eth_csrs_set_dummy_w(0xDEADBEEF);
  //
  //   // read and check result
  //   if (iob_eth_csrs_get_dummy_r() != 0xDEADBEEF) {
  //     printf_func("Ethernet Init failed\n");
  //   } else {
  //     printf_func("Ethernet Core Initialized\n");
  //   }
}

// Reset buffer descriptor memory
void eth_reset_bd_memory() {
  // Reset 128 buffer descriptors (64 bits each)
  for (int i = 0; i < 256; i++) {
    iob_eth_csrs_set_bd(0x00000000, i);
  }
}

// Get payload size from given buffer descriptor
unsigned short int eth_get_payload_size(unsigned int idx) {
  return iob_eth_csrs_get_bd(idx << 1) >> 16;
}

// Set payload size in given buffer descriptor
void eth_set_payload_size(unsigned int idx, unsigned int size) {
  iob_eth_csrs_set_bd((iob_eth_csrs_get_bd(idx << 1) & 0x0000ffff) | size << 16,
                      idx << 1);
}

void eth_send_frame(char *data, unsigned int size) {
  int i;

  // wait for ready
  while (!eth_tx_ready(0))
    ;

  // Alloc memory for frame
  char *frame_ptr = (char *)(*mem_alloc)(TEMPLATE_LEN + size);

  // Copy template to frame
  for (i = 0; i < TEMPLATE_LEN; i++)
    frame_ptr[i] = TEMPLATE[i];

  // Copy payload to frame
  for (i = 0; i < size; i++)
    frame_ptr[i + TEMPLATE_LEN] = data[i];

  // Flush cache (clean + invalidate) if function is defined, to write-back
  // dirty lines to memory so that DMA can read frame data. Tecnically we only
  // need to clean cache here. But we will re-use the flush function since its
  // already defined.
  if (flush_cache)
    (*flush_cache)(frame_ptr, TEMPLATE_LEN + size);

  /* Buffer descriptor configuration */

  // set frame pointer
  eth_set_ptr(0, frame_ptr);
  // set frame size
  eth_set_payload_size(0, TEMPLATE_LEN + size);

  // Set ready bit; Enable CRC and PAD; Set as last descriptor; Enable
  // interrupt.
  eth_set_ready(0, 1);
  eth_set_crc(0, 1);
  eth_set_pad(0, 1);
  eth_set_wr(0, 1);
  eth_set_interrupt(0, 1);

  // start sending
  eth_send(1);

  // wait for ready
  while (!eth_tx_ready(0))
    ;

  // Disable transmission and free memory
  eth_send(0);
  (*mem_free)(frame_ptr);

  return;
}

// prepare frame with ethernet template header
int eth_prepare_frame(char *external_frame) {
  // Copy template to frame
  for (int i = 0; i < TEMPLATE_LEN; i++)
    external_frame[i] = TEMPLATE[i];
  return TEMPLATE_LEN;
}

// eth_send_frame_addr()
// implementation for sending an already prepared frame at frame_address
void eth_send_frame_addr(unsigned int size, uint32_t frame_addr) {
  int i;

  // wait for ready
  while (!eth_tx_ready(0))
    ;

  /* Buffer descriptor configuration */

  // set frame pointer
  eth_set_ptr(0, frame_addr);
  // set frame size
  eth_set_payload_size(0, TEMPLATE_LEN + size);

  // Set ready bit; Enable CRC and PAD; Set as last descriptor; Enable
  // interrupt.
  eth_set_ready(0, 1);
  eth_set_crc(0, 1);
  eth_set_pad(0, 1);
  eth_set_wr(0, 1);
  eth_set_interrupt(0, 1);

  // start sending
  eth_send(1);

  // wait for ready
  while (!eth_tx_ready(0))
    ;

  // Disable transmission and free memory
  eth_send(0);

  return;
}

// eth_check_frame()
// Manual check for valid frame at frame_addr, copy data to data_rcv
int eth_check_frame(char *data_rcv, char *frame_ptr, unsigned int size) {
  int valid_frame = 1, i = 0;
  // Check destination MAC address to see if should ignore frame
  for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++)
    if (TEMPLATE[MAC_SRC_PTR + i] != frame_ptr[MAC_DEST_PTR + i]) {
      valid_frame = 0;
      break;
    }

  // Copy valid frame to data_rcv
  for (i = 0; (i < size) & (valid_frame); i++) {
    data_rcv[i] = frame_ptr[i + TEMPLATE_LEN];
  }

  return valid_frame;
}

// eth_receive_frame_addr()
// implementation for receiving a frame into frame_address
int eth_rcv_frame_addr(unsigned int size, int timeout, uint32_t frame_addr) {
  int i;
  int ignore;

  // set frame pointer
  eth_set_ptr(64, frame_addr);

  // Mark empty; Set as last descriptor; Enable interrupt.
  eth_set_empty(64, 1);
  eth_set_wr(64, 1);
  eth_set_interrupt(64, 1);

  // Enable reception
  eth_receive(1);

  // wait until data received
  while (!eth_rx_ready(64)) {
    timeout--;
    if (!timeout) {
      eth_receive(0);
      return ETH_NO_DATA;
    }
  }

  if (eth_bad_crc(64)) {
    eth_receive(0);
    printf_func("Bad CRC\n");
    return ETH_INVALID_CRC;
  }

  // Disable reception
  eth_receive(0);

  return ETH_DATA_RCV;
}

int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout) {
  int i;
  int cnt = timeout;
  int ignore;

  // Alloc memory for frame
  char *frame_ptr = (char *)(*mem_alloc)(HDR_LEN + ETH_NBYTES + 4);

  // Flush cache (clean + invalidate) if function is defined, to write-back
  // dirty lines to memory, and afterwards fetch newly DMA written frame data
  if (flush_cache)
    (*flush_cache)(frame_ptr, HDR_LEN + ETH_NBYTES + 4);

  // Copy template to frame
  // for (i=0; i < TEMPLATE_LEN; i++)
  //  frame_ptr[i] = TEMPLATE[i];

  do {
    // set frame pointer
    eth_set_ptr(64, frame_ptr);

    // Mark empty; Set as last descriptor; Enable interrupt.
    eth_set_empty(64, 1);
    eth_set_wr(64, 1);
    eth_set_interrupt(64, 1);

    // Enable reception
    eth_receive(1);

    // wait until data received
    while (!eth_rx_ready(64)) {
      timeout--;
      if (!timeout) {
        eth_receive(0);
        (*mem_free)((char *)frame_ptr);
        return ETH_NO_DATA;
      }
    }

    if (eth_bad_crc(64)) {
      eth_receive(0);
      (*mem_free)((char *)frame_ptr);
      printf_func("Bad CRC\n");
      return ETH_INVALID_CRC;
    }

    // Disable reception
    eth_receive(0);

    // Delay to ensure all DMA data is written to memory
    for (unsigned int i = 0; i < 10; i++)
      asm volatile("nop");

    // Check destination MAC address to see if should ignore frame
    ignore = 0;
    for (i = 0; i < IOB_ETH_MAC_ADDR_LEN; i++)
      if (TEMPLATE[MAC_SRC_PTR + i] != frame_ptr[MAC_DEST_PTR + i]) {
        ignore = 1;
        break;
      }

  } while (ignore);

  // Copy payload to return array
  for (i = 0; i < size; i++) {
    data_rcv[i] = frame_ptr[i + TEMPLATE_LEN];
  }

  (*mem_free)((char *)frame_ptr);

  return ETH_DATA_RCV;
}

#define MAX(A, B) ((A) > (B) ? (A) : (B))

static unsigned int rcv_timeout = 500000;
static char buffer[ETH_NBYTES + HDR_LEN];

void eth_set_receive_timeout(unsigned int timeout) { rcv_timeout = timeout; }

static void SyncAckFirst() {
  while (1) {
    // Send frame
    eth_send_frame(
        buffer,
        ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack

    // Wait to receive ack
    if (eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, rcv_timeout) == ETH_DATA_RCV)
      break;
  }
}

static void SyncAckLast() {
  // Wait to receive frame
  while (1) {
    // Wait to receive ack
    if (eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, rcv_timeout) == ETH_DATA_RCV)
      break;
  }

  eth_send_frame(
      buffer,
      ETH_MINIMUM_NBYTES); // Do not care what we send, any frame is the ack
}

static unsigned int eth_rcv_file_impl(char *data, int size) {
  int num_frames = ((size - 1) / ETH_NBYTES) + 1;
  unsigned int bytes_to_receive;
  unsigned int count_bytes = 0;
  int i, j;

  // Loop to receive intermediate data frames
  for (j = 0; j < num_frames; j++) {

    // check if it is last packet (has less data that full payload size)
    if (j == (num_frames - 1))
      bytes_to_receive = size - count_bytes;
    else
      bytes_to_receive = ETH_NBYTES;

    // wait to receive frame
    while (eth_rcv_frame(&data[count_bytes], bytes_to_receive, rcv_timeout))
      ;

    // send data back as ack
    eth_send_frame(&data[count_bytes],
                   MAX(bytes_to_receive, ETH_MINIMUM_NBYTES));

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
  int i, j;

  // Loop to send data
  for (j = 0; j < num_frames; j++) {

    // check if it is last packet (has less data that full payload size)
    if (j == (num_frames - 1))
      bytes_to_send = size - count_bytes;
    else
      bytes_to_send = ETH_NBYTES;

    // send frame
    eth_send_frame(&data[count_bytes], MAX(bytes_to_send, ETH_MINIMUM_NBYTES));

    // wait to receive frame as ack
    while (eth_rcv_frame(buffer, bytes_to_send, rcv_timeout))
      ;

    for (int i = 0; i < bytes_to_send; i++) {
      if (buffer[i] != data[count_bytes + i]) {
        error_bytes += 1;
        // printf_func("Error byte %d: %x %x\n",i,buffer[i], data[count_bytes +
        // i]);
        // //DEBUG
      }
    }

    // update byte counter
    count_bytes += bytes_to_send;
  }

  printf_func("File transmitted with %d errors...\n", error_bytes);

  return count_bytes;
}

unsigned int eth_rcv_file(char *data, int size) {

  SyncAckLast();

  return eth_rcv_file_impl(data, size);
}

unsigned int eth_send_file(char *data, int size) {

  SyncAckFirst();

  return eth_send_file_impl(data, size);
}

unsigned int eth_rcv_variable_file(char *data) {
  unsigned int size = 0;

  SyncAckLast();

  // Receive file size
  while (eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, rcv_timeout))
    ;

  // Send data back as ack
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);
  get_int(buffer, &size);

  return eth_rcv_file_impl(data, size);
}

unsigned int eth_send_variable_file(char *data, int size) {

  SyncAckFirst();

  // Send size
  set_int(buffer, size);
  eth_send_frame(buffer, ETH_MINIMUM_NBYTES);

  // Wait for ack
  while (eth_rcv_frame(buffer, ETH_MINIMUM_NBYTES, rcv_timeout))
    ;

  // Transfer file
  return eth_send_file_impl(data, size);
}

void eth_wait_phy_rst() {
  while (iob_eth_csrs_get_phy_rst_val())
    ;
}

void eth_print_status() {
  printf_func("tx_ready = %x\n", eth_tx_ready(0));
  printf_func("rx_ready = %x\n", eth_rx_ready(0));
  printf_func("Bad CRC = %x\n", eth_bad_crc(0));
}
