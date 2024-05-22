`timescale 1ns / 1ps

`include "iob_utils.vh"
`include "iob_eth_defines.vh"

module iob_eth_driver_tb #(
    `include "iob_eth_params.vs"
) (
    `include "iob_m_port.vs"
    input clk_i
);

  wire                             clk = clk_i;

  //IOb-SoC ethernet
  reg                              iob_valid_i;
  reg  [`IOB_ETH_SWREG_ADDR_W-1:0] iob_addr_i;
  reg  [               DATA_W-1:0] iob_wdata_i;
  reg  [                      3:0] iob_wstrb_i;
  wire [               DATA_W-1:0] iob_rdata_o;
  wire                             iob_ready_o;
  wire                             iob_rvalid_o;

  // Assign IOs to local wires
  // CPU req
  assign iob_valid_o  = iob_valid_i;
  assign iob_addr_o   = iob_addr_i;
  assign iob_wdata_o  = iob_wdata_i;
  assign iob_wstrb_o  = iob_wstrb_i;
  // CPU resp
  assign iob_rdata_o  = iob_rdata_i;
  assign iob_ready_o  = iob_ready_i;
  assign iob_rvalid_o = iob_rvalid_i;

  reg [10:0] rx_nbytes_reg;
  reg txread_reg;
  reg [7:0] cpu_char;
  integer eth2soc_fd;
  integer soc2eth_fd;


  // Main program
  initial begin
    //init cpu bus signals
    iob_valid_i = 0;
    iob_wstrb_i = 0;

    // configure eth
    cpu_initeth();

    rx_nbytes_reg = 0;
    txread_reg = 0;
    cpu_char = 0;


    // Init simulation/real ethernet relay files
    eth2soc_fd = $fopen("eth2soc", "rb");
    while (!eth2soc_fd) begin
      $display("Could not open \"eth2soc\"");
      eth2soc_fd = $fopen("eth2soc", "rb");
    end
    $fclose(eth2soc_fd);
    soc2eth_fd = $fopen("soc2eth", "wb");
    $display("Opened eth2soc and soc2eth");  // DEBUG

    // Relay frames between files and ethernet core
    while (1) begin
      // Check if frames received via ethernet or files
      while (!(|rx_nbytes_reg) && !txread_reg) begin
        IOB_ETH_GET_RX_NBYTES(rx_nbytes_reg);
        eth_tx_ready(0, txread_reg);
      end
      // Relay ethernet frames from core to file
      if (|rx_nbytes_reg) begin
        //iob_read(`IOB_UART_RXDATA_ADDR, cpu_char, `IOB_UART_RXDATA_W);
        //$fwriteh(soc2eth_fd, "%c", cpu_char);
        //$fflush(soc2eth_fd);
        // TODO: Use the non-DMA interface to read frame from core and
        // write to file

        relay_frame_eth_2_file(soc2eth_fd, rx_nbytes_reg);
        rx_nbytes_reg = 0;
      end
      // Relay ethernet frames from file to core
      if (txread_reg) begin
        // Try to open file
        eth2soc_fd = $fopen("eth2soc", "rb");
        if (!eth2soc_fd) begin
          //wait 1 ms and try again
          #1_000_000 eth2soc_fd = $fopen("eth2soc", "rb");
          if (!eth2soc_fd) begin
            $fclose(soc2eth_fd);
            $finish();
          end
        end
        // Read file contents
        // // TODO: Fix this to read whole frame
        // n = $fscanf(eth2soc_fd, "%c", cpu_char);
        // if (n > 0) begin
        //   // TODO: Use non-DMA interface to write to core
        //   iob_write(`IOB_UART_TXDATA_ADDR, cpu_char, `IOB_UART_TXDATA_W);
        //   $fclose(eth2soc_fd);
        //   eth2soc_fd = $fopen("./eth2soc", "w");
        // end
        // $fclose(eth2soc_fd);

        relay_frame_file_2_eth(eth2soc_fd);
        txread_reg = 0;
      end
    end
  end

  task static relay_frame_file_2_eth(input integer eth2soc_fd);
    begin
      reg [7:0] size_l, size_h, frame_byte;
      reg [15:0] frame_size;
      integer i, n;
      reg tx_ready_reg;
      tx_ready_reg = 0;

      // Read frame size (2 bytes)
      n = $fscanf(eth2soc_fd, "%c%c", size_l, size_h);
      // Continue if size read successfully
      if (n == 2) begin
        frame_size = (size_h << 8) | size_l;
        $display("Received %d bytes from file", frame_size);  // DEBUG
        // wait for ready
        while (!tx_ready_reg) eth_tx_ready(0, tx_ready_reg);
        // set frame size
        eth_set_payload_size(0, frame_size);
        // Set ready bit
        eth_set_ready(0, 1);

        // Read RAW frame from binary encoded file, byte by byte
        for (i = 0; i < frame_size; i = i) begin
          n = $fscanf(eth2soc_fd, "%c", frame_byte);
          if (n > 0) begin
            IOB_ETH_SET_FRAME_WORD(frame_byte);
            i = i + 1;
          end
        end
        $fclose(eth2soc_fd);
        // Delete frame from file
        eth2soc_fd = $fopen("./eth2soc", "wb");
      end  // n != 0
      $fclose(eth2soc_fd);
    end
  endtask

  task static relay_frame_eth_2_file(input integer soc2eth_fd, input reg [10:0] frame_size);
    begin
      reg [7:0] frame_byte;
      integer i;
      reg bad_crc;
      bad_crc = 0;

      // Exit if bad CRC
      eth_bad_crc(64, bad_crc);
      if (!bad_crc) begin
        // Write two bytes with frame size
        $fwrite(soc2eth_fd, "%c%c", frame_size[7:0], frame_size[10:8]);

        // Read frame bytes from core and write to file
        for (i = 0; i < frame_size; i = i + 1) begin
          IOB_ETH_GET_FRAME_WORD(frame_byte);
          $fwrite(soc2eth_fd, "%c", frame_byte);
        end
        $fflush(soc2eth_fd);
      end  // !eth_bad_crc
    end
  endtask


  task static cpu_initeth;
    begin
      eth_reset_bd_memory();

      /**** Configure receiver *****/
      // Mark empty; Set as last descriptor; Enable interrupt.
      eth_set_empty(64, 1);
      eth_set_wr(64, 1);
      eth_set_interrupt(64, 1);

      // Enable reception
      eth_receive(1);

      /**** Configure transmitter *****/
      // Enable CRC and PAD; Set as last descriptor; Enable interrupt.
      eth_set_crc(0, 1);
      eth_set_pad(0, 1);
      eth_set_wr(0, 1);
      eth_set_interrupt(0, 1);

      // enable transmission
      eth_send(1);
    end
  endtask

  // Tasks based on macros from iob-eth-defines.h

  task static eth_tx_ready(input reg [ADDR_W-1:0] idx, output reg ready);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      ready = !((rvalue & `TX_BD_READY) || 0);
    end
  endtask
  task static eth_rx_ready(input reg [ADDR_W-1:0] idx, output reg ready);
    eth_tx_ready(idx, ready);
  endtask

  task static eth_bad_crc(input reg [ADDR_W-1:0] idx, output reg bad_crc);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      bad_crc = ((rvalue & `RX_BD_CRC) || 0);
    end
  endtask

  task static eth_send(input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_MODER(rvalue);
      IOB_ETH_SET_MODER(rvalue & ~`MODER_TXEN | (enable ? `MODER_TXEN : 0));
    end
  endtask

  task static eth_receive(input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_MODER(rvalue);
      IOB_ETH_SET_MODER(rvalue & ~`MODER_RXEN | (enable ? `MODER_RXEN : 0));
    end
  endtask

  task static eth_set_ready(input reg [ADDR_W-1:0] idx, input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_READY | (enable ? `TX_BD_READY : 0), idx << 1);
    end
  endtask
  task static eth_set_empty(input reg [ADDR_W-1:0] idx, input reg enable);
    eth_set_ready(idx, enable);
  endtask

  task static eth_set_interrupt(input reg [ADDR_W-1:0] idx, input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_IRQ | (enable ? `TX_BD_IRQ : 0), idx << 1);
    end
  endtask

  task static eth_set_wr(input reg [ADDR_W-1:0] idx, input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_WRAP | (enable ? `TX_BD_WRAP : 0), idx << 1);
    end
  endtask

  task static eth_set_crc(input reg [ADDR_W-1:0] idx, input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_CRC | (enable ? `TX_BD_CRC : 0), idx << 1);
    end
  endtask

  task static eth_set_pad(input reg [ADDR_W-1:0] idx, input reg enable);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_PAD | (enable ? `TX_BD_PAD : 0), idx << 1);
    end
  endtask

  task static eth_set_ptr(input reg [ADDR_W-1:0] idx, input reg [ADDR_W-1:0] ptr);
    IOB_ETH_SET_BD(ptr, (idx << 1) + 1);
  endtask

  task static eth_reset_bd_memory;
    begin
      integer i;
      for (i = 0; i < 256; i = i + 1) begin
        IOB_ETH_SET_BD(32'h00000000, i);
      end
    end
  endtask

  task static eth_set_payload_size(input reg [ADDR_W-1:0] idx, input reg [ADDR_W-1:0] size);
    begin
      reg [DATA_W-1:0] rvalue;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD((rvalue & 32'h0000ffff) | size << 16, idx << 1);
    end
  endtask


  `include "iob_eth_swreg_emb_tb.vs"

  `include "iob_tasks.vs"

endmodule
