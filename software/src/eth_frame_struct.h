/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

/**
 * @file
 * @brief Defines related to the ethernet frame structure.
 */

/**
 * @def ETH_TYPE_H
 * @brief High byte of the Ethernet frame type.
 */
#define ETH_TYPE_H 0x60
/**
 * @def ETH_TYPE_L
 * @brief Low byte of the Ethernet frame type.
 */
#define ETH_TYPE_L 0x00

/**
 * @def ETH_NBYTES
 * @brief Maximum number of bytes in the Ethernet payload.
 */
#define ETH_NBYTES 1500
/**
 * @def ETH_MINIMUM_NBYTES
 * @brief Minimum number of bytes in the Ethernet payload.
 */
#define ETH_MINIMUM_NBYTES (64 - 18)

/**
 * @def HDR_LEN
 * @brief Length of the Ethernet header.
 */
#define HDR_LEN (2 * IOB_ETH_MAC_ADDR_LEN + 2)
