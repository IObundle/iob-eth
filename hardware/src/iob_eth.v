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

    `include "iob_gen_if.vh"
    );

    //BLOCK Register File & Configuration control and status register file.
    `include "iob_eth_swreg_gen.vh"

    //
    // SWRegs
    //

    `IOB_WIRE(ETH_SEND, 1)
    iob_reg #(.DATA_W(1))
    eth_send (
        .clk        (clk),
        .arst       (rst),
        .arst_val   (1'b0),
        .rst        (rst),
        .rst_val    (1'b0),
        .en         (ETH_SEND_en),
        .data_in    (ETH_SEND_wdata[0]),
        .data_out   (ETH_SEND)
    );

    `IOB_WIRE(ETH_RCVACK, 1)
    iob_reg #(.DATA_W(1))
    eth_rcvack (
        .clk        (clk),
        .arst       (rst),
        .arst_val   (1'b0),
        .rst        (rst),
        .rst_val    (1'b0),
        .en         (ETH_RCVACK_en),
        .data_in    (ETH_RCVACK_wdata[0]),
        .data_out   (ETH_RCVACK)
    );

    `IOB_WIRE(ETH_SOFTRST, 1)
    iob_reg #(.DATA_W(1))
    eth_softrst (
        .clk        (clk),
        .arst       (rst),
        .arst_val   (1'b0),
        .rst        (rst),
        .rst_val    (1'b0),
        .en         (ETH_SOFTRST_en),
        .data_in    (ETH_SOFTRST_wdata[0]),
        .data_out   (ETH_SOFTRST)
    );

    iob_reg #(.DATA_W(32))
    eth_dummy_w (
        .clk        (clk),
        .arst       (rst),
        .arst_val   (32'b0),
        .rst        (rst),
        .rst_val    (32'b0),
        .en         (ETH_DUMMY_W_en),
        .data_in    (ETH_DUMMY_W_wdata),
        .data_out   (ETH_DUMMY_R_rdata)
    );

    `IOB_WIRE(ETH_TX_NBYTES, 11)
    iob_reg #(.DATA_W(11))
    eth_tx_nbytes (
        .clk        (clk),
        .arst       (rst),
        .arst_val   (11'd46),
        .rst        (rst),
        .rst_val    (11'b0),
        .en         (ETH_TX_NBYTES_en),
        .data_in    (ETH_TX_NBYTES_wdata[10:0]),
        .data_out   (ETH_TX_NBYTES)
    );

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

    `IOB_WIRE(tx_rd_addr, 11)
    `IOB_VAR(tx_rd_data, 8)

    `IOB_WIRE(rx_wr_addr, 11)
    `IOB_WIRE(rx_wr_data, 8)
    `IOB_WIRE(rx_wr, 1)

    // Ethernet Status
    `IOB_WIRE(pll_locked_sync, 1)
    `IOB_WIRE(phy_clk_detected_sync, 1)
    `IOB_WIRE(phy_dv_detected_sync, 1)
    `IOB_WIRE(rx_data_rcvd_sync, 1)
    `IOB_WIRE(tx_ready_sync, 1)

    assign ETH_STATUS_rdata = {16'b0, pll_locked_sync, ETH_RCV_SIZE_rdata[10:0], phy_clk_detected_sync, phy_dv_detected_sync, rx_data_rcvd_sync, tx_ready_sync};

    // Ethernet CRC

    // Ethernet RCV_SIZE
    assign ETH_RCV_SIZE_rdata[15:11] = 5'b0; // bit unused by core

    // Ethernet Send

    // Ethernet Rcv Ack

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
   `IOB_SYNC(clk, rst_int, 1'b0, 11, rx_wr_addr, rx_wr_addr_sync_reg0, rx_wr_addr_sync_reg1, ETH_RCV_SIZE_rdata[10:0])
   `IOB_SYNC(clk, rst_int, 1'b0, 1, phy_clk_detected, phy_clk_detected_sync_reg0, phy_clk_detected_sync_reg1, phy_clk_detected_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, phy_dv_detected, phy_dv_detected_sync_reg0, phy_dv_detected_sync_reg1, phy_dv_detected_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, (rx_data_rcvd_int & ETH_PHY_RESETN), rx_data_rcvd_sync_reg0, rx_data_rcvd_sync_reg1, rx_data_rcvd_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, 1, (tx_ready_int & ETH_PHY_RESETN & PLL_LOCKED), tx_ready_sync_reg0, tx_ready_sync_reg1, tx_ready_sync)
   `IOB_SYNC(clk, rst_int, 1'b0, `ETH_CRC_W, crc_value, crc_value_sync_reg0, crc_value_sync_reg1, ETH_CRC_rdata)

   // clk to RX_CLK
   `IOB_VAR(send, 1)
   `IOB_F2S_SYNC(TX_CLK, ETH_SEND, send_sync, send)
   `IOB_VAR(rcv_ack, 1)
   `IOB_F2S_SYNC(RX_CLK, ETH_RCVACK, rck_ack_sync, rcv_ack)

   //
   // TX and RX BUFFERS
   //

   `IOB_WIRE(tx_rd_data_int, 32)
   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_WR_ADDR_W-2)
                       )
   tx_buffer
   (
    // Front-End (written by host)
      .clkA(clk),
      .enA(|ETH_DATA_WR_wstrb),
      .weA(ETH_DATA_WR_wstrb),
      .addrA(ETH_DATA_WR_addr[10:2]),
      .dinA(ETH_DATA_WR_wdata),
      .doutA(),

    // Back-End (read by core)
      .clkB(TX_CLK),
      .enB(1'b1),
      .weB(4'b0),
      .addrB(tx_rd_addr[10:2]),
      .dinB(32'b0),
      .doutB(tx_rd_data_int)
   );
   `IOB_WIRE(tx_rd_addr_reg, 2)
    iob_reg #(2) tx_rd_addr_r (TX_CLK, 1'b0, 2'b0, 1'b0, 2'b0, 1'b1, tx_rd_addr[1:0], tx_rd_addr_reg);
   // choose byte from 4 bytes word
   always @* begin
       case(tx_rd_addr_reg)
           0: tx_rd_data = tx_rd_data_int[0+:8];
           1: tx_rd_data = tx_rd_data_int[8+:8];
           2: tx_rd_data = tx_rd_data_int[16+:8];
           default: tx_rd_data = tx_rd_data_int[24+:8];
       endcase
   end

   `IOB_WIRE(rx_wr_wstrb_int, 4)
   `IOB_WIRE(rx_wr_data_int, 32)
   iob_ram_tdp_be #(
                       .DATA_W(32),
                       .ADDR_W(`ETH_DATA_RD_ADDR_W-2)
                       )
   rx_buffer
   (
     // Front-End (written by core)
     .clkA(RX_CLK),
     .enA(rx_wr),
     .weA(rx_wr_wstrb_int),
     .addrA(rx_wr_addr[10:2]),
     .dinA(rx_wr_data_int),
     .doutA(),

     // Back-End (read by host)
     .clkB(clk),
     .enB(ETH_DATA_RD_ren),
     .weB(4'b0),
     .addrB(ETH_DATA_RD_addr[10:2]),
     .dinB(32'b0),
     .doutB(ETH_DATA_RD_rdata)
   );
   `IOB_WIRE2WIRE( rx_wr_data << (8*rx_wr_addr[1:0]), rx_wr_data_int)
   `IOB_WIRE2WIRE( rx_wr << rx_wr_addr[1:0], rx_wr_wstrb_int)

   //
   // TRANSMITTER
   //

   iob_eth_tx
     tx (
         // cpu side
         .rst     (rst_int),
         .nbytes  (ETH_TX_NBYTES),
         .ready   (tx_ready_int),

         // mii side
         .send    (send),
         .addr    (tx_rd_addr),
         .data    (tx_rd_data),
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
