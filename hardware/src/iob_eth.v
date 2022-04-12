`timescale 1ns/1ps

`include "axi.vh"
`include "iob_lib.vh"
`include "iob_eth.vh"
`include "iob_eth_swreg_def.vh"

/*
 Ethernet Core
*/

module iob_eth 
    # (
    parameter DATA_W = 32, //PARAM CPU data width
    parameter ADDR_W = `iob_eth_swreg_ADDR_W, //MACRO CPU address section width
    parameter ETH_MAC_ADDR = `ETH_MAC_ADDR
    )
    (
    // CPU interface
    `include "iob_s_if.vh"

    //START_IO_TABLE eth_phy
    // PHY side
    `IOB_OUTPUT_VAR(ETH_PHY_RESETN, 1), //PHY reset

    // PLL
    `IOB_INPUT(PLL_LOCKED, 1), //PLL locked

    // RX
    `IOB_INPUT(RX_CLK, 1), //RX clock
    `IOB_INPUT(RX_DATA, 4), //RX data nibble
    `IOB_INPUT(RX_DV, 1), //RX DV signal

    // TX
    `IOB_INPUT(TX_CLK, 1), //TX clock
    `IOB_OUTPUT(TX_EN, 1), //TX enable
    `IOB_OUTPUT(TX_DATA, 4), //TX data nibble

    `include "gen_if.vh"
    );

    //BLOCK Register File & Configuration control and status register file.
    `include "iob_eth_swreg.vh"
    `include "iob_eth_swreg_gen.vh"

    //
    // WIRES and REGISTERS
    //
    `IOB_WIRE(rst_int, 1)

    // ETH CLOCK DOMAIN
    `IOB_VAR(phy_clk_detected, 1)
    `IOB_VAR(phy_dv_detected, 1)
    `IOB_WIRE(crc_value, `ETH_CRC_W)
    `IOB_WIRE(tx_ready_int, 1)
    `IOB_WIRE(rx_data_rcvd_int, 1)

    `IOB_WIRE(tx_rd_addr, 9)
    `IOB_WIRE(tx_rd_data, 32)

    `IOB_WIRE(rx_wr_addr, 11)
    `IOB_WIRE(rx_wr_data, 8)
    `IOB_WIRE(rx_wr, 1)

    // Ethernet Status
    `IOB_WIRE(pll_locked_sync, 1)
    `IOB_WIRE(phy_clk_detected_sync, 1)
    `IOB_WIRE(phy_dv_detected_sync, 1)
    `IOB_WIRE(rx_data_rcvd_sync, 1)
    `IOB_WIRE(tx_ready_sync, 1)

    assign ETH_STATUS = {16'b0, pll_locked_sync, ETH_RCV_SIZE, phy_clk_detected_sync, phy_dv_detected_sync, rx_data_rcvd_sync, tx_ready_sync};

    // Ethernet Dummy R - copy value from ETH_DUMMY_W
    assign ETH_DUMMY_R = ETH_DUMMY_W;

    // Ethernet CRC
    //TODO: check CDC for multibit words

    // Ethernet RCV_SIZE
    //TODO: check CDC for multibit words

    // Ethernet Send
    `IOB_VAR(send_en, 1)
    // Self clearing register
    `IOB_REG_RE(clk, (rst_int | send_en), 1'b0, ETH_SEND, send_en, ETH_SEND) 

    // Ethernet Rcv Ack
    `IOB_VAR(rcv_ack_en, 1)
    // Self clearing register
    `IOB_REG_RE(clk, (rst_int | rcv_ack_en), 1'b0, ETH_RCVACK, rcv_ack_en, ETH_RCVACK) 

   //
   // REGISTERS
   //

   // soft reset self-clearing register
   `IOB_VAR(rst_soft, 1)
   always @ (posedge clk, posedge rst)
     if (rst)
       rst_soft <= 1'b1;
     else if (ETH_SOFTRST && !rst_soft)
       rst_soft <= 1'b1;
     else
       rst_soft <= 1'b0;

   assign rst_int = rst_soft | rst;

   //
   // SYNCHRONIZERS
   //

   // RX_CLK to clk

   `IOB_SYNC(clk, rst_int, 1'b0, 1, PLL_LOCKED, pll_locked_sync_reg0, pll_locked_sync_reg1, pll_locked_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 11, rx_wr_addr, rx_wr_addr_sync_reg0, rx_wr_addr_sync_reg1, ETH_RCV_SIZE)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, phy_clk_detected, phy_clk_detected_sync_reg0, phy_clk_detected_sync_reg1, phy_clk_detected_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, phy_dv_detected, phy_dv_detected_sync_reg0, phy_dv_detected_sync_reg1, phy_dv_detected_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, (rx_data_rcvd_int & ETH_PHY_RESETN), rx_data_rcvd_sync_reg0, rx_data_rcvd_sync_reg1, rx_data_rcvd_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, (tx_ready_int & ETH_PHY_RESETN & PLL_LOCKED), tx_ready_sync_reg0, tx_ready_sync_reg1, tx_ready_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, `ETH_CRC_W, crc_value, crc_value_sync_reg0, crc_value_sync_reg1, ETH_CRC)

   // clk to RX_CLK
   `IOB_VAR(send, 1)
   `IOB_F2S_SYNC(TX_CLK, send_en, send_sync, send)
   `IOB_VAR(rcv_ack, 1)
   `IOB_F2S_SYNC(RX_CLK, rcv_ack_en, rck_ack_sync, rcv_ack)

   //
   // TX and RX BUFFERS
   //

   iob_ram_t2p #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_WR_ADDR_W)
                       )
   tx_buffer
   (
    // Front-End (written by host)
      .w_clk(clk),
      .w_addr(ETH_DATA_WR_addr_int),
      .w_en(|ETH_DATA_WR_wstrb_int),
      .w_data(ETH_DATA_WR_wdata_int),

    // Back-End (read by core)
      .r_clk(TX_CLK),
      .r_addr(tx_rd_addr),
      .r_en(1'b1),
      .r_data(tx_rd_data)
   );

   // Transform 8 bit rx data to 32 bit data to be stored in rx_buffer
   reg [8:0] stored_rx_addr;
   reg [31:0] stored_rx_data; 
   reg stored_rx_wr;

   always @(posedge RX_CLK,posedge rst)
   if(rst) begin
     stored_rx_addr <= 0;
     stored_rx_data <= 0;
     stored_rx_wr <= 1'b0;
   end else if(rx_wr) begin
     stored_rx_addr <= rx_wr_addr[10:2];
     stored_rx_data[8 * rx_wr_addr[1:0] +: 8] <= rx_wr_data;
     stored_rx_wr <= 1'b1;
   end

   iob_ram_t2p #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_RD_ADDR_W)
                       )
   rx_buffer
   (
     // Front-End (written by core)
     .w_clk(RX_CLK),
     .w_addr(stored_rx_addr),
     .w_en(stored_rx_wr),
     .w_data(stored_rx_data),

     // Back-End (read by host)
     .r_clk(clk),
     .r_addr(ETH_DATA_RD_addr_int),
     .r_en(1'b1),
     .r_data(ETH_DATA_RD_rdata_int)
   );

   //
   // TRANSMITTER
   //

   // Transform 32 bit data from tx_buffer to 8 bit data for tx input
   reg [1:0] delayed_tx_sel;
   wire [10:0] tx_out_addr;
   
   always @(posedge TX_CLK,posedge rst_int)
     if(rst_int)
       delayed_tx_sel <= 0;
     else
       delayed_tx_sel <= tx_out_addr[1:0];

   assign tx_rd_addr = tx_out_addr[10:2];
   wire [7:0] tx_in_data = delayed_tx_sel[1] ? (delayed_tx_sel[0] ? tx_rd_data[8*3 +: 8] : tx_rd_data[8*2 +: 8]):
                                               (delayed_tx_sel[0] ? tx_rd_data[8*1 +: 8] : tx_rd_data[8*0 +: 8]);

   iob_eth_tx
     tx (
         // cpu side
         .rst     (rst_int),
         .nbytes  (ETH_TX_NBYTES),
         .ready   (tx_ready_int),

         // mii side
         .send    (send),
         .addr    (tx_out_addr),
         .data    (tx_in_data),
         .TX_CLK  (TX_CLK),
         .TX_EN   (TX_EN),
         .TX_DATA (TX_DATA)
         );


   //
   // RECEIVER
   //

   iob_eth_rx #(
                .ETH_MAC_ADDR(ETH_MAC_ADDR)
                )
   rx (
       // cpu side
       .rst       (rst_int),
       .data_rcvd (rx_data_rcvd_int),

       // mii side
       .rcv_ack   (rcv_ack),
       .wr        (rx_wr),
       .addr      (rx_wr_addr),
       .data      (rx_wr_data),
       .RX_CLK    (RX_CLK),
       .RX_DATA   (RX_DATA),
       .RX_DV     (RX_DV),
       .crc_value (crc_value)
       );


   //
   //  PHY RESET
   //
   `IOB_VAR(phy_rst_cnt, 20)
   
   always @ (posedge clk, posedge rst_int)
     if(rst_int) begin
        phy_rst_cnt <= 0;
        ETH_PHY_RESETN <= 0;
     end else 
`ifdef SIM // Faster for simulation
       if (phy_rst_cnt != 20'h000FF)
`else
       if (phy_rst_cnt != 20'hFFFFF)
`endif
         phy_rst_cnt <= phy_rst_cnt+1'b1;
       else
         ETH_PHY_RESETN <= 1;

   reg [1:0] rx_rst;
   always @ (posedge RX_CLK, negedge ETH_PHY_RESETN)
     if (!ETH_PHY_RESETN)
       rx_rst <= 2'b11;
     else
       rx_rst <= {rx_rst[0], 1'b0};
   
   always @ (posedge RX_CLK, posedge rx_rst[1])
     if (rx_rst[1]) begin
        phy_clk_detected <= 1'b0;
        phy_dv_detected <= 1'b0;
     end else begin 
        phy_clk_detected <= 1'b1;
        if(RX_DV)
          phy_dv_detected <= 1'b1;
     end

endmodule
