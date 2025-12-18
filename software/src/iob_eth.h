/*
 * SPDX-FileCopyrightText: 2025 IObundle
 *
 * SPDX-License-Identifier: MIT
 */

/**
 * @file iob_eth.h
 * @brief High-level driver functions for the IOb-Eth ethernet controller.
 *
 * This file provides the function declarations for interacting with the IOb-Eth
 * hardware core.
 */

#include "stdint.h"
#include <stdlib.h>

/**
 * @brief Initializes the Ethernet core.
 *
 * @param base_address The base memory address of the Ethernet core.
 * @param clear_cache_func Function pointer to a function that clears the data
 * cache.
 */
void eth_init(int base_address, void (*clear_cache_func)(void));

/**
 * @brief Set the cache clearing function.
 * @param clear_cache_func Function pointer to a function that clears the data
 * cache.
 */
void eth_init_clear_cache(void (*clear_cache_func)(void));

/**
 * @brief Set the memory allocation and free functions.
 * @param mem_alloc_func Function pointer for memory allocation.
 * @param mem_free_func Function pointer for memory freeing.
 */
void eth_init_mem_alloc(void *(*mem_alloc_func)(size_t),
                        void (*mem_free_func)(void *));

/**
 * @brief Initializes the MAC address and destination MAC address.
 *
 * @param base_address The base memory address of the Ethernet core.
 * @param mac_addr The MAC address of the device.
 * @param dest_mac_addr The destination MAC address.
 */
void eth_init_mac(int base_address, uint64_t mac_addr, uint64_t dest_mac_addr);

/**
 * @brief Resets the buffer descriptor memory.
 *
 */
void eth_reset_bd_memory();

/**
 * @brief Gets the payload size of a received frame.
 *
 * @param idx Index of the buffer descriptor.
 * @return unsigned short int The size of the payload.
 */
unsigned short int eth_get_payload_size(unsigned int idx);

/**
 * @brief Sets the payload size of a frame to be sent.
 *
 * @param idx Index of the buffer descriptor.
 * @param size The size of the payload.
 */
void eth_set_payload_size(unsigned int idx, unsigned int size);

/**
 * @brief Sends an Ethernet frame.
 * @warning Care when using this function directly, too small a size or too
 * large might not work (frame does not get sent)
 *
 * @param data_to_send Pointer to the data to be sent.
 * @param size Size of the data to be sent.
 */
void eth_send_frame(char *data_to_send, unsigned int size);

/**
 * @brief Prepare frame with ethernet template header.
 *
 * @param external_frame should have at least TEMPLATE_LEN size.
 * @return int 0 on success.
 */
int eth_prepare_frame(char *external_frame);

/**
 * @brief Send an already prepared frame from a specific memory address.
 *
 * @param size The size of the frame to send.
 * @param frame_addr The memory address of the frame.
 */
void eth_send_frame_addr(unsigned int size, uint32_t frame_addr);

/**
 * @brief Manual check for a valid frame at a specific memory address and copies
 * its data.
 *
 * @param data_rcv Buffer to store the received data.
 * @param frame_ptr Pointer to the frame to check.
 * @param size The expected size of the frame.
 * @return int 0 if a valid frame is found and copied, -1 otherwise.
 */
int eth_check_frame(char *data_rcv, char *frame_ptr, unsigned int size);

/**
 * @brief Receives a frame into a specific memory address.
 *
 * @param size The expected size of the frame.
 * @param timeout The number of cycles to wait for the frame.
 * @param frame_addr The memory address to store the received frame.
 * @return int 0 if the frame is successfully received, -1 on timeout.
 */
int eth_rcv_frame_addr(unsigned int size, int timeout, uint32_t frame_addr);

/**
 * @brief Receives an Ethernet frame.
 *
 * @param data_rcv Buffer to store the received data.
 * @param size The number of bytes to be received.
 * @param timeout The number of cycles (approximately) in which the data should
 * be received.
 * @return int 0 if data is successfully received, -1 if a timeout occurs.
 */
int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout);

/**
 * @brief Sets the receive timeout value.
 *
 * @param timeout The timeout value in cycles.
 */
void eth_set_receive_timeout(unsigned int timeout);

/**
 * @brief Receives a file over Ethernet.
 *
 * @param data Buffer to store the received file data.
 * @param size The size of the file to receive.
 * @return unsigned int The number of bytes received.
 */
unsigned int eth_rcv_file(char *data, int size);

/**
 * @brief Sends a file over Ethernet.
 *
 * @param data Pointer to the file data to send.
 * @param size The size of the file to send.
 * @return unsigned int The number of bytes sent.
 */
unsigned int eth_send_file(char *data, int size);

/**
 * @brief Receives a file of variable size.
 *
 * @param data Buffer to store the received file data.
 * @return unsigned int The size of the received file.
 */
unsigned int eth_rcv_variable_file(char *data);

/**
 * @brief Sends a file of variable size.
 *
 * @param data Pointer to the file data to send.
 * @param size The size of the file to send.
 * @return unsigned int The number of bytes sent.
 */
unsigned int eth_send_variable_file(char *data, int size);

/**
 * @brief Waits for the PHY to reset.
 *
 */
void eth_wait_phy_rst();

/**
 * @brief Prints the status of the Ethernet core.
 *
 */
void eth_print_status();
