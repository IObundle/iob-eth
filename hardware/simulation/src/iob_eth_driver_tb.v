`include "iob_eth_defines.vh"

module iob_eth_driver_tb (
    `include "iob_m_port.vs"
    input clk_i
);

  wire                             clk = clk_i;

  //IOb-SoC ethernet
  reg                              iob_valid_i;
  reg  [`IOB_ETH_SWREG_ADDR_W-1:0] iob_addr_i;
  reg  [      `IOB_SOC_DATA_W-1:0] iob_wdata_i;
  reg  [                      3:0] iob_wstrb_i;
  wire [      `IOB_SOC_DATA_W-1:0] iob_rdata_o;
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
  assign iob_rvalid_o = iob_valid_i;

  // Main program
  initial begin
    //init cpu bus signals
    iob_valid_i = 0;
    iob_wstrb_i = 0;

    // configure eth
    cpu_initeth();

    frame_word[1521:0];
    rxread_reg = 0;
    txread_reg = 0;
    // TODO: Update below to drive ethernet
    cpu_char   = 0;


    // Init simulation/real ethernet relay files
    eth2soc_fd = $fopen("eth2soc", "r");
    while (!eth2soc_fd) begin
      $display("Could not open \"eth2soc\"");
      eth2soc_fd = $fopen("eth2soc", "r");
    end
    $fclose(eth2soc_fd);
    soc2eth_fd = $fopen("soc2eth", "w");

    // Relay frames between files and ethernet core
    while (1) begin
      // Check if frames received via ethernet or files
      while (!rxread_reg && !txread_reg) begin
        eth_rx_ready(64, rxread_reg);
        eth_tx_ready(0, txread_reg);
      end
      // Relay ethernet frames from core to file
      if (rxread_reg) begin
        //iob_read(`IOB_UART_RXDATA_ADDR, cpu_char, `IOB_UART_RXDATA_W);
        //$fwriteh(soc2eth_fd, "%c", cpu_char);
        //$fflush(soc2eth_fd);
        // TODO: Use the non-DMA interface to read frame from core and
        // write to file

        rxread_reg = 0;
      end
      // Relay ethernet frames from file to core
      if (txread_reg) begin
        // Try to open file
        eth2soc_fd = $fopen("eth2soc", "r");
        if (!eth2soc_fd) begin
          //wait 1 ms and try again
          #1_000_000 eth2soc_fd = $fopen("eth2soc", "r");
          if (!eth2soc_fd) begin
            $fclose(soc2eth_fd);
            $finish();
          end
        end
        // Read file contents
        // TODO: Fix this to read whole frame
        n = $fscanf(eth2soc_fd, "%c", cpu_char);
        if (n > 0) begin
          // TODO: Use non-DMA interface to write to core
          iob_write(`IOB_UART_TXDATA_ADDR, cpu_char, `IOB_UART_TXDATA_W);
          $fclose(eth2soc_fd);
          eth2soc_fd = $fopen("./eth2soc", "w");
        end
        $fclose(eth2soc_fd);

        txread_reg = 0;
      end
    end
  end

  task relay_frame_file_2_eth();
    begin
      // TODO: Read frame size (2 bytes)
      // Read RAW frame from binary encoded file, byte by byte
    end
  endtask


  task cpu_initeth;
    begin
      /**** Configure receiver *****/
      // Mark empty; Set as last descriptor; Enable interrupt.
      eth_set_empty(64, 1);
      eth_set_wr(64, 1);
      eth_set_interrupt(64, 1);

      // Enable reception
      eth_receive(1);

      /**** Configure transmitter *****/
      // Set ready bit; Enable CRC and PAD; Set as last descriptor; Enable interrupt.
      eth_set_ready(0, 1);
      eth_set_crc(0, 1);
      eth_set_pad(0, 1);
      eth_set_wr(0, 1);
      eth_set_interrupt(0, 1);
    end
  endtask

  // Tasks based on macros from iob-eth-defines.h

  task eth_tx_ready(input [ADDR_W-1:0] idx, output ready);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      ready = !((rvalue & `TX_BD_READY) || 0);
    end
  endtask
  task eth_rx_ready(input [ADDR_W-1:0] idx, output ready);
    eth_tx_ready(idx, ready);
  endtask

  task eth_bad_crc(input [ADDR_W-1:0] idx, output bad_crc);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      bad_crc = ((rvalue & `RX_BD_CRC) || 0);
    end
  endtask

  task eth_send(input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_MODER(rvalue);
      IOB_ETH_SET_MODER(rvalue & ~`MODER_TXEN | (enable ? `MODER_TXEN : 0));
    end
  endtask

  task eth_receive(input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_MODER(rvalue);
      IOB_ETH_SET_MODER(rvalue & ~`MODER_RXEN | (enable ? `MODER_RXEN : 0));
    end
  endtask

  task eth_set_ready(input [ADDR_W-1:0] idx, input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_READY | (enable ? `TX_BD_READY : 0), idx << 1);
    end
  endtask
  task eth_set_empty(input [ADDR_W-1:0] idx, input enable);
    eth_set_ready(idx, enable);
  endtask

  task eth_set_interrupt(input [ADDR_W-1:0] idx, input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_IRQ | (enable ? `TX_BD_IRQ : 0), idx << 1);
    end
  endtask

  task eth_set_wr(input [ADDR_W-1:0] idx, input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_WRAP | (enable ? `TX_BD_WRAP : 0), idx << 1);
    end
  endtask

  task eth_set_crc(input [ADDR_W-1:0] idx, input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_CRC | (enable ? `TX_BD_CRC : 0), idx << 1);
    end
  endtask

  task eth_set_pad(input [ADDR_W-1:0] idx, input enable);
    begin
      rvalue = 0;
      IOB_ETH_GET_BD(idx << 1, rvalue);
      IOB_ETH_SET_BD(rvalue & ~`TX_BD_PAD | (enable ? `TX_BD_PAD : 0), idx << 1);
    end
  endtask

  task eth_set_ptr(input [ADDR_W-1:0] idx, input [ADDR_W-1:0] ptr);
    IOB_ETH_SET_BD(ptr, (idx << 1) + 1);
  endtask


  `include "iob_eth_swreg_emb_tb.vs"

  `include "iob_tasks.vs"

endmodule
