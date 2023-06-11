   //ETHERNET
   // External Memory Macros
   // TX Front-End
   output                              iob_eth_tx_buffer_enA,
   output [32/8-1:0]                   iob_eth_tx_buffer_weA,
   output [`ETH_DATA_WR_ADDR_W-1:0]    iob_eth_tx_buffer_addrA,
   output [32-1:0]                     iob_eth_tx_buffer_dinA,

   // TX Back-End
   output [`ETH_DATA_WR_ADDR_W-1:0]    iob_eth_tx_buffer_addrB,
   input [32-1:0]                      iob_eth_tx_buffer_doutB,

   // RX Front-End
   output                              iob_eth_rx_buffer_enA,
   output [32/8-1:0]                   iob_eth_rx_buffer_weA,
   output [`ETH_DATA_RD_ADDR_W-1:0]    iob_eth_rx_buffer_addrA,
   output [32-1:0]                     iob_eth_rx_buffer_dinA,

    // RX Back-End
   output                              iob_eth_rx_buffer_enB,
   output [`ETH_DATA_RD_ADDR_W-1:0]    iob_eth_rx_buffer_addrB,
   input [32-1:0]                      iob_eth_rx_buffer_doutB,

   output 		     ETH_PHY_RESETN,
   input 		     PLL_LOCKED,

   input 		     RX_CLK,
   input [3:0] 		     RX_DATA,
   input 		     RX_DV,

   input 		     TX_CLK,
   output 		     TX_EN,
   output [3:0] 	     TX_DATA,


