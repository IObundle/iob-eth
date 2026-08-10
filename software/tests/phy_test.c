/*
 * SPDX-FileCopyrightText: 2026 IObundle
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include "iob_eth.h"
#include "iob_eth_csrs.h"
#include "iob_eth_macros.h"

static uint16_t mii_read(int phy, int reg_addr) {
  iob_eth_csrs_set_miiaddress(MIIADDRESS_ADDR(phy, reg_addr));
  iob_eth_csrs_set_miicommand(MIICOMMAND_READ);
  int timeout = 100000;
  while (iob_eth_csrs_get_miicommand() && timeout > 0)
    timeout--;
  iob_eth_csrs_set_miicommand(0);
  if (timeout == 0)
    printf("    [!] mii_read(phy=%d, reg=%d) TIMEOUT\n", phy, reg_addr);
  return iob_eth_csrs_get_miirx_data() & 0xFFFF;
}

static void mii_write(int phy, int reg_addr, uint16_t val) {
  iob_eth_csrs_set_miiaddress(MIIADDRESS_ADDR(phy, reg_addr));
  iob_eth_csrs_set_miitx_data(MIITX_DATA_VAL(val));
  iob_eth_csrs_set_miicommand(MIICOMMAND_WRITE);
  int timeout = 100000;
  while (iob_eth_csrs_get_miicommand() && timeout > 0)
    timeout--;
  iob_eth_csrs_set_miicommand(0);
  if (timeout == 0)
    printf("    [!] mii_write(phy=%d, reg=%d) TIMEOUT\n", phy, reg_addr);
}

void debug_phy_connection() {
  printf("\n--- Starting Ethernet PHY Connection Debug Tests ---\n");

  // Initialize MII management clock division (MDC clock <= 2.5 MHz)
  // Assuming frequency is around 50MHz, divider 40 gives 1.25 MHz.
  iob_eth_csrs_set_miimoder(MIIMODER_CLKDIV(40));

  // 1. Scan MII bus to discover the PHY address
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

  // 2. Read and print standard PHY registers for the found PHY
  int phy = found_phy_addr;
  printf("\nReading registers for PHY at address %d:\n", phy);

  uint16_t bmcr = mii_read(phy, 0);      // Basic Mode Control Register
  uint16_t bmsr = mii_read(phy, 1);      // Basic Mode Status Register
  uint16_t advertise = mii_read(phy, 4); // Auto-Negotiation Advertisement
  uint16_t lpa = mii_read(phy, 5); // Auto-Negotiation Link Partner Ability

  printf("  Reg 0 (Control): 0x%04X\n", bmcr);
  printf("    - Reset: %d\n", (bmcr >> 15) & 1);
  printf("    - Loopback: %d\n", (bmcr >> 14) & 1);
  printf("    - Speed Selection: %s\n",
         ((bmcr >> 13) & 1) ? "100 Mbps" : "10 Mbps");
  printf("    - Auto-Negotiation Enable: %d\n", (bmcr >> 12) & 1);
  printf("    - Power Down: %d\n", (bmcr >> 11) & 1);
  printf("    - Duplex Mode: %s\n", (bmcr >> 8) & 1 ? "Full" : "Half");

  printf("  Reg 1 (Status): 0x%04X\n", bmsr);
  printf("    - Auto-Negotiation Complete: %d\n", (bmsr >> 5) & 1);
  printf("    - Link Status: %s\n", (bmsr >> 2) & 1 ? "UP" : "DOWN");

  printf("  Reg 4 (AN Advertisement): 0x%04X\n", advertise);
  printf("  Reg 5 (AN Link Partner Ability): 0x%04X\n", lpa);

  // 3. Check link status (before write test to avoid AN disruption)
  printf("\nChecking link status...\n");
  uint16_t status = mii_read(phy, 1);
  int link_up = (status & (1 << 2)) != 0;

  if (link_up) {
    printf("  [+] SUCCESS: Ethernet link is UP!\n");
    bmcr = mii_read(phy, 0);
    printf("  Speed: %s, Duplex: %s\n",
           ((bmcr >> 13) & 1) ? "100 Mbps" : "10 Mbps",
           (bmcr >> 8) & 1 ? "Full" : "Half");
  } else {
    printf("  [!] WARNING: Ethernet link is DOWN. Please check cable "
           "connection.\n");
  }

  // 4. Test writing to some register to verify write communication
  printf("\nTesting MII write to PHY...\n");
  uint16_t orig_bmcr = bmcr;
  uint16_t test_bmcr = orig_bmcr | (1 << 14); // loopback bit
  mii_write(phy, 0, test_bmcr);
  uint16_t read_bmcr = mii_read(phy, 0);
  if (read_bmcr & (1 << 14)) {
    printf("  [+] Write test successful: Loopback bit set in Reg 0.\n");
  } else {
    printf("  [!] ERROR: Write test failed! Read back 0x%04X, expected bit 14 "
           "set.\n",
           read_bmcr);
  }
  // Restore original control register
  mii_write(phy, 0, orig_bmcr);

  printf("--- Ethernet PHY Connection Debug Tests Complete ---\n\n");
}

int main() {
  // Run PHY connection debug tests
  debug_phy_connection();
}
