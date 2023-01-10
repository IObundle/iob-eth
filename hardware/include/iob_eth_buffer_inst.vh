    // TX Front-End
    wire                              iob_eth_tx_buffer_enA;
    wire [32/8-1:0]                   iob_eth_tx_buffer_weA;
    wire [`ETH_DATA_WR_ADDR_W-1:0]    iob_eth_tx_buffer_addrA;
    wire [32-1:0]                     iob_eth_tx_buffer_dinA;

    // TX Back-End
    wire [`ETH_DATA_WR_ADDR_W-1:0]    iob_eth_tx_buffer_addrB;
    wire [32-1:0]                      iob_eth_tx_buffer_doutB;

    // RX Front-End
    wire                              iob_eth_rx_buffer_enA;
    wire [32/8-1:0]                   iob_eth_rx_buffer_weA;
    wire [`ETH_DATA_RD_ADDR_W-1:0]    iob_eth_rx_buffer_addrA;
    wire [32-1:0]                     iob_eth_rx_buffer_dinA;

     // RX Back-End
    wire                              iob_eth_rx_buffer_enB;
    wire [`ETH_DATA_RD_ADDR_W-1:0]    iob_eth_rx_buffer_addrB;
    wire [32-1:0]                      iob_eth_rx_buffer_doutB;

   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_WR_ADDR_W)
                       )
   tx_buffer
   (
    // Front-End (written by host)
      .clkA(clk),
      .enA(iob_eth_tx_buffer_enA),
      .weA(iob_eth_tx_buffer_weA),
      .addrA(iob_eth_tx_buffer_addrA),
      .dinA(iob_eth_tx_buffer_dinA),
      .doutA(),

    // Back-End (read by core)
      .clkB(TX_CLK),
      .enB(1'b1),
      .weB(4'b0),
      .addrB(iob_eth_tx_buffer_addrB),
      .dinB(32'b0),
      .doutB(iob_eth_tx_buffer_doutB)
   );

   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_RD_ADDR_W)
                       )
   rx_buffer
   (
     // Front-End (written by core)
     .clkA(RX_CLK),

     .enA(iob_eth_rx_buffer_enA),
     .weA(iob_eth_rx_buffer_weA),
     .addrA(iob_eth_rx_buffer_addrA),
     .dinA(iob_eth_rx_buffer_dinA),
     .doutA(),

     // Back-End (read by host)
     .clkB(clk),
     .enB(iob_eth_rx_buffer_enB),
     .weB(4'b0),
     .addrB(iob_eth_rx_buffer_addrB),
     .dinB(32'b0),
     .doutB(iob_eth_rx_buffer_doutB)
   );
