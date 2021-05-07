//add core test module in testbench

   iob_eth eth_tb
     (
      .clk       (clk),
      .rst       (reset),
      
      // CPU side
      .valid      (eth_valid),
      .wstrb      (eth_wstrb),
      .addr       (eth_addr),
      .data_in    (eth_data_in),
      .data_out   (eth_data_out),

      //PLL
      .PLL_LOCKED(1'b1),
                
      //PHY
      .ETH_PHY_RESETN (ETH_PHY_RESETN),

      .TX_CLK     (TX_CLK),
      .TX_DATA    (TX_DATA),
      .TX_EN      (TX_EN),

      .RX_CLK     (RX_CLK),
      .RX_DATA    (RX_DATA),
      .RX_DV      (RX_DV)
      );

