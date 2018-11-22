`timescale 1ns/1ps
`timescale 1ns/1ps
`define DEBUG

module faw_system_tb;

   parameter clk_period = 20;

   reg 			reset = 1'b1;
   reg 			clk = 1'b1;

   wire [3:0]		data12, data21;
   
   reg 			ETH_RX_CLK = 1'b1;
  
   reg [31:0] 		cw_link_Tx_0 = 32'h1;
   reg [7:0] 		cw_req_vector_Tx_0 = 8'd0;
   reg [31:0] 		cw_link_Rx_0;
   reg [7:0] 		cw_req_vector_Rx_0;

   wire 		ETH_TX_CLK, ETH_TX_EN1, ETH_RX_DV1, ETH_RESETN, ETH_MDC, ETH_TX_ERR1;
   wire 		ETH_TX_EN2, ETH_RX_DV2,  ETH_TX_ERR2;
   
   
   // Instantiate the Unit Under Test (UUT)
   faw_system uut1
     (
      .sys_clk(clk),
      .sys_rst(reset),

      // cwlink 0 tx
      .cw_link_Tx_0(cw_link_Tx_0),
      .cw_req_vector_Tx_0(cw_req_vector_Tx_0),
      // cwlink 0 rx
      .cw_link_Rx_0(),
      .cw_req_vector_Rx_0(),


      .MAC_PHY_tx_clk_pin(ETH_TX_CLK),
      .MAC_PHY_tx_en_pin(ETH_TX_EN1),
      .MAC_PHY_tx_error_pin(ETH_TX_ERR1),
      .MAC_PHY_tx_data_pin(data12),

      .MAC_PHY_rx_clk_pin(ETH_RX_CLK),
      .MAC_PHY_rx_dv_pin(ETH_TX_EN2),
      .MAC_PHY_rx_data_pin(data21),

      .MAC_PHY_rst_n(ETH_RESETN),
      .MAC_PHY_mdc(ETH_MDC)
      );
   
     faw_system uut2
     (
      .sys_clk(clk),
      .sys_rst(reset),

      // cwlink 0 tx
      .cw_link_Tx_0(32'b0),
      .cw_req_vector_Tx_0(8'b0),
      // cwlink 0 rx
      .cw_link_Rx_0(cw_link_Rx_0),
      .cw_req_vector_Rx_0(cw_req_vector_Rx_0),


      .MAC_PHY_tx_clk_pin(ETH_TX_CLK),
      .MAC_PHY_tx_en_pin(ETH_TX_EN2),
      .MAC_PHY_tx_error_pin(ETH_TX_ERR2),
      .MAC_PHY_tx_data_pin(data21),

      .MAC_PHY_rx_clk_pin(ETH_RX_CLK),
      .MAC_PHY_rx_dv_pin(ETH_TX_EN1),
      .MAC_PHY_rx_data_pin(data12),

      .MAC_PHY_rst_n(ETH_RESETN),
      .MAC_PHY_mdc(ETH_MDC)
      );
     
   initial begin

`ifdef DEBUG
      $dumpfile("faw_system.vcd");
      $dumpvars();
`endif

  
      #101 reset = 1'b0;

      #100 cw_req_vector_Tx_0 = 8'h01;
      cw_link_Tx_0 = 1;
      #20 cw_link_Tx_0 = 1;
      #20 cw_link_Tx_0 = 2;
      #20 cw_link_Tx_0 = 3;
      #20 cw_link_Tx_0 = 4;
      #20 cw_link_Tx_0 = 5;
      #20 cw_link_Tx_0 = 6;
      #20 cw_link_Tx_0 = 7;
      #20 cw_link_Tx_0 = 8;
      #20 cw_link_Tx_0 = 9;
      #20 cw_link_Tx_0 = 10;
      #20 cw_link_Tx_0 = 11;
      #20 cw_link_Tx_0 = 12;  
	
      #20 cw_req_vector_Tx_0 = 8'h00;
      
      #1000000 $finish;
    

   end // initial begin
         
   //system clock 
   always 
     #(clk_period/2) clk = ~clk;

   //rx clock 
   always 
     #(clk_period) ETH_RX_CLK= ~ETH_RX_CLK;

   //tx clock
   assign ETH_TX_CLK = ~ETH_RX_CLK;
   
endmodule // faw_system_tb

