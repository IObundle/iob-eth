   //
   // ETHERNET
   //

   iob_eth #(
      .AXI_ADDR_W(`DDR_ADDR_W)     
     )
     eth
     (
      .clk      (clk),
      .rst      (reset),

      //cpu interface
      .valid(slaves_req[`valid(`ETHERNET)]),
      .addr(slaves_req[`address(`ETHERNET, `ETH_ADDR_W+2)-2]),
      .data_in(slaves_req[`wdata(`ETHERNET)]),
      .wstrb(slaves_req[`wstrb(`ETHERNET)]),
      .data_out(slaves_resp[`rdata(`ETHERNET)]),
      .ready(slaves_resp[`ready(`ETHERNET)]),

      // AXI4 master interface
      //address write
      .m_axi_awid(m_axi_awid[1*1+:1]), 
      .m_axi_awaddr(m_axi_awaddr[1*`DDR_ADDR_W+:`DDR_ADDR_W]), 
      .m_axi_awlen(m_axi_awlen[1*8+:8]), 
      .m_axi_awsize(m_axi_awsize[1*3+:3]), 
      .m_axi_awburst(m_axi_awburst[1*2+:2]), 
      .m_axi_awlock(m_axi_awlock[1*1+:1]), 
      .m_axi_awcache(m_axi_awcache[1*4+:4]), 
      .m_axi_awprot(m_axi_awprot[1*3+:3]),
      .m_axi_awqos(m_axi_awqos[1*4+:4]), 
      .m_axi_awvalid(m_axi_awvalid[1*1+:1]), 
      .m_axi_awready(m_axi_awready[1*1+:1]), 
      //write
      .m_axi_wdata(m_axi_wdata[1*32+:32]), 
      .m_axi_wstrb(m_axi_wstrb[1*32/8+:32/8]), 
      .m_axi_wlast(m_axi_wlast[1*1+:1]), 
      .m_axi_wvalid(m_axi_wvalid[1*1+:1]), 
      .m_axi_wready(m_axi_wready[1*1+:1]), 
      //write response
      .m_axi_bid(1'b0), 
      .m_axi_bresp(m_axi_bresp[1*2+:2]), 
      .m_axi_bvalid(m_axi_bvalid[1*1+:1]), 
      .m_axi_bready(m_axi_bready[1*1+:1]), 
      //address read
      .m_axi_arid(m_axi_arid[1*1+:1]), 
      .m_axi_araddr(m_axi_araddr[1*`DDR_ADDR_W+:`DDR_ADDR_W]), 
      .m_axi_arlen(m_axi_arlen[1*8+:8]), 
      .m_axi_arsize(m_axi_arsize[1*3+:3]), 
      .m_axi_arburst(m_axi_arburst[1*2+:2]), 
      .m_axi_arlock(m_axi_arlock[1*1+:1]), 
      .m_axi_arcache(m_axi_arcache[1*4+:4]), 
      .m_axi_arprot(m_axi_arprot[1*3+:3]), 
      .m_axi_arqos(m_axi_arqos[1*4+:4]), 
      .m_axi_arvalid(m_axi_arvalid[1*1+:1]), 
      .m_axi_arready(m_axi_arready[1*1+:1]), 
      //read 
      .m_axi_rid(1'b0), 
      .m_axi_rdata(m_axi_rdata[1*32+:32]), 
      .m_axi_rresp(m_axi_rresp[1*2+:2]), 
      .m_axi_rlast(m_axi_rlast[1*1+:1]), 
      .m_axi_rvalid(m_axi_rvalid[1*1+:1]),  
      .m_axi_rready(m_axi_rready[1*1+:1]),

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

