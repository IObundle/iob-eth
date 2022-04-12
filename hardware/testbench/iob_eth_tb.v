`timescale 1ns/1ps

`include "iob_eth.vh"
`include "iob_eth_swreg_def.vh"

// FRAME_SIZE (bytes) = PREAMBLE + SFD + HDR + DATA + CRC -> Ethernet Frame
`define FRAME_SIZE (`PREAMBLE_LEN + 1 + `HDR_LEN + `ETH_NBYTES + 4)
`define FRAME_NIBBLE_SIZE (`FRAME_SIZE * 2)

`define PREAMBLE_PTR     0
`define SDF_PTR          (`PREAMBLE_PTR + `PREAMBLE_LEN)
`define MAC_DEST_PTR     (`SDF_PTR + 1)
`define MAC_SRC_PTR      (`MAC_DEST_PTR + `MAC_ADDR_LEN)
//`define TAG_PTR          (`MAC_SRC_PTR + `MAC_ADDR_LEN) // Optional - not supported
`define ETH_TYPE_PTR     (`MAC_SRC_PTR + `MAC_ADDR_LEN)
`define PAYLOAD_PTR      (`ETH_TYPE_PTR + 2)

`define RX_BUFFER_OFFSET 2

module iob_eth_tb;

   parameter clk_per = 10;
   parameter pclk_per = 40;

   // CPU SIDE
   reg         rst;
   reg         clk;

   reg [`iob_eth_swreg_ADDR_W-1:0] addr;
   reg          valid;
   reg [3:0]             wstrb;
   reg [31:0]            data_in;
   wire [31:0]           data_out;

   reg [31:0]            cpu_reg;


   // ETH SIDE
   wire                  ETH_RESETN;

   reg                   TX_CLK;
   wire [3:0]            TX_DATA;
   wire                  TX_EN;

   reg                   RX_CLK;
   wire [3:0]            RX_DATA;
   reg                   RX_DV;

   // iterator
   integer               i;
   integer            rx_index;
   integer            nibble_index;

   // data vector
   reg [7:0] data[`FRAME_SIZE-1:0];
   reg [3:0] dataNibbleView[`FRAME_NIBBLE_SIZE-1:0]; // View data as a array of nibbles

   assign RX_DATA = dataNibbleView[rx_index];

   // mac_addr
   reg [47:0] mac_addr = `ETH_MAC_ADDR;
   
   
   // Instantiate the Unit Under Test (UUT)

   iob_eth uut (
      .clk        (clk),
      .rst        (rst),

      // CPU side
      .valid         (valid),
      .wstrb         (wstrb),
      .addr       (addr),
      .data_in    (data_in),
      .data_out      (data_out),

        //PLL
        .PLL_LOCKED(1'b1),
                
      //PHY
      .ETH_PHY_RESETN      (ETH_RESETN),

      .TX_CLK        (TX_CLK),
      .TX_DATA    (TX_DATA),
      .TX_EN         (TX_EN),

      .RX_CLK        (RX_CLK),
      .RX_DATA    (RX_DATA),
      .RX_DV         (RX_DV)

      );

   initial begin

`ifdef VCD
      $dumpfile("iob_eth.vcd");
      $dumpvars;
`endif

     nibble_index = 0;
     rx_index = 0;
     RX_DV = 0;

      //preamble
      for(i=0; i < `PREAMBLE_LEN; i= i+1)
         data[`PREAMBLE_PTR+i] = `ETH_PREAMBLE;

      //sfd
      data[`SDF_PTR] = `ETH_SFD;
      
      //dest mac address
      mac_addr = `ETH_MAC_ADDR;
      for(i=0; i < `MAC_ADDR_LEN; i= i+1) begin
         data[`MAC_DEST_PTR+i] = mac_addr[47:40];
         mac_addr = mac_addr<<8;
      end
      //source mac address
      mac_addr = `ETH_MAC_ADDR;
      for(i=0; i < `MAC_ADDR_LEN; i= i+1) begin
         data[`MAC_SRC_PTR+i] = mac_addr[47:40];
         mac_addr = mac_addr<<8;
      end

      //eth type
      data[`ETH_TYPE_PTR] = `ETH_TYPE_H;
      data[`ETH_TYPE_PTR+1] = `ETH_TYPE_L;
                   
      // generate test data

      // Fill the rest with increasing values
      for(i = `PAYLOAD_PTR; i < `FRAME_SIZE; i = i + 1)
        data[i] = i;

      // Initialize the same data in a nibble array
     for(i = 0; i < `FRAME_NIBBLE_SIZE; i = i + 1) begin
       dataNibbleView[i] = data[i/2][(i%2)*4 +: 4];
     end

      if(0) begin
      $display("Byte to receive");
      for(i = 0; i < `FRAME_SIZE; i = i + 1)
      begin
         $write("%x ",data[i]);
         if((i+1) % 16 == 0)
            $display("");
      end
      $display("");
      end

      if(0) begin
         $display("Nibbles to receive");
         for(i = 0; i < `FRAME_NIBBLE_SIZE; i = i + 1)
         begin
            $write("%x ",dataNibbleView[i]);
            if((i+1) % 16 == 0)
               $display("");
         end
         $display("");
      end

      rst = 1;
      clk = 1;
      RX_CLK = 1;
      wstrb = 0;
      valid = 0;

      // deassert reset
      #100 @(posedge clk) rst = 0;

      // wait until tx ready
      cpu_read(`ETH_STATUS, cpu_reg);
      while(!cpu_reg[0])
        cpu_read(`ETH_STATUS, cpu_reg);
      $display("TX is ready");
      
      //setup number of bytes of transaction
      cpu_write(`ETH_TX_NBYTES, `ETH_NBYTES);
      cpu_write(`ETH_RX_NBYTES, `ETH_NBYTES);

      // wait until rx ready

      RX_DV = 1;

      #(pclk_per * `FRAME_NIBBLE_SIZE);

      RX_DV = 0;

      cpu_read (`ETH_STATUS, cpu_reg);
      while(!cpu_reg[1])
        cpu_read (`ETH_STATUS, cpu_reg);
      $display("RX received data");

       // read and check received data
      for(i=0; i < `FRAME_SIZE; i= i+1) begin
         get_rx_byte(i,cpu_reg[7:0]);

         if (cpu_reg[7:0] != data[i+`MAC_DEST_PTR]) begin
            $display("Test failed on vector %d: %x / %x", i, cpu_reg[7:0], data[i + `MAC_DEST_PTR]);
            $finish;
         end
      end

      // send receive command
      cpu_write(`ETH_RCVACK, 1);
      
      #400;

      $display("Test successfully completed.");
      $finish;

   end // initial begin

   //
   // CLOCKS
   //

   //system clock
   always #(clk_per/2) clk = ~clk;

   //rx clock
   always #(pclk_per/2)
   begin 
         RX_CLK = ~RX_CLK;
         if(RX_DV & !RX_CLK) // Transition on the neg edge of the clk
         begin
            rx_index = rx_index + 1;
            if(rx_index == `FRAME_NIBBLE_SIZE)
               RX_DV = 0;
         end
      end

   //tx clock
   always @* begin
      TX_CLK = #1 RX_CLK;
   end

   //
   // TASKS
   //

   // 1-cycle write
   task cpu_write;
      input [`iob_eth_swreg_ADDR_W-1:0]  cpu_address;
      input [31:0]  cpu_data;

      #1 addr = cpu_address;
      valid = 1;
      wstrb = 1;
      data_in = cpu_data;
      @ (posedge clk) #1 wstrb = 0;
      valid = 0;
   endtask

   // 2-cycle read
   task cpu_read;
      input [`iob_eth_swreg_ADDR_W-1:0]   cpu_address;
      output [31:0] read_reg;

      #1 addr = cpu_address;
      valid = 1;
      @ (posedge clk) #1 read_reg = data_out;
      @ (posedge clk) #1 valid = 0;
   endtask

   // get individual byte
   task get_rx_byte;
      input [10:0] addr;
      output [7:0] val;
      reg [31:0] temp;

      addr = addr + `RX_BUFFER_OFFSET;

      cpu_read(`ETH_DATA + (addr / 4),temp); 
   
      case(addr % 4)
         2'b00: val = temp[7:0];
         2'b01: val = temp[15:8];
         2'b10: val = temp[23:16];
         2'b11: val = temp[31:24];
      endcase
   endtask

endmodule

