/*
 * SPDX-FileCopyrightText: 2026 IObundle
 *
 * SPDX-License-Identifier: GPL-3.0-only
 *
 * Baremetal firmware that emulates the Linux ethoc.c driver behavior for
 * debugging the RX path of iob_eth. This replicates ethoc_probe, ethoc_reset,
 * ethoc_init_ring, ethoc_rx, and ethoc_start_xmit from the Linux driver so
 * that RX failures can be debugged without Linux overhead.
 */

#include "clint.h"
#include "iob_bsp.h"
#include "iob_printf.h"
#include "iob_system_linux_conf.h"
#include "iob_system_linux_mmap.h"
#include "iob_uart16550.h"
#include "iob_eth.h"
#include "iob_eth_csrs.h"
#include "iob_eth_macros.h"
#include "iob_eth_defines.h"
#include "iob_plic.h"
#include "iob_timer.h"
#include "riscv-csr.h"
#include "riscv-interrupts.h"
#include <string.h>

/* ================================================================
 * Constants matching ethoc.c
 * ================================================================ */

#define ETH0_PLIC_SOURCE 2

#define NUM_TX 64
#define NUM_RX 64
#define NUM_BD (NUM_TX + NUM_RX) /* 128 */

#define ETHOC_BUFSIZ 1536
#define ETHOC_BD_BASE 0x400

/*
 * DMA buffer region in DDR (24-bit AXI address range).
 * TX buffers: TX_BUF_BASE .. TX_BUF_BASE + NUM_TX * ETHOC_BUFSIZ - 1
 * RX buffers: immediately after TX
 */
#define BUF_BASE 0x00100000

/* Register offsets (matching ethoc.c exactly) */
#define REG_MODER 0x00
#define REG_INT_SOURCE 0x04
#define REG_INT_MASK 0x08
#define REG_IPGT 0x0c
#define REG_IPGR1 0x10
#define REG_IPGR2 0x14
#define REG_PACKETLEN 0x18
#define REG_COLLCONF 0x1c
#define REG_TX_BD_NUM 0x20
#define REG_CTRLMODER 0x24
#define REG_MIIMODER 0x28
#define REG_MIICOMMAND 0x2c
#define REG_MIIADDRESS 0x30
#define REG_MIITX_DATA 0x34
#define REG_MIIRX_DATA 0x38
#define REG_MIISTATUS 0x3c
#define REG_MAC_ADDR0 0x40
#define REG_MAC_ADDR1 0x44
#define REG_ETH_HASH0 0x48
#define REG_ETH_HASH1 0x4c
#define REG_ETH_TXCTRL 0x50

/* ================================================================
 * Globals
 * ================================================================ */

static volatile int rx_irq_count = 0;
static volatile int tx_irq_count = 0;
static volatile int total_irq_count = 0;
static unsigned int cur_rx = 0;

/* ================================================================
 * Cache flush (VexRiscv specific)
 * ================================================================ */

static void clear_cache(void) {
  for (unsigned int i = 0; i < 10; i++)
    asm volatile("nop");
  asm volatile(".word 0x500F" ::: "memory");
}

/* ================================================================
 * ethoc-style raw register access (matches ioread32/iowrite32)
 * ================================================================ */

static inline uint32_t ethoc_read(uint32_t offset) {
  return iob_read(ETH0_BASE + offset, 32);
}

static inline void ethoc_write(uint32_t offset, uint32_t data) {
  iob_write(ETH0_BASE + offset, 32, data);
}

/* ================================================================
 * ethoc_bd structure and BD read/write (matches ethoc.c exactly)
 * ================================================================ */

struct ethoc_bd {
  uint32_t stat;
  uint32_t addr;
};

static inline void ethoc_read_bd(int index, struct ethoc_bd *bd) {
  uint32_t offset = ETHOC_BD_BASE + (index * sizeof(struct ethoc_bd));
  bd->stat = ethoc_read(offset + 0);
  bd->addr = ethoc_read(offset + 4);
}

static inline void ethoc_write_bd(int index, const struct ethoc_bd *bd) {
  uint32_t offset = ETHOC_BD_BASE + (index * sizeof(struct ethoc_bd));
  ethoc_write(offset + 0, bd->stat);
  ethoc_write(offset + 4, bd->addr);
}

/* ================================================================
 * IRQ handler (machine mode)
 * ================================================================ */

#pragma GCC push_options
#pragma GCC optimize("align-functions=2")
static void irq_entry(void) __attribute__((interrupt("machine")));
static void irq_entry(void) {
  uint32_t mcause;
  asm volatile("csrr %0, mcause" : "=r"(mcause));

  if (mcause & MCAUSE_INTERRUPT_BIT_MASK) {
    uint32_t pending = plic_read(PLIC_PENDING_BASE);
    if (pending & (1 << ETH0_PLIC_SOURCE)) {
      total_irq_count++;

      /* Read ethoc-style interrupt source and mask */
      uint32_t mask = ethoc_read(REG_INT_MASK);
      uint32_t source = ethoc_read(REG_INT_SOURCE);
      uint32_t triggered = source & mask;

      printf("  [IRQ] INT_SOURCE=0x%08X INT_MASK=0x%08X triggered=0x%08X\n",
             source, mask, triggered);

      /* ACK ethoc interrupt (write-1-to-clear) */
      if (triggered)
        ethoc_write(REG_INT_SOURCE, triggered);

      /* Count TX vs RX */
      if (triggered & INT_MASK_TXF)
        tx_irq_count++;
      if (triggered & INT_MASK_RXF)
        rx_irq_count++;

      /* Claim + complete PLIC */
      uint32_t claim = plic_claim_interrupt(0);
      plic_complete_interrupt(0, claim);
    }
  }
}
#pragma GCC pop_options

static void set_trap_vector(void (*handler)(void)) {
  uintptr_t addr = (uintptr_t)handler;
  asm volatile("csrw mtvec, %0" : : "r"(addr));
}

/* ================================================================
 * Helper: print all ETH registers
 * ================================================================ */

static void print_all_registers(void) {
  printf("\n  === ETH Register Dump ===\n");
  printf("  MODER       = 0x%08X", ethoc_read(REG_MODER));
  {
    uint32_t m = ethoc_read(REG_MODER);
    printf(" (RXEN=%d TXEN=%d CRC=%d PAD=%d FULLD=%d PRO=%d BRO=%d LOOP=%d)\n",
           (m >> 0) & 1, (m >> 1) & 1, (m >> 13) & 1, (m >> 15) & 1,
           (m >> 10) & 1, (m >> 5) & 1, (m >> 3) & 1, (m >> 7) & 1);
  }
  printf("  INT_SOURCE  = 0x%08X\n", ethoc_read(REG_INT_SOURCE));
  printf("  INT_MASK    = 0x%08X\n", ethoc_read(REG_INT_MASK));
  printf("  IPGT        = 0x%08X\n", ethoc_read(REG_IPGT));
  printf("  IPGR1       = 0x%08X\n", ethoc_read(REG_IPGR1));
  printf("  IPGR2       = 0x%08X\n", ethoc_read(REG_IPGR2));
  printf("  PACKETLEN   = 0x%08X\n", ethoc_read(REG_PACKETLEN));
  printf("  COLLCONF    = 0x%08X\n", ethoc_read(REG_COLLCONF));
  printf("  TX_BD_NUM   = 0x%08X (%d)\n", ethoc_read(REG_TX_BD_NUM),
         ethoc_read(REG_TX_BD_NUM));
  printf("  CTRLMODER   = 0x%08X\n", ethoc_read(REG_CTRLMODER));
  printf("  MAC_ADDR0   = 0x%08X\n", ethoc_read(REG_MAC_ADDR0));
  printf("  MAC_ADDR1   = 0x%08X\n", ethoc_read(REG_MAC_ADDR1));
  printf("  MIIMODER    = 0x%08X\n", ethoc_read(REG_MIIMODER));
  printf("  PHY_RST_VAL = %d\n", iob_eth_csrs_get_phy_rst_val());
  printf("  VERSION     = 0x%06X\n", iob_eth_csrs_get_version());
}

/* ================================================================
 * Helper: print RX BD ring status
 * ================================================================ */

static void print_rx_bd_ring(void) {
  printf("\n  === RX BD Ring (BD[%d]..BD[%d]), cur_rx=%u ===\n", NUM_TX,
         NUM_BD - 1, cur_rx);
  for (int i = NUM_TX; i < NUM_BD; i++) {
    struct ethoc_bd bd;
    ethoc_read_bd(i, &bd);
    printf("  BD[%3d]: stat=0x%08X addr=0x%08X %s%s%s%s%s\n", i, bd.stat,
           bd.addr, (bd.stat & RX_BD_EMPTY) ? "EMPTY" : "HAS_DATA",
           (bd.stat & RX_BD_IRQ) ? " IRQ" : "",
           (bd.stat & RX_BD_WRAP) ? " WRAP" : "",
           (bd.stat & RX_BD_CRC) ? " CRC_ERR" : "",
           (bd.stat & RX_BD_TL) ? " TOO_LONG" : "");
  }
}

/* ================================================================
 * Helper: print TX BD ring (just the active ones)
 * ================================================================ */

static void print_tx_bd_ring(void) {
  printf("\n  === TX BD Ring (BD[0]..BD[%d]) ===\n", NUM_TX - 1);
  for (int i = 0; i < NUM_TX; i++) {
    struct ethoc_bd bd;
    ethoc_read_bd(i, &bd);
    if (bd.stat & TX_BD_READY)
      continue; /* skip not-yet-used BDs */
    printf("  BD[%3d]: stat=0x%08X addr=0x%08X %s%s\n", i, bd.stat, bd.addr,
           (bd.stat & TX_BD_READY) ? "READY" : "DONE",
           (bd.stat & TX_BD_WRAP) ? " WRAP" : "");
  }
}

/* ================================================================
 * MII helpers (same as existing firmware)
 * ================================================================ */

static uint16_t mii_read(int phy, int reg_addr) {
  ethoc_write(REG_MIIADDRESS, MIIADDRESS_ADDR(phy, reg_addr));
  ethoc_write(REG_MIICOMMAND, MIICOMMAND_READ);
  int timeout = 100000;
  while (ethoc_read(REG_MIISTATUS) & MIISTATUS_BUSY) {
    timeout--;
    if (timeout <= 0)
      break;
  }
  ethoc_write(REG_MIICOMMAND, 0);
  if (timeout == 0)
    printf("    [!] mii_read(phy=%d, reg=%d) TIMEOUT\n", phy, reg_addr);
  return ethoc_read(REG_MIIRX_DATA) & 0xFFFF;
}

static void mii_write(int phy, int reg_addr, uint16_t val) {
  ethoc_write(REG_MIIADDRESS, MIIADDRESS_ADDR(phy, reg_addr));
  ethoc_write(REG_MIITX_DATA, MIITX_DATA_VAL(val));
  ethoc_write(REG_MIICOMMAND, MIICOMMAND_WRITE);
  int timeout = 100000;
  while (ethoc_read(REG_MIISTATUS) & MIISTATUS_BUSY) {
    timeout--;
    if (timeout <= 0)
      break;
  }
  ethoc_write(REG_MIICOMMAND, 0);
  if (timeout == 0)
    printf("    [!] mii_write(phy=%d, reg=%d) TIMEOUT\n", phy, reg_addr);
}

static void debug_phy_connection(void) {
  printf("\n--- Starting Ethernet PHY Connection Debug Tests ---\n");

  ethoc_write(REG_MIIMODER, MIIMODER_CLKDIV(40));

  int found_phy_addr = -1;
  printf("Scanning MII PHY addresses (0-31):\n");
  for (int phy = 0; phy < 32; phy++) {
    uint16_t id1 = mii_read(phy, 2);
    uint16_t id2 = mii_read(phy, 3);
    if (id1 != 0x0000 && id1 != 0xFFFF) {
      printf("  [+] Found PHY at address %d: ID1=0x%04X, ID2=0x%04X\n", phy,
             id1, id2);
      found_phy_addr = phy;
    }
  }

  if (found_phy_addr == -1) {
    printf("  [!] ERROR: No PHY found on MII management bus!\n");
    printf("--- Ethernet PHY Connection Debug Tests Complete ---\n\n");
    return;
  }

  int phy = found_phy_addr;
  printf("\nReading registers for PHY at address %d:\n", phy);

  uint16_t bmcr = mii_read(phy, 0);
  uint16_t bmsr = mii_read(phy, 1);

  printf("  Reg 0 (Control): 0x%04X\n", bmcr);
  printf("    - Reset: %d\n", (bmcr >> 15) & 1);
  printf("    - Auto-Negotiation Enable: %d\n", (bmcr >> 12) & 1);
  printf("    - Power Down: %d\n", (bmcr >> 11) & 1);
  printf("    - Speed: %s\n", ((bmcr >> 13) & 1) ? "100 Mbps" : "10 Mbps");
  printf("    - Duplex: %s\n", (bmcr >> 8) & 1 ? "Full" : "Half");

  printf("  Reg 1 (Status): 0x%04X\n", bmsr);
  printf("    - Auto-Negotiation Complete: %d\n", (bmsr >> 5) & 1);
  printf("    - Link Status: %s\n", (bmsr >> 2) & 1 ? "UP" : "DOWN");

  printf("--- Ethernet PHY Connection Debug Tests Complete ---\n\n");
}

/* ================================================================
 * emulating ethoc_reset()
 * ================================================================ */

static void ethoc_disable_rx_and_tx(void) {
  uint32_t mode = ethoc_read(REG_MODER);
  mode &= ~(MODER_RXEN | MODER_TXEN);
  ethoc_write(REG_MODER, mode);
}

static void ethoc_enable_rx_and_tx(void) {
  uint32_t mode = ethoc_read(REG_MODER);
  mode |= MODER_RXEN | MODER_TXEN;
  ethoc_write(REG_MODER, mode);
}

static void ethoc_disable_irq(uint32_t mask) {
  uint32_t imask = ethoc_read(REG_INT_MASK);
  imask &= ~mask;
  ethoc_write(REG_INT_MASK, imask);
}

static void ethoc_enable_irq(uint32_t mask) {
  uint32_t imask = ethoc_read(REG_INT_MASK);
  imask |= mask;
  ethoc_write(REG_INT_MASK, imask);
}

static void ethoc_ack_irq(uint32_t mask) { ethoc_write(REG_INT_SOURCE, mask); }

static void do_ethoc_reset(void) {
  uint32_t mode;

  printf("\n--- do_ethoc_reset (emulating ethoc_reset) ---\n");

  /* Disable RX and TX first */
  ethoc_disable_rx_and_tx();

  /* Enable FCS generation and automatic padding */
  mode = ethoc_read(REG_MODER);
  mode |= MODER_CRC | MODER_PAD;
  ethoc_write(REG_MODER, mode);

  /* Set full-duplex mode */
  mode = ethoc_read(REG_MODER);
  mode |= MODER_FULLD;
  ethoc_write(REG_MODER, mode);

  /* Set inter-packet gap (matching ethoc_reset) */
  ethoc_write(REG_IPGT, 0x15);

  /* ACK all interrupts */
  ethoc_ack_irq(INT_MASK_ALL);

  /* Enable all interrupts */
  ethoc_enable_irq(INT_MASK_ALL);

  /* Enable RX and TX */
  ethoc_enable_rx_and_tx();

  printf("  MODER after reset = 0x%08X\n", ethoc_read(REG_MODER));
  printf("  INT_MASK          = 0x%08X\n", ethoc_read(REG_INT_MASK));
  printf("  IPGT              = 0x%08X\n", ethoc_read(REG_IPGT));
}

/* ================================================================
 * emulating ethoc_init_ring()
 * ================================================================ */

static void do_ethoc_init_ring(void) {
  struct ethoc_bd bd;
  int i;

  printf("\n--- do_ethoc_init_ring (emulating ethoc_init_ring) ---\n");

  /* Set TX_BD_NUM: boundary between TX and RX BDs */
  ethoc_write(REG_TX_BD_NUM, NUM_TX);
  printf("  TX_BD_NUM = %d\n", NUM_TX);

  /* Setup TX BDs (indices 0 to NUM_TX-1) */
  bd.addr = BUF_BASE;
  bd.stat = TX_BD_IRQ | TX_BD_CRC;

  for (i = 0; i < NUM_TX; i++) {
    if (i == NUM_TX - 1)
      bd.stat |= TX_BD_WRAP;
    ethoc_write_bd(i, &bd);
    bd.addr += ETHOC_BUFSIZ;
  }
  printf("  TX BDs: 0..%d configured, first addr=0x%08X\n", NUM_TX - 1,
         BUF_BASE);

  /* Setup RX BDs (indices NUM_TX to NUM_BD-1) */
  bd.stat = RX_BD_EMPTY | RX_BD_IRQ;

  for (i = 0; i < NUM_RX; i++) {
    if (i == NUM_RX - 1)
      bd.stat |= RX_BD_WRAP;
    ethoc_write_bd(NUM_TX + i, &bd);
    bd.addr += ETHOC_BUFSIZ;
  }
  printf("  RX BDs: %d..%d configured, first addr=0x%08X\n", NUM_TX, NUM_BD - 1,
         BUF_BASE + NUM_TX * ETHOC_BUFSIZ);

  /* Verify: read back first and last of each ring */
  {
    struct ethoc_bd verify;
    ethoc_read_bd(0, &verify);
    printf("  Verify BD[0]:   stat=0x%08X addr=0x%08X\n", verify.stat,
           verify.addr);
    ethoc_read_bd(NUM_TX - 1, &verify);
    printf("  Verify BD[%d]: stat=0x%08X addr=0x%08X\n", NUM_TX - 1,
           verify.stat, verify.addr);
    ethoc_read_bd(NUM_TX, &verify);
    printf("  Verify BD[%d]: stat=0x%08X addr=0x%08X\n", NUM_TX, verify.stat,
           verify.addr);
    ethoc_read_bd(NUM_BD - 1, &verify);
    printf("  Verify BD[%d]: stat=0x%08X addr=0x%08X\n", NUM_BD - 1,
           verify.stat, verify.addr);
  }
}

/* ================================================================
 * emulating ethoc_rx() - poll RX BDs for received frames
 * ================================================================ */

static int do_ethoc_rx(int limit) {
  int count;
  int packets_received = 0;

  for (count = 0; count < limit; count++) {
    unsigned int entry = NUM_TX + cur_rx;
    struct ethoc_bd bd;

    ethoc_read_bd(entry, &bd);

    if (bd.stat & RX_BD_EMPTY) {
      /*
       * No packet. ACK RX interrupt to clear any pending (matching ethoc_rx
       * race-condition handling in ethoc.c lines 432-443).
       */
      ethoc_ack_irq(INT_MASK_RX);

      /* Re-read to check for race condition */
      ethoc_read_bd(entry, &bd);
      if (bd.stat & RX_BD_EMPTY) {
        /* Still empty, no packet waiting */
        printf("  BD[%u] EMPTY, no packet (cur_rx=%u)\n", entry, cur_rx);
        break;
      }
    }

    /* Packet received! */
    packets_received++;
    int size = bd.stat >> 16;
    printf("\n  [RX] Packet at BD[%u]: size=%d stat=0x%08X addr=0x%08X\n",
           entry, size, bd.stat, bd.addr);

    /* Check for errors (matching ethoc_update_rx_stats) */
    if (bd.stat & RX_BD_CRC)
      printf("  [RX] !! CRC ERROR\n");
    if (bd.stat & RX_BD_TL)
      printf("  [RX] !! TOO LONG\n");
    if (bd.stat & RX_BD_SF)
      printf("  [RX] !! SHORT FRAME\n");
    if (bd.stat & RX_BD_DN)
      printf("  [RX] !! DRIBBLE NIBBLE\n");
    if (bd.stat & RX_BD_OR)
      printf("  [RX] !! OVERRUN\n");
    if (bd.stat & RX_BD_MISS)
      printf("  [RX] !! MISS\n");
    if (bd.stat & RX_BD_LC)
      printf("  [RX] !! LATE COLLISION\n");

    /* Hex dump of received data (first 64 bytes or less) */
    if (size > 0) {
      uint8_t *data = (uint8_t *)(uintptr_t)bd.addr;
      clear_cache(); /* Invalidate cache to see DMA-written data */
      int dump_len = size > 64 ? 64 : size;
      printf("  [RX] Data (%d bytes):\n    ", dump_len);
      for (int j = 0; j < dump_len; j++) {
        printf("%02X ", data[j]);
        if ((j + 1) % 16 == 0 && j + 1 < dump_len)
          printf("\n    ");
      }
      printf("\n");
    }

    /* Clear stats and re-arm BD (matching ethoc_rx cleanup, lines 471-473) */
    bd.stat &= ~RX_BD_STATS;
    bd.stat |= RX_BD_EMPTY;
    ethoc_write_bd(entry, &bd);

    /* Advance ring index (matching ethoc.c line 474) */
    if (++cur_rx == NUM_RX)
      cur_rx = 0;
  }

  return packets_received;
}

/* ================================================================
 * emulating ethoc_start_xmit() - send a test frame via TX BD 0
 * ================================================================ */

static void ethoc_send_test_frame(void) {
  struct ethoc_bd bd;
  uint8_t
      frame[64]; /* Minimum Ethernet frame (60 bytes + 4 CRC auto-appended) */
  uint32_t frame_addr = BUF_BASE; /* TX BD 0's buffer */

  static int tx_count = 0;
  tx_count++;

  /* Build frame */
  memset(frame, 0xFF, 6); /* Destination: broadcast */
  frame[6] = 0x0A;        /* Source MAC: 0A:35:00:00:00:01 */
  frame[7] = 0x35;
  frame[8] = 0x00;
  frame[9] = 0x00;
  frame[10] = 0x00;
  frame[11] = 0x01;
  frame[12] = 0x60; /* Ethertype: 0x6000 */
  frame[13] = 0x00;
  /* Embed counter in payload for identification */
  frame[14] = (tx_count >> 24) & 0xFF;
  frame[15] = (tx_count >> 16) & 0xFF;
  frame[16] = (tx_count >> 8) & 0xFF;
  frame[17] = (tx_count >> 0) & 0xFF;
  memset(frame + 18, 0x00, sizeof(frame) - 18);

  memcpy((void *)(uintptr_t)frame_addr, frame, sizeof(frame));
  clear_cache();

  /* Wait for TX BD 0 to be ready (matching ethoc_start_xmit) */
  struct ethoc_bd read_bd;
  ethoc_read_bd(0, &read_bd);
  if (read_bd.stat & TX_BD_READY) {
    printf("  [TX] BD[0] still READY, skipping send\n");
    return;
  }

  /*
   * Setup TX BD 0 (matching ethoc_start_xmit lines 914-920):
   *   Clear stats, set length, set READY bit.
   */
  read_bd.stat &= ~(TX_BD_STATS | TX_BD_LEN_MASK);
  read_bd.stat |= TX_BD_LEN(sizeof(frame));
  read_bd.addr = frame_addr;
  ethoc_write_bd(0, &read_bd);

  /* Set READY bit (triggers hardware transmission) */
  read_bd.stat |= TX_BD_READY;
  ethoc_write_bd(0, &read_bd);

  printf("  [TX] Sent test frame #%d, len=%d, BD[0] stat=0x%08X\n", tx_count,
         (int)sizeof(frame), read_bd.stat);
}

/* ================================================================
 * Poll TX BD 0 for completion (matching ethoc_tx)
 * ================================================================ */

static void ethoc_check_tx(void) {
  struct ethoc_bd bd;
  ethoc_read_bd(0, &bd);

  if (!(bd.stat & TX_BD_READY)) {
    /* TX completed */
    printf("  [TX] BD[0] completed: stat=0x%08X", bd.stat);
    if (bd.stat & TX_BD_CS)
      printf(" CARRIER_LOST");
    if (bd.stat & TX_BD_LC)
      printf(" LATE_COLLISION");
    if (bd.stat & TX_BD_RL)
      printf(" RETRANS_LIMIT");
    if (bd.stat & TX_BD_UR)
      printf(" UNDERRUN");
    printf("\n");
  }
}

/* ================================================================
 * Main
 * ================================================================ */

int main() {
  uart16550_init(UART0_BASE, IOB_BSP_FREQ / (16 * IOB_BSP_BAUD));
  printf_init(&uart16550_putc);

  printf("\n");
  printf("============================================\n");
  printf("  ethoc-emulation RX debug test\n");
  printf("  (baremetal replication of Linux ethoc.c)\n");
  printf("============================================\n\n");

  /* ---- Initialize ethernet (basic setup) ---- */
  iob_eth_csrs_init_baseaddr(ETH0_BASE);
  eth_wait_phy_rst();

  /* ---- PHY connection debug ---- */
  debug_phy_connection();

  /* ---- Setup PLIC + IRQ handler ---- */
  printf("--- IRQ Setup ---\n");
  set_trap_vector(irq_entry);
  plic_init(PLIC0_BASE);
  plic_set_priority(ETH0_PLIC_SOURCE, 1);
  plic_enable_interrupt(0, ETH0_PLIC_SOURCE);
  printf("  PLIC eth0 source %d enabled\n", ETH0_PLIC_SOURCE);

  /* Enable machine-level global interrupts */
  csr_set_bits_mstatus(MSTATUS_MIE_BIT_MASK);
  /* Also enable machine external interrupt specifically */
  csr_set_bits_mie(RISCV_INT_MASK_MEI);
  printf("  Machine interrupts enabled\n");

  /* ---- ethoc_reset: configure MODER, IPGT, interrupts ---- */
  do_ethoc_reset();

  /* ---- ethoc_init_ring: set up BD ring ---- */
  do_ethoc_init_ring();

  /* ---- Full register dump ---- */
  print_all_registers();

  /* ---- Print MAC address ---- */
  {
    uint32_t ma0 = ethoc_read(REG_MAC_ADDR0);
    uint32_t ma1 = ethoc_read(REG_MAC_ADDR1);
    printf("\n  MAC Address: %02X:%02X:%02X:%02X:%02X:%02X\n",
           (ma1 >> 8) & 0xFF, ma1 & 0xFF, (ma0 >> 24) & 0xFF,
           (ma0 >> 16) & 0xFF, (ma0 >> 8) & 0xFF, ma0 & 0xFF);
  }

  /* ---- Main loop ---- */
  printf("\n--- Main loop: TX test every ~2s, poll RX continuously ---\n");
  printf("  Send packets to this device to test RX.\n\n");

  int loop_count = 0;
  int tx_interval = 2000000; /* approximate loop iterations between TX */
  int status_interval = 1000000;
  int tx_timer = tx_interval - 100000; /* send first frame quickly */
  int status_timer = 0;

  while (1) {
    loop_count++;

    /* ---- Periodic TX ---- */
    tx_timer++;
    if (tx_timer >= tx_interval) {
      tx_timer = 0;
      ethoc_send_test_frame();
    }

    /* ---- TX completion check ---- */
    ethoc_check_tx();

    /* ---- RX poll (emulating ethoc_poll -> ethoc_rx) ---- */
    int rx = do_ethoc_rx(NUM_RX);
    if (rx > 0) {
      printf("\n  [POLL] Received %d packet(s)\n", rx);
      printf("  [STATS] total_irq=%d rx_irq=%d tx_irq=%d cur_rx=%u\n",
             total_irq_count, rx_irq_count, tx_irq_count, cur_rx);
    }

    /* ---- Periodic status dump ---- */
    status_timer++;
    if (status_timer >= status_interval) {
      status_timer = 0;
      printf(
          "\n  [STATUS] loop=%d total_irq=%d rx_irq=%d tx_irq=%d cur_rx=%u\n",
          loop_count, total_irq_count, rx_irq_count, tx_irq_count, cur_rx);
      print_all_registers();
      print_rx_bd_ring();
      print_tx_bd_ring();
    }
  }

  return 0;
}
