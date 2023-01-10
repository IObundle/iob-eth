   //ETHERNET
   // External Memory Macros
   `include "iob_eth_buffer_port.vh"

   output 		     ETH_PHY_RESETN,
   input 		     PLL_LOCKED,

   input 		     RX_CLK,
   input [3:0] 		     RX_DATA,
   input 		     RX_DV,

   input 		     TX_CLK,
   output 		     TX_EN,
   output [3:0] 	     TX_DATA,


