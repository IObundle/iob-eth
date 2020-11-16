`timescale 1ns/1ps
`include "iob_eth_defs.vh"

module iob_eth_tb;

   parameter clk_per = 10;
   parameter pclk_per = 40;

   // CPU SIDE
   reg 			rst;
   reg 			clk;

   reg [`ETH_ADDR_W-1:0] addr;
   reg 			 valid;
   reg 			 wstrb;
   reg [31:0]            data_in;
   wire [31:0]           data_out;

   reg [31:0]            cpu_reg;


   // ETH SIDE
   wire                  ETH_RESETN;

   wire                  TX_CLK;
   wire [3:0]            TX_DATA;
   wire                  TX_EN;

   reg                   RX_CLK;
   wire [3:0]            RX_DATA;
   wire                  RX_DV;

   //iterator
   integer               i;

   // data vector
   reg [7:0] data[`ETH_SIZE+30-1:0];
   reg [8*`ETH_SIZE-1:0] data_tmp;

   // mac_addr
   reg [47:0] mac_addr = `ETH_MAC_ADDR;
   
   
   // Instantiate the Unit Under Test (UUT)

   iob_eth uut (
		.clk			(clk),
		.rst			(rst),

		// CPU side
		.valid			(valid),
		.wstrb			(wstrb),
		.addr			(addr),
		.data_in		(data_in),
		.data_out		(data_out),

                //PLL
                .PLL_LOCKED(1'b1),
                
		//PHY
		.ETH_PHY_RESETN		(ETH_RESETN),

		.TX_CLK			(TX_CLK),
		.TX_DATA		(TX_DATA),
		.TX_EN			(TX_EN),

		.RX_CLK			(RX_CLK),
		.RX_DATA		(RX_DATA),
		.RX_DV			(RX_DV)
		);


   assign RX_DV =  TX_EN;

   assign RX_DATA = TX_DATA;

   initial begin

`ifdef VCD
      $dumpfile("iob_eth.vcd");
      $dumpvars;
`endif

      //preamble
      for(i=0; i < 15; i= i+1)
         data[i] = 8'h55;

      //sfd
      data[15] = 8'hD5;
      
      //dest mac address
      mac_addr = `ETH_MAC_ADDR;
      for(i=0; i < 6; i= i+1) begin
         data[i+16] = mac_addr[47:40];
         mac_addr = mac_addr<<8;
      end
      //source mac address
      mac_addr = `ETH_MAC_ADDR;
      for(i=0; i < 6; i= i+1) begin
         data[i+22] = mac_addr[47:40];
         mac_addr = mac_addr<<8;
      end

      //eth type
      data[28] = 8'h08;
      data[29] = 8'h00;
                   
      // generate test data


      data_tmp = {8*`ETH_SIZE{1'b0}};
            
      data_tmp[8*`ETH_SIZE-1-:9*8] = "Hello PC!";
 
      $display("%x", data_tmp);
      
      $display("%x", data_tmp[8*`ETH_SIZE-1-0*8 -: 8]);
      
      
      for(i=0; i < `ETH_SIZE; i= i+1)
        data[i+30]  = data_tmp[8*`ETH_SIZE-i*8-1 -: 8];
       //data[i]  = $random;
      
      
      //print data for debug
      for(i=0; i < (`ETH_SIZE+30); i= i+1)
        $display("%x", data[i]);

      //$finish;

      
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
      cpu_write(`ETH_TX_NBYTES, `ETH_SIZE);
      cpu_write(`ETH_RX_NBYTES, `ETH_SIZE);

      // write data to send
      for(i=0; i < (`ETH_SIZE+30); i= i+1)
	cpu_write(`ETH_DATA + i, data[i]);

      // start sending
      cpu_write(`ETH_SEND, 1);

      // wait until rx ready
      cpu_read (`ETH_STATUS, cpu_reg);
      while(!cpu_reg[1])
        cpu_read (`ETH_STATUS, cpu_reg);
      $display("RX received data");

       // read and check received data
      for(i=0; i < (22+`ETH_SIZE); i= i+1) begin
	 cpu_read (`ETH_DATA + i, cpu_reg);
	 if (cpu_reg[7:0] != data[i+16]) begin
	    $display("Test failed on vector %d: %x / %x", i, cpu_reg[7:0], data[i+16]);
	    $finish;
	 end
      end

      // send receive command
      cpu_write(`ETH_RCVACK, 1);
      
      $display("Test completed.");
      $finish;

   end // initial begin

   //
   // CLOCKS
   //

   //system clock
   always #(clk_per/2) clk = ~clk;

   //rx clock
   always #(pclk_per/2) RX_CLK = ~RX_CLK;

   //tx clock
   assign TX_CLK = RX_CLK;

   //
   // TASKS
   //

   // 1-cycle write
   task cpu_write;
      input [`ETH_ADDR_W-1:0]  cpu_address;
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
      input [`ETH_ADDR_W-1:0]   cpu_address;
      output [31:0] read_reg;

      #1 addr = cpu_address;
      valid = 1;
      @ (posedge clk) #1 read_reg = data_out;
      @ (posedge clk) #1 valid = 0;
   endtask

endmodule

