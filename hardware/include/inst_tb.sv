
//add core test module in testbench

reg [7:0] counter;

reg running;
reg disableRunning;

assign RX_DATA = counter[3:0];
assign RX_DV = running;

always @(posedge clk,posedge reset)
begin
      if(reset || disableRunning)
      begin
            running <= 1'b0;
      end 
      else
      if(uut.eth.valid && uut.eth.addr == 1)
      begin
            running <= 1'b1;
      end
end

always @(posedge RX_CLK,posedge reset)
begin
      if(reset)
      begin
            counter <= 0;
            disableRunning <= 0;
      end

      if(running)
      begin
            counter <= counter + 1;
            if(&counter)
            begin
                  disableRunning <= 1'b1;
            end
      end
end

/*
   iob_eth eth_tb
     (
      .clk       (clk),
      .rst       (reset),
      
      // CPU side
      .valid      (eth_valid),
      .wstrb      (|eth_wstrb),
      .addr       (eth_addr),
      .data_in    (eth_data_in),
      .data_out   (eth_data_out),

      //PLL
      .PLL_LOCKED(1'b1),
                
      //PHY
      .ETH_PHY_RESETN (ETH_PHY_RESETN),

      .TX_CLK     (RX_CLK),
      .TX_DATA    (RX_DATA),
      .TX_EN      (RX_DV),

      .RX_CLK     (TX_CLK),
      .RX_DATA    (TX_DATA),
      .RX_DV      (TX_EN)
      );
*/
