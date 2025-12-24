/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

/**
 * @file
 * @brief Memory map for the IOb-Eth core registers.
 */

/**
 * @def ETH_STATUS
 * @brief Offset for the status register.
 */
#define ETH_STATUS 0
/**
 * @def ETH_SEND
 * @brief Offset for the send control register.
 */
#define ETH_SEND 1
/**
 * @def ETH_RCVACK
 * @brief Offset for the receive acknowledge register.
 */
#define ETH_RCVACK 2
/**
 * @def ETH_SOFTRST
 * @brief Offset for the software reset register.
 */
#define ETH_SOFTRST 4
/**
 * @def ETH_DUMMY
 * @brief Offset for the dummy register.
 */
#define ETH_DUMMY 5
/**
 * @def ETH_TX_NBYTES
 * @brief Offset for the transmit number of bytes register.
 */
#define ETH_TX_NBYTES 6
/**
 * @def ETH_RX_NBYTES
 * @brief Offset for the receive number of bytes register.
 */
#define ETH_RX_NBYTES 7
/**
 * @def ETH_CRC
 * @brief Offset for the CRC register.
 */
#define ETH_CRC 8
/**
 * @def ETH_RCV_SIZE
 * @brief Offset for the receive size register.
 */
#define ETH_RCV_SIZE 9
/**
 * @def ETH_DATA
 * @brief Offset for the data buffer.
 */
#define ETH_DATA 2048
