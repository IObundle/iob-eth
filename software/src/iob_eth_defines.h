/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef H_IOB_ETH_DEFINES_H
#define H_IOB_ETH_DEFINES_H

/**
 * @file
 * @brief Macros for controlling the IOb-Eth core.
 */

#include "eth_frame_struct.h"

#include "iob_eth_conf.h"
#include "iob_eth_csrs.h"
#include "iob_eth_macros.h"

/**
 * @def eth_tx_ready(idx)
 * @brief Check if the transmit buffer descriptor is ready.
 * @param idx Index of the buffer descriptor.
 * @return 1 if ready, 0 otherwise.
 */
#define eth_tx_ready(idx) !((iob_eth_csrs_get_bd(idx << 1) & TX_BD_READY) || 0)

/**
 * @def eth_rx_ready(idx)
 * @brief Check if the receive buffer descriptor is ready.
 * @param idx Index of the buffer descriptor.
 * @return 1 if ready, 0 otherwise.
 */
#define eth_rx_ready(idx) eth_tx_ready(idx)

/**
 * @def eth_bad_crc(idx)
 * @brief Check if the received frame has a bad CRC.
 * @param idx Index of the buffer descriptor.
 * @return 1 if CRC is bad, 0 otherwise.
 */
#define eth_bad_crc(idx) ((iob_eth_csrs_get_bd(idx << 1) & RX_BD_CRC) || 0)

/**
 * @def eth_send(enable)
 * @brief Enable or disable the transmitter.
 * @param enable 1 to enable, 0 to disable.
 */
#define eth_send(enable)                                                       \
  ({                                                                           \
    iob_eth_csrs_set_moder(iob_eth_csrs_get_moder() & ~MODER_TXEN |            \
                           (enable ? MODER_TXEN : 0));                         \
  })

/**
 * @def eth_receive(enable)
 * @brief Enable or disable the receiver.
 * @param enable 1 to enable, 0 to disable.
 */
#define eth_receive(enable)                                                    \
  ({                                                                           \
    iob_eth_csrs_set_moder(iob_eth_csrs_get_moder() & ~MODER_RXEN |            \
                           (enable ? MODER_RXEN : 0));                         \
  })

/**
 * @def eth_set_ready(idx, enable)
 * @brief Set the ready flag for a transmit buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to set as ready, 0 otherwise.
 */
#define eth_set_ready(idx, enable)                                             \
  ({                                                                           \
    iob_eth_csrs_set_bd(iob_eth_csrs_get_bd(idx << 1) & ~TX_BD_READY |         \
                            (enable ? TX_BD_READY : 0),                        \
                        idx << 1);                                             \
  })
/**
 * @def eth_set_empty(idx, enable)
 * @brief Set the empty flag for a receive buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to set as empty, 0 otherwise.
 */
#define eth_set_empty(idx, enable) eth_set_ready(idx, enable)

/**
 * @def eth_set_interrupt(idx, enable)
 * @brief Enable or disable interrupts for a buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to enable, 0 to disable.
 */
#define eth_set_interrupt(idx, enable)                                         \
  ({                                                                           \
    iob_eth_csrs_set_bd(iob_eth_csrs_get_bd(idx << 1) & ~TX_BD_IRQ |           \
                            (enable ? TX_BD_IRQ : 0),                          \
                        idx << 1);                                             \
  })

/**
 * @def eth_set_wr(idx, enable)
 * @brief Set the wrap flag for a buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to set the wrap flag, 0 otherwise.
 */
#define eth_set_wr(idx, enable)                                                \
  ({                                                                           \
    iob_eth_csrs_set_bd(iob_eth_csrs_get_bd(idx << 1) & ~TX_BD_WRAP |          \
                            (enable ? TX_BD_WRAP : 0),                         \
                        idx << 1);                                             \
  })

/**
 * @def eth_set_crc(idx, enable)
 * @brief Enable or disable CRC generation for a transmit buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to enable CRC, 0 to disable.
 */
#define eth_set_crc(idx, enable)                                               \
  ({                                                                           \
    iob_eth_csrs_set_bd(iob_eth_csrs_get_bd(idx << 1) & ~TX_BD_CRC |           \
                            (enable ? TX_BD_CRC : 0),                          \
                        idx << 1);                                             \
  })

/**
 * @def eth_set_pad(idx, enable)
 * @brief Enable or disable padding for a transmit buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param enable 1 to enable padding, 0 to disable.
 */
#define eth_set_pad(idx, enable)                                               \
  ({                                                                           \
    iob_eth_csrs_set_bd(iob_eth_csrs_get_bd(idx << 1) & ~TX_BD_PAD |           \
                            (enable ? TX_BD_PAD : 0),                          \
                        idx << 1);                                             \
  })

/**
 * @def eth_set_ptr(idx, ptr)
 * @brief Set the data pointer for a buffer descriptor.
 * @param idx Index of the buffer descriptor.
 * @param ptr Pointer to the data buffer.
 */
#define eth_set_ptr(idx, ptr)                                                  \
  ({ iob_eth_csrs_set_bd((uint32_t)(uintptr_t)ptr, (idx << 1) + 1); })

#endif // H_IOB_ETH_DEFINES_H
