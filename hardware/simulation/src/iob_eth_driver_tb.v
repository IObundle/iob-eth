`include "iob_eth_swreg_def.vh"

module iob_eth_driver_tb (
`include "iob_m_port.vs"
   input clk_i
);

   wire clk = clk_i;

   //IOb-SoC ethernet
   reg                               iob_valid_i;
   reg [`IOB_UART_SWREG_ADDR_W-1:0]  iob_addr_i;
   reg [       `IOB_SOC_DATA_W-1:0]  iob_wdata_i;
   reg [                       3:0]  iob_wstrb_i;
   wire [       `IOB_SOC_DATA_W-1:0] iob_rdata_o;
   wire                              iob_ready_o;
   wire                              iob_rvalid_o;

   // Assign IOs to local wires
   // CPU req
   assign iob_valid_o = iob_valid_i;
   assign iob_addr_o = iob_addr_i;
   assign iob_wdata_o = iob_wdata_i;
   assign iob_wstrb_o = iob_wstrb_i;
   // CPU resp
   assign iob_rdata_o = iob_rdata_i;
   assign iob_ready_o = iob_ready_i;
   assign iob_rvalid_o = iob_valid_i;

   // Main program
   initial begin
      //init cpu bus signals
      iob_valid_i = 0;
      iob_wstrb_i  = 0;

      // configure eth
      cpu_initeth();

      // TODO: Update below to drive ethernet
      cpu_char    = 0;
      rxread_reg  = 0;
      txread_reg  = 0;


      eth2soc_fd = $fopen("eth2soc", "r");
      while (!eth2soc_fd) begin
         $display("Could not open \"eth2soc\"");
         eth2soc_fd = $fopen("eth2soc", "r");
      end
      $fclose(eth2soc_fd);
      soc2eth_fd = $fopen("soc2eth", "w");

      while (1) begin
         while (!rxread_reg && !txread_reg) begin
            iob_read(`IOB_UART_RXREADY_ADDR, rxread_reg, `IOB_UART_RXREADY_W);
            iob_read(`IOB_UART_TXREADY_ADDR, txread_reg, `IOB_UART_TXREADY_W);
         end
         if (rxread_reg) begin
            iob_read(`IOB_UART_RXDATA_ADDR, cpu_char, `IOB_UART_RXDATA_W);
            $fwriteh(soc2eth_fd, "%c", cpu_char);
            $fflush(soc2eth_fd);
            rxread_reg = 0;
         end
         if (txread_reg) begin
            eth2soc_fd = $fopen("eth2soc", "r");
            if (!eth2soc_fd) begin
               //wait 1 ms and try again
               #1_000_000 eth2soc_fd = $fopen("eth2soc", "r");
               if (!eth2soc_fd) begin
                  $fclose(soc2eth_fd);
                  $finish();
               end
            end
            n = $fscanf(eth2soc_fd, "%c", cpu_char);
            if (n > 0) begin
               iob_write(`IOB_UART_TXDATA_ADDR, cpu_char, `IOB_UART_TXDATA_W);
               $fclose(eth2soc_fd);
               eth2soc_fd = $fopen("./eth2soc", "w");
            end
            $fclose(eth2soc_fd);
            txread_reg = 0;
         end
      end
   end


   task cpu_initeth;
      begin
         // Enable reception
      end
   endtask

   // Macros based on iob-eth-defines.h

   `define ETH_SET_PTR(idx,ptr) ({\
        IOB_ETH_SET_BD(ptr, (idx<<1)+1);\
        })

   `define ETH_SET_READY(idx, enable) ({\
           IOB_ETH_GET_BD(idx<<1, rvalue);\
           IOB_ETH_SET_BD(rvalue & ~TX_BD_READY | (enable ? TX_BD_READY : 0), idx<<1);\
           })
   `define ETH_SET_EMPTY(idx, enable) ETH_SET_READY(idx, enable)

   `define ETH_SET_WR(idx, enable) ({\
           IOB_ETH_GET_BD(idx<<1, rvalue);\
           IOB_ETH_SET_BD(rvalue & ~TX_BD_WRAP | (enable ? TX_BD_WRAP : 0), idx<<1);\
           })

   `define ETH_SET_INTERRUPT(idx, enable) ({\
           IOB_ETH_GET_BD(idx<<1, rvalue);\
           IOB_ETH_SET_BD(rvalue & ~TX_BD_IRQ | (enable ? TX_BD_IRQ : 0), idx<<1);\
           })
   `define ETH_RECEIVE(enable) ({\
           IOB_ETH_GET_MODER(rvalue);
           IOB_ETH_SET_MODER(rvalue & ~MODER_RXEN | (enable ? MODER_RXEN : 0));\
           })

   task eth_rcv_frame;
      begin
         do {
            // set frame pointer
            ETH_SET_PTR(64, frame_ptr);

            // Mark empty; Set as last descriptor; Enable interrupt.
            ETH_SET_EMPTY(64, 1);
            ETH_SET_WR(64, 1);
            ETH_SET_INTERRUPT(64, 1);

            // Enable reception
            ETH_RECEIVE(1);

            // wait until data received
            while (!eth_rx_ready(64)) {
               timeout--;
               if (!timeout) {
                 ETH_RECEIVE(0);
                (*mem_free)((char *)frame_ptr);
                 return ETH_NO_DATA;
               }
            }

            if(eth_bad_crc(64)) {
              ETH_RECEIVE(0);
              (*mem_free)((char *)frame_ptr);
              printf("Bad CRC\n");
              return ETH_INVALID_CRC;
            }
            
            
            // Disable reception
            ETH_RECEIVE(0);

            // Check destination MAC address to see if should ignore frame
            ignore = 0;
            for (i=0; i < IOB_ETH_MAC_ADDR_LEN; i++)
              if (TEMPLATE[MAC_SRC_PTR+i] != frame_ptr[MAC_DEST_PTR+i]){
                ignore = 1;
                break;  
              }

         } while(ignore);

         // Copy payload to return array
         for (i=0; i < size; i++) {
          data_rcv[i] = frame_ptr[i+TEMPLATE_LEN];
         }

         return ETH_DATA_RCV;
      end
   endtask

   `include "iob_eth_swreg_emb_tb.vs"

   `include "iob_tasks.vs"

endmodule
