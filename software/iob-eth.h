#include "eth_frame_struct.h"

// fields
#define ETH_TX_READY          0
#define ETH_RX_READY          1
#define ETH_PHY_DV            2
#define ETH_PHY_CLK           3
#define ETH_RX_WR_ADDR        4
#define ETH_TX_CLK_PLL_LOCKED 5

#define ETH_MAC_ADDR 0x01606e11020f

#define ETH_INVALID_CRC -2
#define ETH_NO_DATA -1
#define ETH_DATA_RCV 0

// driver functions
void eth_init(int base);

int eth_get_status(void);

int eth_get_status(char field);

void eth_set_send(char value);

void eth_set_rcvack(char value);

void eth_set_soft_rst(char value);

void eth_set_tx_payload_size(unsigned int size);

void eth_set_rx_payload_size(unsigned int size);

int eth_get_crc(void);

void eth_set_data(int i, char data);

char eth_get_data(int i);

void eth_init_frame(void);

void eth_send_frame(char *data_to_send, unsigned int size);

/* Function name: eth_rcv_frame
 * Inputs:
 * 	- data_rcv: char array where data received will be saved
 * 	- size: number of bytes to be received
 * 	- timeout: number of cycles (approximately) in which the data should be received
 * Output: 
 * 	- Return -1 if timeout occurs (no data received), or 0 if data is
 * 	successfully received
 */
int eth_rcv_frame(char *data_rcv, unsigned int size, int timeout);

unsigned int eth_rcv_file(char *data, int size);

unsigned int eth_send_file(char *data, int size);

void eth_print_status(void);

#define eth_tx_ready() eth_get_status(ETH_TX_READY)

#define eth_rx_ready() eth_get_status(ETH_RX_READY)

#define eth_phy_dv() eth_get_status(ETH_PHY_DV)

#define eth_phy_clk() eth_get_status(ETH_PHY_CLK)

#define eth_rx_wr_addr() eth_get_status(ETH_RX_WR_ADDR)

#define eth_tx_clk_pll_locked() eth_get_status(ETH_TX_CLK_PLL_LOCKED)

#define eth_send() eth_set_send(1)

#define eth_ack() eth_set_rcvack(1)

#define eth_soft_rst() ({\
      eth_set_soft_rst(1);\
      eth_set_soft_rst(0);\
    })
