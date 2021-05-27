`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma #(
		    parameter DMA_DATA_W = 32,
		    // AXI4 interface parameters
		    parameter AXI_ADDR_W = 32,
		    parameter AXI_DATA_W = DMA_DATA_W
		    ) (
		       // system inputs
		       input 		       clk,
		       input 		       rst,

		       //AXI4 Master i/f
			   `include "cpu_axi4_m_if.v"

		       // DMA Configurations
		       input [AXI_ADDR_W-1:0]  dma_out_addr,
		       input [`AXI_LEN_W-1:0]  dma_out_len,
		       input 		           dma_out_run,
		       output 		           dma_ready,

		       input [DMA_DATA_W-1:0]  out_data,
		       output 		           out_en
		       );

	assign m_axi_arid = 0;
	assign m_axi_araddr = 0;  
	assign m_axi_arlen = 0;   
	assign m_axi_arsize = 0;  
	assign m_axi_arburst = 0;
	assign m_axi_arlock = 0; 
	assign m_axi_arcache = 0; 
	assign m_axi_arprot = 0;  
	assign m_axi_arqos = 0;   
	assign m_axi_arvalid = 0;
	assign m_axi_rready = 0;

   // Aux registers
   reg 					       run_state;
   reg 					       valid_int;
   reg [AXI_ADDR_W-1:0] 		       addr_int;
   reg [DMA_DATA_W/8-1:0] 		       wstrb_int;
   reg [`AXI_LEN_W-1:0] 		       dma_len_int;
   wire 				       ready;
   reg 					       out_en_int;
   
   // Len counter
   reg [`AXI_LEN_W-1:0] 		       len_cnt;
   
   // Run registers
   wire 				       out_run_int;
   reg 					       out_run0, out_run1;
   
   
   //
   // Register RUN commands for 1 cycle
   //
   always @(posedge clk, posedge rst) begin
      if(rst) begin
	 out_run0 <= 1'b0; 
	 out_run1 <= 1'b0;
      end else begin
	 out_run0 <= dma_out_run;
	 out_run1 <= out_run0; 
      end
   end

   assign out_run_int = out_run0 && ~out_run1;

   //
   // FIFO enables
   //
   
   assign out_en = (out_en_int) ? ready : 1'b0;
   
   //
   // I2S DMA RUNS
   //
   
   always @ (posedge clk, posedge rst) begin
      if (rst) begin
	 run_state <= 1'b0;
	 valid_int <= 1'b0;
	 addr_int <= 1'b0;
	 wstrb_int <= {DMA_DATA_W/8{1'b0}};
	 dma_len_int <= `AXI_LEN_W'b0;
	 len_cnt <= `AXI_LEN_W'b0;
	 out_en_int <= 1'b0;
      end else begin
	 valid_int <= valid_int;
	 addr_int <= addr_int;
	 wstrb_int <= wstrb_int;
	 dma_len_int <= dma_len_int;
	 len_cnt <= len_cnt;
	 out_en_int <= out_en_int;
	 
	 run_state <= run_state + 1'b1;

	 case(run_state)
	   1'd0: begin // wait for AUDIO_IN or AUDIO_OUT RUN
	      if(out_run_int) begin // AUDIO_OUT RUN -> Write to DDR
		 valid_int <= 1'b1;
		 addr_int <= dma_out_addr;
		 wstrb_int <= {DMA_DATA_W/8{1'b1}};
		 dma_len_int <= dma_out_len;
		 len_cnt <= dma_out_len;
		 out_en_int <= 1'b1;
	      end else begin
		 run_state <= run_state;
	      end
	   end
	   
	   1'd1: begin // decrement len_cnt
	      run_state <= run_state;
	      if(ready) begin
		 len_cnt <= len_cnt-`AXI_LEN_W'd1;
		 if(|len_cnt) begin // len_cnt != 0
		    run_state <= run_state;
		 end else begin // final transfer
		    run_state <= 1'b0;
		    valid_int <= 1'b0;
		    addr_int <= 1'b0;
		    wstrb_int <= {DMA_DATA_W/8{1'b0}};
		    dma_len_int <= `AXI_LEN_W'b0;
		    len_cnt <= `AXI_LEN_W'b0;
		    out_en_int <= 1'b0;
		 end
	      end
	   end
	 endcase
      end
   end
   
   //
   // DMA module
   //
   
   dma_axi_w 
     #(
       .DMA_DATA_W(DMA_DATA_W),
       .AXI_ADDR_W(AXI_ADDR_W)
       ) dma (
	      // system inputs
	      .clk(clk),
	      .rst(rst),

	      // Native i/f
	      .valid(valid_int),
	      .addr(addr_int), 
	      .wdata(out_data),
	      .wstrb(wstrb_int),
	      .ready(ready),

	      // DMA signals
	      .dma_len(dma_len_int),
	      .dma_ready(dma_ready),
	      .error(),
	      
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
	      .m_axi_bresp(m_axi_bresp), 
	      .m_axi_bvalid(m_axi_bvalid), 
	      .m_axi_bready(m_axi_bready)
	      );
endmodule
