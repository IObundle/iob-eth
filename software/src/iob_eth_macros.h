/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef H_IOB_ETH_MACROS_H
#define H_IOB_ETH_MACROS_H

/**
 * @file
 * @brief Macros for IOb-Eth core.
 *
 * This file contains macros for various registers and flags in the IOb-Eth
 * core.
 */

#include "iob_eth_conf.h"
#include "iob_eth_rmac.h"

/** @name Mode Register Flags
 *  @{
 */
#define MODER_RXEN (1 << 0)   /**< Receive enable */
#define MODER_TXEN (1 << 1)   /**< Transmit enable */
#define MODER_NOPRE (1 << 2)  /**< No preamble */
#define MODER_BRO (1 << 3)    /**< Broadcast address */
#define MODER_IAM (1 << 4)    /**< Individual address mode */
#define MODER_PRO (1 << 5)    /**< Promiscuous mode */
#define MODER_IFG (1 << 6)    /**< Interframe gap for incoming frames */
#define MODER_LOOP (1 << 7)   /**< Loopback */
#define MODER_NBO (1 << 8)    /**< No back-off */
#define MODER_EDE (1 << 9)    /**< Excess defer enable */
#define MODER_FULLD (1 << 10) /**< Full duplex */
#define MODER_RESET (1 << 11) /**< FIXME: reset (undocumented) */
#define MODER_DCRC (1 << 12)  /**< Delayed CRC enable */
#define MODER_CRC (1 << 13)   /**< CRC enable */
#define MODER_HUGE (1 << 14)  /**< Huge packets enable */
#define MODER_PAD (1 << 15)   /**< Padding enabled */
#define MODER_RSM (1 << 16)   /**< Receive small packets */
/** @} */

/** @name Interrupt Source and Mask Registers
 *  @{
 */
#define INT_MASK_TXF (1 << 0)  /**< Transmit frame */
#define INT_MASK_TXE (1 << 1)  /**< Transmit error */
#define INT_MASK_RXF (1 << 2)  /**< Receive frame */
#define INT_MASK_RXE (1 << 3)  /**< Receive error */
#define INT_MASK_BUSY (1 << 4) /**< Busy */
#define INT_MASK_TXC (1 << 5)  /**< Transmit control frame */
#define INT_MASK_RXC (1 << 6)  /**< Receive control frame */

#define INT_MASK_TX (INT_MASK_TXF | INT_MASK_TXE) /**< Transmit interrupts */
#define INT_MASK_RX (INT_MASK_RXF | INT_MASK_RXE) /**< Receive interrupts */

/**
 * @def INT_MASK_ALL
 * @brief Mask for all interrupt sources.
 */
#define INT_MASK_ALL                                                           \
  (INT_MASK_TXF | INT_MASK_TXE | INT_MASK_RXF | INT_MASK_RXE | INT_MASK_TXC |  \
   INT_MASK_RXC | INT_MASK_BUSY)
/** @} */

/** @name Packet Length Register
 *  @{
 */
#define PACKETLEN_MIN(min)                                                     \
  (((min)&0xffff) << 16)                         /**< Minimum packet length    \
                                                  */
#define PACKETLEN_MAX(max) (((max)&0xffff) << 0) /**< Maximum packet length */
#define PACKETLEN_MIN_MAX(min, max)                                            \
  (PACKETLEN_MIN(min) | PACKETLEN_MAX(max)) /**< Min and max packet length */
/** @} */

/** @name Transmit Buffer Number Register
 *  @{
 */
#define TX_BD_NUM_VAL(x)                                                       \
  (((x) <= 0x80) ? (x) : 0x80) /**< Transmit buffer descriptor number */
/** @} */

/** @name Control Module Mode Register
 *  @{
 */
#define CTRLMODER_PASSALL (1 << 0) /**< Pass all receive frames */
#define CTRLMODER_RXFLOW (1 << 1)  /**< Receive control flow */
#define CTRLMODER_TXFLOW (1 << 2)  /**< Transmit control flow */
/** @} */

/** @name MII Mode Register
 *  @{
 */
#define MIIMODER_CLKDIV(x)                                                     \
  ((x)&0xfe) /**< Clock divider - needs to be an even number */
#define MIIMODER_NOPRE (1 << 8) /**< No preamble */
/** @} */

/** @name MII Command Register
 *  @{
 */
#define MIICOMMAND_SCAN (1 << 0)  /**< Scan status */
#define MIICOMMAND_READ (1 << 1)  /**< Read status */
#define MIICOMMAND_WRITE (1 << 2) /**< Write control data */
/** @} */

/** @name MII Address Register
 *  @{
 */
#define MIIADDRESS_FIAD(x) (((x)&0x1f) << 0) /**< PHY address */
#define MIIADDRESS_RGAD(x) (((x)&0x1f) << 8) /**< Register address */
#define MIIADDRESS_ADDR(phy, reg)                                              \
  (MIIADDRESS_FIAD(phy) | MIIADDRESS_RGAD(reg)) /**< PHY and register address  \
                                                 */
/** @} */

/** @name MII Transmit Data Register
 *  @{
 */
#define MIITX_DATA_VAL(x) ((x)&0xffff) /**< Transmit data */
/** @} */

/** @name MII Receive Data Register
 *  @{
 */
#define MIIRX_DATA_VAL(x) ((x)&0xffff) /**< Receive data */
/** @} */

/** @name MII Status Register
 *  @{
 */
#define MIISTATUS_LINKFAIL (1 << 0) /**< Link fail */
#define MIISTATUS_BUSY (1 << 1)     /**< Busy */
#define MIISTATUS_INVALID (1 << 2)  /**< Invalid data */
/** @} */

/** @name TX Buffer Descriptor
 *  @{
 */
#define TX_BD_CS (1 << 0)                  /**< Carrier sense lost */
#define TX_BD_DF (1 << 1)                  /**< Defer indication */
#define TX_BD_LC (1 << 2)                  /**< Late collision */
#define TX_BD_RL (1 << 3)                  /**< Retransmission limit */
#define TX_BD_RETRY_MASK (0x00f0)          /**< Retry mask */
#define TX_BD_RETRY(x) (((x)&0x00f0) >> 4) /**< Retry count */
#define TX_BD_UR (1 << 8)                  /**< Transmitter underrun */
#define TX_BD_CRC (1 << 11)                /**< TX CRC enable */
#define TX_BD_PAD (1 << 12)                /**< Pad enable for short packets */
#define TX_BD_WRAP (1 << 13)               /**< Wrap */
#define TX_BD_IRQ (1 << 14)                /**< Interrupt request enable */
#define TX_BD_READY (1 << 15)              /**< TX buffer ready */
#define TX_BD_LEN(x) (((x)&0xffff) << 16)  /**< Length of the buffer */
#define TX_BD_LEN_MASK                                                         \
  (0xffff << 16) /**< Mask for the length of the buffer                        \
                  */

#define TX_BD_STATS                                                            \
  (TX_BD_CS | TX_BD_DF | TX_BD_LC | TX_BD_RL | TX_BD_RETRY_MASK |              \
   TX_BD_UR) /**< TX buffer descriptor statistics */
/** @} */

/** @name RX Buffer Descriptor
 *  @{
 */
#define RX_BD_LC (1 << 0)                 /**< Late collision */
#define RX_BD_CRC (1 << 1)                /**< RX CRC error */
#define RX_BD_SF (1 << 2)                 /**< Short frame */
#define RX_BD_TL (1 << 3)                 /**< Too long */
#define RX_BD_DN (1 << 4)                 /**< Dribble nibble */
#define RX_BD_IS (1 << 5)                 /**< Invalid symbol */
#define RX_BD_OR (1 << 6)                 /**< Receiver overrun */
#define RX_BD_MISS (1 << 7)               /**< Miss */
#define RX_BD_CF (1 << 8)                 /**< Control frame */
#define RX_BD_WRAP (1 << 13)              /**< Wrap */
#define RX_BD_IRQ (1 << 14)               /**< Interrupt request enable */
#define RX_BD_EMPTY (1 << 15)             /**< RX buffer empty */
#define RX_BD_LEN(x) (((x)&0xffff) << 16) /**< Length of the buffer */

#define RX_BD_STATS                                                            \
  (RX_BD_LC | RX_BD_CRC | RX_BD_SF | RX_BD_TL | RX_BD_DN | RX_BD_IS |          \
   RX_BD_OR | RX_BD_MISS) /**< RX buffer descriptor statistics */
/** @} */

/** @name MAC Address
 *  @{
 */
#define ETH_MAC_ADDR 0x01606e11020f /**< Default MAC address */
/** @} */

/** @name Rx Return Codes
 *  @{
 */
#define ETH_INVALID_CRC -2 /**< Invalid CRC */
#define ETH_NO_DATA -1     /**< No data */
#define ETH_DATA_RCV 0     /**< Data received */
/** @} */

/** @name Frame Template Pointers
 *  @{
 */
#define MAC_DEST_PTR 0 /**< Destination MAC address pointer */
#define MAC_SRC_PTR                                                            \
  (MAC_DEST_PTR + IOB_ETH_MAC_ADDR_LEN) /**< Source MAC address pointer */
//#define TAG_PTR          (MAC_SRC_PTR + IOB_ETH_MAC_ADDR_LEN) // Optional -
// not supported
#define ETH_TYPE_PTR                                                           \
  (MAC_SRC_PTR + IOB_ETH_MAC_ADDR_LEN)        /**< Ethernet type pointer */
#define PAYLOAD_PTR (ETH_TYPE_PTR + 2)        /**< Payload pointer */
#define TEMPLATE_LEN (PAYLOAD_PTR)            /**< Template length */
#define DWORD_ALIGN(val) ((val + 0x3) & ~0x3) /**< Dword alignment */
/** @} */

/** @name Debug
 *  @{
 */
#define ETH_DEBUG_PRINT 1 /**< Enable debug prints */
/** @} */

/** @name RMAC Address
 *  @{
 */
#ifndef ETH_RMAC_ADDR
#define ETH_RMAC_ADDR ETH_MAC_ADDR /**< Default RMAC address if not defined */
#endif
/** @} */

#endif // H_IOB_ETH_MACROS_H
