`timescale 1ns / 1fs

`include "iob_lib.vh"
`include "axi.vh"

module iob_eth_dma_r #(
		    parameter DMA_DATA_W = 32,
		    // AXI4 interface parameters
		    parameter AXI_ADDR_W = 32,
		    parameter AXI_DATA_W = DMA_DATA_W
		    ) (
		       // system inputs
		       input 		       clk,
		       input 		       rst,

		       //AXI4 Master i/f
           //address read
           output [`AXI_ID_W-1:0]    m_axi_arid,
           output reg [AXI_ADDR_W-1:0] m_axi_araddr,
           output [`AXI_LEN_W-1:0]   m_axi_arlen,
           output [`AXI_SIZE_W-1:0]  m_axi_arsize,
           output [`AXI_BURST_W-1:0] m_axi_arburst,
           output [`AXI_LOCK_W-1:0]  m_axi_arlock,
           output [`AXI_CACHE_W-1:0] m_axi_arcache,
           output [`AXI_PROT_W-1:0]  m_axi_arprot,
           output [`AXI_QOS_W-1:0]   m_axi_arqos,
           output reg                m_axi_arvalid,
           input                     m_axi_arready,

           //read
           input [`AXI_ID_W-1:0] m_axi_rid,
           input [AXI_DATA_W-1:0] m_axi_rdata,
           input [`AXI_RESP_W-1:0] m_axi_rresp,
           input  m_axi_rlast,
           input  m_axi_rvalid,
           output reg m_axi_rready,

		       // DMA Configurations
		       input[AXI_ADDR_W-1:0] dma_addr,
		       input 		             dma_run,
		       output reg            dma_ready,
           input [10:0]          dma_start_index,
           input [10:0]          dma_end_index,

		       output reg [7:0]      in_data,
		       output reg[10:0]      in_addr,
           output reg            in_wr
		       );

   localparam axi_awsize = $clog2(DMA_DATA_W/8);

   assign m_axi_arid = 0;   // id is zero
   assign m_axi_arlen = 0;  // transfers per burst (0 = 1 transfer per burst)
   assign m_axi_arsize = 3'h2; // 4 bytes at a time 
   assign m_axi_arburst = 0; // no bursting, for now
   assign m_axi_arlock = 0; // do not lock
   assign m_axi_arcache = 4'h2; 
   assign m_axi_arprot = `AXI_PROT_W'b010;
   assign m_axi_arqos = `AXI_QOS_W'h0;

   reg [3:0] state,state_next;
   reg [31:0] m_axi_araddr_next;

   reg [10:0] in_addr_next;
   reg [3:0]  read_wstrb,read_wstrb_next;

   reg [10:0] end_index,end_index_next;

   reg store_data;
   reg [31:0] data_stored;

   always @(posedge clk, posedge rst)
   begin
      if(rst)
      begin
         state <= 0;
         end_index <= 0;
         in_addr <= 0;
         read_wstrb <= 4'b0001;
         m_axi_araddr <= 0;
      end else begin
         state <= state_next;
         end_index <= end_index_next;
         in_addr <= in_addr_next;
         read_wstrb <= read_wstrb_next;
         m_axi_araddr <= m_axi_araddr_next;
      
         if(store_data) 
          data_stored <= m_axi_rdata;
      end
   end

   always @*
   begin
      // Output
      dma_ready = 1'b0;
      m_axi_arvalid = 1'b0;
      m_axi_rready = 1'b0;
      in_wr = 1'b0;

      // Control state 
      store_data = 1'b0;
      state_next = state;
      end_index_next = end_index;
      in_addr_next = in_addr;
      read_wstrb_next = read_wstrb;
      m_axi_araddr_next = m_axi_araddr;

      case(1'b1) // synthesis parallel_case full_case
        read_wstrb[3]: in_data = data_stored[8*3 +: 8];
        read_wstrb[2]: in_data = data_stored[8*2 +: 8];
        read_wstrb[1]: in_data = data_stored[8*1 +: 8];
        read_wstrb[0]: in_data = data_stored[8*0 +: 8];
      endcase

      case(state)
         4'h0: begin // Wait for dma_run
            dma_ready = 1'b1;

            if(dma_run)
            begin
               state_next = 4'h1;
               in_addr_next = dma_start_index;
               end_index_next = dma_end_index;
               read_wstrb_next = {dma_addr[1] & dma_addr[0],dma_addr[1] & ~dma_addr[0],~dma_addr[1] & dma_addr[0],~dma_addr[1] & ~dma_addr[0]};
               m_axi_araddr_next = {dma_addr[AXI_ADDR_W-1:2],2'b00};
            end
         end
         4'h1: begin // Wait for arready
            m_axi_arvalid = 1'b1;

            if(m_axi_arready)
            begin
               state_next = 4'h2;
            end
         end
         4'h2: begin // Wait for rvalid
            m_axi_rready = 1'b1;

            if(m_axi_rvalid)
            begin
               state_next = 4'h4;
               store_data = 1'b1;
            end
         end
         4'h4: begin // Start dissecting the data
            in_wr = 1'b1;            
            read_wstrb_next = {read_wstrb[2:0],read_wstrb[3]};
            in_addr_next = in_addr + 32'h1;

            if(in_addr_next == end_index)
               state_next = 4'h0;
            else if(read_wstrb[3]) begin
              state_next = 4'h1;
              m_axi_araddr_next = m_axi_araddr + 4;
            end
         end
         default: state_next = 4'h0;
      endcase
   end

endmodule
