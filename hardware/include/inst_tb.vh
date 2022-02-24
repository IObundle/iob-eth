
   //ethernet clock
   parameter eth_per = clk_per * 4;
   reg eth_clk = 1;
   always #(eth_per/2) eth_clk = ~eth_clk;

   // Ethernet Interface signals
   assign RX_CLK = eth_clk;
   assign TX_CLK = eth_clk;
   assign PLL_LOCKED = 1'b1;

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
