
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


      cnsl2soc_fd = $fopen("cnsl2soc", "r");
      while (!cnsl2soc_fd) begin
         $display("Could not open \"cnsl2soc\"");
         cnsl2soc_fd = $fopen("cnsl2soc", "r");
      end
      $fclose(cnsl2soc_fd);
      soc2cnsl_fd = $fopen("soc2cnsl", "w");

      while (1) begin
         while (!rxread_reg && !txread_reg) begin
            iob_read(`IOB_UART_RXREADY_ADDR, rxread_reg, `IOB_UART_RXREADY_W);
            iob_read(`IOB_UART_TXREADY_ADDR, txread_reg, `IOB_UART_TXREADY_W);
         end
         if (rxread_reg) begin
            iob_read(`IOB_UART_RXDATA_ADDR, cpu_char, `IOB_UART_RXDATA_W);
            $fwriteh(soc2cnsl_fd, "%c", cpu_char);
            $fflush(soc2cnsl_fd);
            rxread_reg = 0;
         end
         if (txread_reg) begin
            cnsl2soc_fd = $fopen("cnsl2soc", "r");
            if (!cnsl2soc_fd) begin
               //wait 1 ms and try again
               #1_000_000 cnsl2soc_fd = $fopen("cnsl2soc", "r");
               if (!cnsl2soc_fd) begin
                  $fclose(soc2cnsl_fd);
                  $finish();
               end
            end
            n = $fscanf(cnsl2soc_fd, "%c", cpu_char);
            if (n > 0) begin
               iob_write(`IOB_UART_TXDATA_ADDR, cpu_char, `IOB_UART_TXDATA_W);
               $fclose(cnsl2soc_fd);
               cnsl2soc_fd = $fopen("./cnsl2soc", "w");
            end
            $fclose(cnsl2soc_fd);
            txread_reg = 0;
         end
      end
   end


   task cpu_initeth;
      begin
 	 //TODO: Update below to init ethernet
         //pulse reset uart
         iob_write(`IOB_UART_SOFTRESET_ADDR, 1, `IOB_UART_SOFTRESET_W);
         iob_write(`IOB_UART_SOFTRESET_ADDR, 0, `IOB_UART_SOFTRESET_W);
         //config uart div factor
         iob_write(`IOB_UART_DIV_ADDR, `FREQ / `BAUD, `IOB_UART_DIV_W);
         //enable uart for receiving
         iob_write(`IOB_UART_RXEN_ADDR, 1, `IOB_UART_RXEN_W);
         iob_write(`IOB_UART_TXEN_ADDR, 1, `IOB_UART_TXEN_W);
      end
   endtask

   `include "iob_tasks.vs"

endmodule
