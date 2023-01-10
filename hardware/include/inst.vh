   //
   // ETHERNET
   //

   iob_eth #(
     )
     eth
     (
      .clk      (clk),
      .rst      (reset),

      // external memory macros
      `include "iob_eth_buffer_portmap.vh"

      //cpu interface
      .valid(slaves_req[`valid(`ETHERNET)]),
      .address(slaves_req[`address(`ETHERNET, `iob_eth_swreg_ADDR_W+2)-2]),
      .wdata(slaves_req[`wdata(`ETHERNET)]),
      .wstrb(slaves_req[`wstrb(`ETHERNET)]),
      .rdata(slaves_resp[`rdata(`ETHERNET)]),
      .ready(slaves_resp[`ready(`ETHERNET)]),

      // ethernet interface
      .ETH_PHY_RESETN(ETH_PHY_RESETN),
      .PLL_LOCKED(PLL_LOCKED),

      .RX_CLK(RX_CLK),
      .RX_DATA(RX_DATA),
      .RX_DV(RX_DV),

      .TX_CLK(TX_CLK),
      .TX_DATA(TX_DATA),
      .TX_EN(TX_EN)
      );

