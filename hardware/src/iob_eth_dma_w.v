`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma_w #(
		    parameter DMA_DATA_W = 32,
		    // AXI4 interface parameters
		    parameter AXI_ADDR_W = 32,
		    parameter AXI_DATA_W = DMA_DATA_W
		    ) (
		       // system inputs
		       input 		       clk,
		       input 		       rst,

		       //AXI4 Master i/f
           // Master Interface Write Address
           output [`AXI_ID_W-1:0]        m_axi_awid,
           output reg [AXI_ADDR_W-1:0]  m_axi_awaddr,
           output [`AXI_LEN_W-1:0]       m_axi_awlen,
           output [`AXI_SIZE_W-1:0]      m_axi_awsize,
           output [`AXI_BURST_W-1:0]     m_axi_awburst,
           output [`AXI_LOCK_W-1:0]      m_axi_awlock,
           output [`AXI_CACHE_W-1:0]     m_axi_awcache,
           output [`AXI_PROT_W-1:0]      m_axi_awprot,
           output [`AXI_QOS_W-1:0]       m_axi_awqos,
           output reg                    m_axi_awvalid,
           input                         m_axi_awready,

           // Master Interface Write Data
           output [DMA_DATA_W-1:0]       m_axi_wdata,
           output reg [DMA_DATA_W/8-1:0] m_axi_wstrb,
           output reg                    m_axi_wlast,
           output reg                    m_axi_wvalid,
           input                         m_axi_wready,

           // Master Interface Write Response
           //input [`AXI_ID_W-1:0]         m_axi_bid,
           input [`AXI_RESP_W-1:0]       m_axi_bresp,
           input                         m_axi_bvalid,
           output reg                    m_axi_bready,

		       // DMA Configurations
		       input[AXI_ADDR_W-1:0] dma_addr,
		       input 		             dma_run,
		       output reg            dma_ready,
           input [10:0]          dma_start_index,
           input [10:0]          dma_end_index,

		       input [7:0]           out_data,
		       output reg[10:0]      out_addr
		       );

   localparam axi_awsize = $clog2(DMA_DATA_W/8);

   reg [31:0] address;

   // One byte at a time, for now
   assign m_axi_awid = `AXI_ID_W'b0;
   assign m_axi_awlen = 0; // number of trasfers per burst
   assign m_axi_awsize = 3'h2;
   assign m_axi_awburst = 2'b00;
   assign m_axi_awlock = 1'b0;
   assign m_axi_awcache = 4'h2;
   assign m_axi_awprot = `AXI_PROT_W'b010;
   assign m_axi_awqos = `AXI_QOS_W'h0;
   
   // Data write constants
   assign m_axi_wdata = {out_data,out_data,out_data,out_data}; // the strobe signal selects the correct byte

   reg [3:0] state,state_next;
   reg [31:0] buffer;
   reg [31:0] m_axi_awaddr_next;

   reg [10:0] out_addr_next;
   reg [3:0] m_axi_wstrb_next;

   reg [10:0] end_index,end_index_next;

   always @(posedge clk, posedge rst)
   begin
      if(rst)
      begin
         state <= 0;
         end_index <= 0;
         out_addr <= 0;
         m_axi_wstrb <= 4'b0001;
         m_axi_awaddr <= 0;
      end else begin
         state <= state_next;
         end_index <= end_index_next;
         out_addr <= out_addr_next;
         m_axi_wstrb <= m_axi_wstrb_next;
         m_axi_awaddr <= m_axi_awaddr_next;
      end
   end

   always @*
   begin
      // Output
      dma_ready = 1'b0;
      m_axi_wlast = 1'b0;
      m_axi_wvalid = 1'b0;
      m_axi_bready = 1'b0;
      m_axi_awvalid = 1'b0;
      // Control state 
      state_next = state;
      end_index_next = end_index;
      out_addr_next = out_addr;
      m_axi_wstrb_next = m_axi_wstrb;
      m_axi_awaddr_next = m_axi_awaddr;

      case(state)
         4'h0: begin // Wait for dma_run
            dma_ready = 1'b1;

            if(dma_run)
            begin
               state_next = 4'h1;
               out_addr_next = dma_start_index;
               end_index_next = dma_end_index;
               m_axi_wstrb_next = {dma_addr[1] & dma_addr[0],dma_addr[1] & ~dma_addr[0],~dma_addr[1] & dma_addr[0],~dma_addr[1] & ~dma_addr[0]};
               m_axi_awaddr_next = {dma_addr[AXI_ADDR_W-1:2],2'b00};
            end
         end
         4'h1: begin // Wait for awready
            m_axi_awvalid = 1'b1;

            if(m_axi_awready)
            begin
               state_next = 4'h2;
            end
         end
         4'h2: begin // Begin data reading cycle
            m_axi_wvalid = 1'b1;
            m_axi_wlast = 1'b1;

            if(m_axi_wready)
            begin
               state_next = 4'h4;
            end
         end
         4'h4: begin // Write response
            m_axi_bready = 1'b1;

            if(m_axi_bvalid)
            begin
               state_next = 4'h8;
            end
         end
         4'h8: begin // Update run variables
            m_axi_wstrb_next = {m_axi_wstrb[2:0],m_axi_wstrb[3]};
            out_addr_next = out_addr + 32'h1;

            if(m_axi_wstrb[3])
            begin
               m_axi_awaddr_next = m_axi_awaddr + 32'h4;
            end

            if(out_addr_next == end_index)
               state_next = 4'h0;
            else
               state_next = 4'h1; // Loop back
         end
         default: state_next = 4'h0;
      endcase
   end

endmodule
