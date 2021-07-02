
//add core test module in testbench

iob_eth_tb_gen eth_tb(
      .clk      (clk),
      .reset    (reset),

      // This module acts like a loopback
      .RX_CLK(TX_CLK),
      .RX_DATA(TX_DATA),
      .RX_DV(TX_EN),

      // The wires are thus reversed
      .TX_CLK(RX_CLK),
      .TX_DATA(RX_DATA),
      .TX_EN(RX_DV)
);
