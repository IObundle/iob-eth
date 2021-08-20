`timescale 1ns/1ps

`define AXI_DATA_W 32

module dma_tb;

  wire [10:0] rx_addr_b;
  wire [31:0] rx_data_b,tx_data_b;
  wire tx_write;
  wire [10:0] tx_addr_a;
  wire [31:0] tx_data_a;
  
  wire dma_ready;

  wire [10:0] burst_addr;
  wire [31:0] rd_data_out;
  wire rd_data_valid,rd_data_ready;

  wire [31:0] tx_data;
  wire tx_data_valid;

  // System
  reg clk;
  reg rst;

  // Buffers
  reg [10:0] rx_addr_a,tx_addr_b;
  reg [31:0] rx_data_a;
  reg rx_write;

  // DMA
  reg dma_read_from_not_write,dma_out_run;
  reg [31:0] dma_address_reg,dma_len;

  // AXI Input 
  reg m_axi_awready;
  reg m_axi_wready;
  reg [`AXI_ID_W-1:0] m_axi_bid;
  reg [`AXI_RESP_W-1:0] m_axi_bresp;
  reg m_axi_bvalid;
  reg m_axi_arready;
  reg [`AXI_ID_W-1:0] m_axi_rid;
  reg [`AXI_RESP_W-1:0] m_axi_rresp;
  reg m_axi_rvalid;

  wire [`AXI_DATA_W-1:0] m_axi_rdata;
  wire m_axi_rlast;

  wire [`AXI_ID_W-1:0] m_axi_awid;
  wire [`AXI_ADDR_W-1:0] m_axi_awaddr;
  wire [`AXI_LEN_W-1:0] m_axi_awlen;
  wire [`AXI_SIZE_W-1:0] m_axi_awsize;
  wire [`AXI_BURST_W-1:0] m_axi_awburst;
  wire [`AXI_LOCK_W-1:0] m_axi_awlock;
  wire [`AXI_CACHE_W-1:0] m_axi_awcache;
  wire [`AXI_PROT_W-1:0] m_axi_awprot;
  wire [`AXI_QOS_W-1:0] m_axi_awqos;
  wire m_axi_awvalid;
  wire [`AXI_DATA_W-1:0] m_axi_wdata;
  wire [(`AXI_DATA_W/8)-1:0] m_axi_wstrb;
  wire m_axi_wlast;
  wire m_axi_wvalid;
  wire m_axi_bready;
  wire [`AXI_ID_W-1:0] m_axi_arid;
  wire [`AXI_ADDR_W-1:0] m_axi_araddr;
  wire [`AXI_LEN_W-1:0] m_axi_arlen;
  wire [`AXI_SIZE_W-1:0] m_axi_arsize;
  wire [`AXI_BURST_W-1:0] m_axi_arburst;
  wire [`AXI_LOCK_W-1:0] m_axi_arlock;
  wire [`AXI_CACHE_W-1:0] m_axi_arcache;
  wire [`AXI_PROT_W-1:0] m_axi_arprot;
  wire [`AXI_QOS_W-1:0] m_axi_arqos;
  wire m_axi_arvalid;
  wire m_axi_rready;

   dma_transfer dma(
    // DMA configuration 
    .addr(dma_address_reg),
    .length(dma_len),
    .readNotWrite(dma_read_from_not_write),
    .start(dma_out_run),

    // DMA status
    .ready(dma_ready),

    // Simple interface for data_in
    .data_in(rd_data_out),
    .valid_in(rd_data_valid),
    .ready_in(rd_data_ready),

    // Simple interface for data_out
    .data_out(tx_data),
    .valid_out(tx_data_valid),
    .ready_out(1'b1),

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
    .m_axi_rready(m_axi_rready),

    .clk(clk),
    .rst(rst)
  );

  iob_eth_alt_s2p_mem #(
               .DATA_W(32),
               .ADDR_W(11)
               )
  rx_buffer
  (
    // Front-End (written by core)
    .clk_a(clk),
    .addr_a(rx_addr_a),
    .data_a(rx_data_a),
    .we_a(rx_write),

    // Back-End (read by host)
    .clk_b(clk),
    .addr_b(rx_addr_b),
    .data_b(rx_data_b)
  );

  mem_burst_out #(.ADDR_W(11)) burst_out
  (
    .start_addr(11'h0),

    .start(dma_out_run & !dma_read_from_not_write),

    .addr(rx_addr_b),
    .data_in(rx_data_b),

    .data_out(rd_data_out),
    .valid(rd_data_valid),
    .ready(rd_data_ready),

    .clk(clk),
    .rst(rst)
  );

  iob_eth_alt_s2p_mem #(
               .DATA_W(32),
               .ADDR_W(11)
               )
  tx_buffer
  (
    // Front-End (written by host)
    .clk_a(clk),
    .addr_a(tx_addr_a),
    .data_a(tx_data_a),
    .we_a(tx_write),

    // Back-End (read by core)
    .clk_b(clk),
    .addr_b(tx_addr_b),
    .data_b(tx_data_b)
  );

  mem_burst_in #(.ADDR_W(11)) burst_in(
    .start_addr(11'h0),

    .start(dma_out_run & dma_read_from_not_write),

    // Simple interface for data_in (ready = 1)
    .data_in(tx_data),
    .valid(tx_data_valid),
    // Connect to memory unit
    .addr(tx_addr_a),
    .data(tx_data_a),
    .write(tx_write),

    // System connection
    .clk(clk),
    .rst(rst)
  );

  //system clock
  always #(5) clk = ~clk;

  integer i;

  reg [31:0] memory[2047:0];
  reg [10:0] address;
  reg [31:0] counter;

  assign m_axi_rdata = m_axi_rvalid ? memory[address] : 32'hDEADBEEF;

  // Counts number of transfers
  always @(posedge clk,posedge rst)
  begin
    if(rst) begin
      address <= 0;
      counter <= 0;
    end 

    if(m_axi_rready & m_axi_rvalid) begin
      address <= address + 1;
      counter <= counter + 1;
    end
    
    if(m_axi_rlast) begin
      counter <= 0;
    end 
  end

  assign m_axi_rlast = (counter == m_axi_arlen);

  // Check if tx_data_a is correct when tx_write is asserted
  always @(posedge clk)
  begin
    if(tx_write) begin
      if(tx_addr_a != tx_data_a)
        ;//$display("%t Error on tx_data, addr: %x current value: %x",$time,tx_addr_a,tx_data_a);
    end
  end

`define ADDRESS   2
`define LENGTH 1000

  initial
    begin

    clk = 0;
    rst = 0;
    rx_addr_a = 0;
    rx_data_a = 0;
    rx_write = 0;
    tx_addr_b = 0;
    dma_read_from_not_write = 0;
    dma_out_run = 0;
    dma_address_reg = 0;
    dma_len = 0;
    m_axi_awready = 0;
    m_axi_wready = 0;
    m_axi_bid = 0;
    m_axi_bresp = 0;
    m_axi_bvalid = 0;
    m_axi_arready = 0;
    m_axi_rid = 0;
    m_axi_rresp = 0;
    m_axi_rvalid = 0;

    #5;

    clk = 0;

    // Init buffer
    memory[0] = 32'hFFFEFDFC;
    memory[1] = 32'h030201AA;
    for(i = 2; i < 2048; i = i + 1) begin
      memory[i] = i;
    end

    for(i = 0; i < 2048; i = i + 1) begin
      tx_buffer.ram[i] = 0;
      rx_buffer.ram[i] = {i[7:0],i[7:0],i[7:0],i[7:0]};
    end

    `ifdef VCD
    $dumpfile("iob_eth.vcd");
    $dumpvars;
    `endif

    rst = 1;

    #10;

    rst = 0;

    #10;

    dma_address_reg = `ADDRESS;
    dma_len = `LENGTH;
    dma_read_from_not_write = 1'b1; // Initially read
    
    dma_out_run = 1;#10; 
    dma_out_run = 0;#10;
    while(!m_axi_arvalid)
      #10;
    m_axi_arready = 1'b1;#10;
    m_axi_arready = 1'b0;#10;
    while(!m_axi_rready)
      #10;
    #10;  m_axi_rvalid = 1'b1;
    #10;  m_axi_rvalid = 1'b0;
    #10;  m_axi_rvalid = 1'b1;
    #(10*5);  m_axi_rvalid = 1'b0;
    #(10*3);  m_axi_rvalid = 1'b1;
    #10;  m_axi_rvalid = 1'b0;
    #10;  m_axi_rvalid = 1'b1;
    #10;  m_axi_rvalid = 1'b0;
    #10;  m_axi_rvalid = 1'b1;
    #10;  m_axi_rvalid = 1'b0;
    #20;  m_axi_rvalid = 1'b1;
    #10;  m_axi_rvalid = 1'b0;
    #10;  m_axi_rvalid = 1'b1;  #10;
    while(!m_axi_rlast)
      #10;
    m_axi_rvalid = 1'b1;#10;
    m_axi_rvalid = 1'b0;#(10*50);

    dma_address_reg = `ADDRESS;
    dma_len = `LENGTH;
    dma_read_from_not_write = 1'b0; // Write
    dma_out_run = 1;
    m_axi_awready = 1;
    m_axi_wready = 1;
    m_axi_bvalid = 1;
    #10;
    dma_out_run = 0;
    while(!m_axi_wvalid)
      #10;
    #10;m_axi_wready = 1'b0;
    #10;m_axi_wready = 1'b1;
    #10;m_axi_wready = 1'b0;
    #50;m_axi_wready = 1'b1;
    #10;m_axi_wready = 1'b0;
    #10;m_axi_wready = 1'b1;

    #(10*600);

    $finish;
  end

endmodule