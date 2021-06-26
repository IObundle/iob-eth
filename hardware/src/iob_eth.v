`timescale 1ns/1ps

`include "axi.vh"
`include "iob_lib.vh"
`include "iob_eth_defs.vh"

/*
 Ethernet Core
*/

module iob_eth #(
                 parameter ETH_MAC_ADDR = `ETH_MAC_ADDR,
                 parameter AXI_ADDR_W = 32, //NODOC addressable memory space (log2)
                 parameter AXI_DATA_W = 32 //NODOC Memory data width = DMA_DATA_W
                 )
   (
    // CPU side
    input                   clk,
    input                   rst,

    input                   valid,
    output reg              ready,
    input [3:0]             wstrb,
    input [`ETH_ADDR_W-1:0] addr,
    output reg [31:0]       data_out,
    input [31:0]            data_in,

    `include "cpu_axi4_m_if.v"

    output wire ila_dma_ready,
    output wire [63:0] ila_data,

    // PHY side
    output reg              ETH_PHY_RESETN,

    // PLL
    input                   PLL_LOCKED,

    // RX
    input                   RX_CLK,
    input [3:0]             RX_DATA,
    input                   RX_DV,

    // TX
    input                   TX_CLK,
    output                  TX_EN,
    output [3:0]            TX_DATA
    );

   // registers
   // dummy
   reg [31:0]               dummy_reg;
   reg                      dummy_reg_en;
   // tx_nbytes
   reg [10:0]               tx_nbytes_reg;
   reg                      tx_nbytes_reg_en;
   // rx_nbytes
   reg [10:0]               rx_nbytes_reg;
   reg                      rx_nbytes_reg_en;
   // dma address
   reg [AXI_ADDR_W-1:0]     dma_address_reg;
   reg                      dma_address_reg_en;
   reg                      dma_read_from_not_write;

   wire[3:0]                dma_in_wstrb;
   wire[8:0]                dma_rx_address;
   wire[8:0]                dma_tx_address;
   wire[31:0]               dma_tx_data;
   wire                     dma_tx_wr;

   reg [10:0]               dma_start_index;
   reg                      dma_start_index_en;

   wire                     dma_ready;
   wire                     dma_out_en;
   reg                      dma_out_run,dma_out_run_en;

   // control
   reg                      send_en;
   reg                      send;

   reg                      rcv_ack_en;
   reg                      rcv_ack;

   // tx signals
   reg                      tx_wr;
   reg [1:0]                tx_ready;
   reg [1:0]                tx_clk_pll_locked;
   wire                     tx_ready_int;

   // rx signals
   reg [1:0]                rx_data_rcvd;
   wire                     rx_data_rcvd_int;
   wire[31:0]               rx_rd_data;
   reg [10:0]               rx_wr_addr_cpu[1:0];
   reg [31:0]               crc_value_cpu[1:0];
   
   // phy reset timer
   reg [19:0]               phy_rst_cnt;
   reg                      phy_clk_detected;
   reg                      phy_dv_detected;
   reg [1:0]                phy_clk_detected_sync;
   reg [1:0]                phy_dv_detected_sync;

   reg                      rst_soft_en;
   reg                      rst_soft;
   wire                     rst_int;

   // ETH CLOCK DOMAIN
   wire [8:0]               tx_rd_addr;
   wire [31:0]              tx_rd_data;

   wire [10:0]              rx_wr_addr;
   wire [7:0]               rx_wr_data;
   wire                     rx_wr;
   wire [31:0]              crc_value;

    iob_eth_dma 
     #(
       .DMA_DATA_W(AXI_DATA_W),
       .AXI_ADDR_W(AXI_ADDR_W)
       ) eth_dma (
        // system inputs
        .clk(clk),
        .rst(rst),

        .in_data(dma_tx_data),
        .in_addr(dma_tx_address),
        .in_wr(dma_tx_wr),
        .in_end_addr(tx_nbytes_reg),
        .in_wstrb(dma_in_wstrb),

        .out_data(rx_rd_data),
        .out_addr(dma_rx_address),
        .out_end_addr(rx_nbytes_reg),

        .dma_addr(dma_address_reg),
        .dma_run(dma_out_run),
        .dma_ready(dma_ready),
        .dma_start_index(dma_start_index),
        .dma_read_from_not_write(dma_read_from_not_write),

        // AXI4 Master i/f
        // Address write
        .m_axi_awid(m_axi_awid), 
        .m_axi_awaddr(m_axi_awaddr), 
        .m_axi_awlen(m_axi_awlen), 
        .m_axi_awsize(m_axi_awsize), 
        .m_axi_awburst(m_axi_awburst), 
        .m_axi_awlock(m_axi_awlock), 
        .m_axi_awcache(m_axi_awcache), 
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos), 
        .m_axi_awvalid(m_axi_awvalid), 
        .m_axi_awready(m_axi_awready),
        //write
        .m_axi_wdata(m_axi_wdata), 
        .m_axi_wstrb(m_axi_wstrb), 
        .m_axi_wlast(m_axi_wlast), 
        .m_axi_wvalid(m_axi_wvalid), 
        .m_axi_wready(m_axi_wready), 
        //write response
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp), 
        .m_axi_bvalid(m_axi_bvalid), 
        .m_axi_bready(m_axi_bready),

        //address read
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
   
        //read
        .m_axi_rid(m_axi_rid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
        );
   
   // When dma is ready (not running) the software can still use the register interface to write and read the buffers
   wire [8:0]  rx_address = dma_ready ? addr[8:0] : dma_rx_address;
   wire [8:0]  tx_address = dma_ready ? addr[8:0] : dma_tx_address;
   wire [31:0] tx_wr_data = dma_ready ? data_in : dma_tx_data;
   wire        do_tx_wr   = dma_ready ? tx_wr : dma_tx_wr;
   wire [3:0]  tx_wstrb   = dma_ready ? wstrb : dma_in_wstrb;

   assign rst_int = rst_soft | rst;
   
   // SYNCHRONIZERS
   always @ (posedge clk, posedge rst_int)
     if (rst_int) begin
        tx_ready <= 0;
        tx_clk_pll_locked <= 0;
        rx_data_rcvd <= 0;
        rx_wr_addr_cpu[0] <= 0;
        rx_wr_addr_cpu[1] <= 0;
        crc_value_cpu[0] <= 0;
        crc_value_cpu[1] <= 0;
        phy_clk_detected_sync <= 0;
        phy_dv_detected_sync <= 0;
     end else begin
        tx_clk_pll_locked <= {tx_clk_pll_locked[0], PLL_LOCKED};
        tx_ready <= {tx_ready[0], tx_ready_int & ETH_PHY_RESETN & PLL_LOCKED};
        rx_data_rcvd <= {rx_data_rcvd[0], rx_data_rcvd_int & ETH_PHY_RESETN};
        rx_wr_addr_cpu[0] <= rx_wr_addr;
        rx_wr_addr_cpu[1] <= rx_wr_addr_cpu[0];
        crc_value_cpu[0] <= crc_value;
        crc_value_cpu[1] <= crc_value_cpu[0];
        phy_clk_detected_sync <= {phy_clk_detected_sync[0], phy_clk_detected};
        phy_dv_detected_sync <= {phy_dv_detected_sync[0], phy_dv_detected};
     end

   // cpu interface ready signal
   always @(posedge clk, posedge rst)
     if (rst)
       ready <= 1'b0;
     else
       ready <= valid;

   //
   // ADDRESS DECODER
   //

   // write
   always @* begin
      // defaults
      rst_soft_en = 0;
      send_en = 0;
      rcv_ack_en = 0;
      dummy_reg_en = 0;
      tx_nbytes_reg_en = 0;
      rx_nbytes_reg_en = 0;
      tx_wr = 1'b0;
      dma_address_reg_en = 1'b0;
      dma_out_run_en = 1'b0;
      dma_start_index_en = 1'b0;

      if(valid & (|wstrb))
        case (addr)
          `ETH_SEND: send_en = 1'b1;
          `ETH_RCVACK: rcv_ack_en = 1'b1;
          `ETH_DUMMY: dummy_reg_en = 1'b1;
          `ETH_TX_NBYTES: tx_nbytes_reg_en = 1'b1;
          `ETH_RX_NBYTES: rx_nbytes_reg_en = 1'b1;
          `ETH_SOFTRST: rst_soft_en  = 1'b1;
          `ETH_DMA_ADDRESS: dma_address_reg_en = 1'b1;
          `ETH_DMA_RUN: dma_out_run_en = 1'b1;
          `ETH_READ_ADDRESS: dma_start_index_en = 1'b1;
          default: tx_wr = addr[11] & 1'b1; // ETH_DATA
        endcase
   end


   // read
   always @* begin
      case (addr)
        `ETH_STATUS: data_out = {15'b0, dma_ready, tx_clk_pll_locked[1], rx_wr_addr_cpu[1], phy_clk_detected_sync[1], phy_dv_detected_sync[1], rx_data_rcvd[1], tx_ready[1]};
        `ETH_DUMMY: data_out = dummy_reg;
        `ETH_CRC: data_out = crc_value_cpu[1];
        `ETH_RCV_SIZE: data_out = rx_wr_addr;
        default: data_out = rx_rd_data; // ETH_DATA
      endcase
   end

   //
   // REGISTERS
   //

   // soft reset self-clearing register
   always @ (posedge clk, posedge rst)
     if (rst)
       rst_soft <= 1'b1;
     else if (rst_soft_en && !rst_soft)
       rst_soft <= 1'b1;
     else
       rst_soft <= 1'b0;

   always @ (posedge clk, posedge rst_int)
     if(rst_int)
        dma_out_run <= 0;
     else if(dma_out_run_en)
        dma_out_run <= 1;
     else
        dma_out_run <= 0;

   always @ (posedge clk, posedge rst_int)
     if (rst_int) begin
        tx_nbytes_reg <= 11'd46;
        rx_nbytes_reg <= 11'd46;
        dummy_reg <= 0;
        dma_address_reg <= 0;
        dma_start_index <= 0;
        dma_read_from_not_write <= 0;
     end else if (dummy_reg_en)
       dummy_reg <= data_in;
     else if (tx_nbytes_reg_en)
       tx_nbytes_reg <= data_in[10:0];
     else if (rx_nbytes_reg_en)
       rx_nbytes_reg <= data_in[10:0];
     else if (dma_address_reg_en)
       dma_address_reg <= data_in;
     else if (dma_out_run_en)
       dma_read_from_not_write <= data_in[0];
     else if (dma_start_index_en)
       dma_start_index <= data_in[10:0];
   
   // SYNCHRONIZERS
   
   // Clock cross send_en from clk to TX_CLK domain
   `PULSE_SYNC(send_en,clk,send,TX_CLK,rst)

   // Clock cross rcv_ack_en from clk to RX_CLK domain
   `PULSE_SYNC(rcv_ack_en,clk,rcv_ack,RX_CLK,rst)

   //
   // TX and RX BUFFERS
   //

   eth_mem tx_buffer
     (
      // Back-End (written by host)
      .clk_a(clk),
      .addr_a(tx_address),
      .data_a(tx_wr_data),
      .we_a(do_tx_wr),
      .wstrb(tx_wstrb),

      // Front-End (read by core)
      .clk_b(TX_CLK),
      .addr_b(tx_rd_addr),
      .data_b(tx_rd_data)
      );

   wire [3:0] rx_wstrb = rx_wr_addr[1] ? (rx_wr_addr[0] ? 4'b1000 : 4'b0100):
                                         (rx_wr_addr[0] ? 4'b0010 : 4'b0001);

   eth_mem rx_buffer
     (
      // Front-End (written by core)
      .clk_a(RX_CLK),
      .addr_a(rx_wr_addr[10:2]),
      .data_a({rx_wr_data,rx_wr_data,rx_wr_data,rx_wr_data}),
      .we_a(rx_wr),
      .wstrb(rx_wstrb),

      // Back-End (read by host)
      .clk_b(clk),
      .addr_b(rx_address),
      .data_b(rx_rd_data)
      );


   //
   // TRANSMITTER
   //
   
   wire [10:0] tx_out_addr;
   assign tx_rd_addr = tx_out_addr[10:2];

   reg [1:0] delayed_tx_sel;
   always @(posedge TX_CLK,posedge rst_int)
     if(rst_int)
       delayed_tx_sel <= 0;
     else
       delayed_tx_sel <= tx_out_addr[1:0];

   wire [7:0] tx_in_data = delayed_tx_sel[1] ? (delayed_tx_sel[0] ? tx_rd_data[8*3 +: 8] : tx_rd_data[8*2 +: 8]):
                                               (delayed_tx_sel[0] ? tx_rd_data[8*1 +: 8] : tx_rd_data[8*0 +: 8]);

   iob_eth_tx
     tx (
         // cpu side
         .rst     (rst_int),
         .nbytes  (tx_nbytes_reg),
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
       .nbytes    (rx_nbytes_reg),
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
   
assign ila_dma_ready = dma_ready;

wire [31:0] s0 = {15'b0, dma_ready, tx_clk_pll_locked[1], rx_wr_addr_cpu[1], phy_clk_detected_sync[1], phy_dv_detected_sync[1], rx_data_rcvd[1], tx_ready[1]};
wire [31:0] s1 = tx_wr_data;

assign ila_data = {s1,s0};

endmodule
