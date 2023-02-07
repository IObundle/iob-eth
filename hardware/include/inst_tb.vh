
   //ethernet clock: 4x slower than system clock
   reg [1:0] eth_cnt = 2'b0;
   reg eth_clk;

   always @(posedge clk) begin
       eth_cnt <= eth_cnt + 1'b1;
       eth_clk <= eth_cnt[1];
   end

   // Ethernet Interface signals
   assign RX_CLK = eth_clk;
   assign TX_CLK = eth_clk;
   assign PLL_LOCKED = 1'b1;

//add core test module in testbench

iob_eth_tb_gen eth_tb(
      .clk      (clk),
      .reset    (rst),

      // This module acts like a loopback
      .RX_CLK(TX_CLK),
      .RX_DATA(TX_DATA),
      .RX_DV(TX_EN),

      // The wires are thus reversed
      .TX_CLK(RX_CLK),
      .TX_DATA(RX_DATA),
      .TX_EN(RX_DV)
);
