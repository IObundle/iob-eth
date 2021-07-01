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
           output reg [AXI_ADDR_W-1:0]   m_axi_awaddr,
           output reg [`AXI_LEN_W-1:0]   m_axi_awlen,
           output [`AXI_SIZE_W-1:0]      m_axi_awsize,
           output [`AXI_BURST_W-1:0]     m_axi_awburst,
           output [`AXI_LOCK_W-1:0]      m_axi_awlock,
           output [`AXI_CACHE_W-1:0]     m_axi_awcache,
           output [`AXI_PROT_W-1:0]      m_axi_awprot,
           output [`AXI_QOS_W-1:0]       m_axi_awqos,
           output reg                    m_axi_awvalid,
           input                         m_axi_awready,

           // Master Interface Write Data
           output reg [DMA_DATA_W-1:0]   m_axi_wdata,
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
		     input 		            dma_run,
		     output reg            dma_ready,
           input [9:0]           dma_len,

		     input [31:0]          out_data,
		     output reg[8:0]       out_addr
		     );

   // One byte at a time, for now
   assign m_axi_awid = `AXI_ID_W'b0;
   assign m_axi_awsize = 3'h2;
   assign m_axi_awburst = 2'b01;
   assign m_axi_awlock = 1'b0;
   assign m_axi_awcache = 4'h2;
   assign m_axi_awprot = `AXI_PROT_W'b010;
   assign m_axi_awqos = `AXI_QOS_W'h0;
   
   wire axi_transfer = (m_axi_wvalid & m_axi_wready);

   reg [7:0] transfers;
   reg bootstrap;

   wire [31:0] axi_data;
   wire [3:0] initial_strb,final_strb;
   wire [7:0] axi_len;

   reg [31:0] storedData;
   reg hasStoredData;

   // Misalign data to write to RAM
   eth_burst_split burst_split(
        .data((hasStoredData ? storedData : out_data)),
        .transfer(axi_transfer | bootstrap),
        .offset(dma_addr[1:0]),
        .len(dma_len),

        .data_out(axi_data),

        .initial_strb(initial_strb),
        .final_strb(final_strb),
        .axi_len(axi_len),

        .clk(clk),
        .rst(rst)
    );

   reg [7:0] state;

   always @(posedge clk, posedge rst)
   begin
      if(rst)
      begin
         m_axi_awaddr <= 0;
         m_axi_awlen <= 0;
         m_axi_awvalid <= 0;
         m_axi_wvalid <= 0;
         m_axi_wlast <= 0;
         m_axi_wstrb <= 0;
         m_axi_bready <= 0;
         m_axi_wdata <= 0;
         state <= 0;
         transfers <= 0;
         out_addr <= 0;
         hasStoredData <= 0;
         storedData <= 0;
         bootstrap <= 0;
         dma_ready <= 1'b1;
      end else begin

      case(state)
         8'h0: begin
            out_addr <= 4;
            transfers <= 0;
            m_axi_awaddr <= {dma_addr[AXI_ADDR_W-1:2],2'b00};
            m_axi_awlen <= axi_len;

            if(dma_run)
            begin
               state <= 8'h1;
               dma_ready <= 1'b0;
            end
         end
        8'h1: begin // Need to wait one cycle with dma_ready deasserted to start reading valid data from the buffer
           state <= 8'h2;
           m_axi_awvalid <= 1'b1;
        end
        8'h2: begin // Wait for first valid data
            m_axi_wstrb <= initial_strb;
            m_axi_wdata <= axi_data;
            
            if(m_axi_awready) begin
               state <= 8'h4;
               m_axi_awvalid <= 1'b0;
               bootstrap <= 1'b1;
               out_addr <= out_addr + 1;
            end
        end
        8'h4: begin
            state <= 8'h8;
            m_axi_wvalid <= 1'b1;
            bootstrap <= 1'b0;
            out_addr <= out_addr + 1;
        end
        8'h8: begin // Perform burst transfer
           if(axi_transfer) begin
               transfers <= transfers + 1;
               out_addr <= out_addr + 1;
               m_axi_wdata <= axi_data;
               m_axi_wstrb <= 4'b1111;

               if(hasStoredData) begin
                  hasStoredData <= 1'b0;
                  storedData <= 0;
               end

               if(transfers + 1 >= axi_len) begin
                  m_axi_wlast <= 1'b1;
                  m_axi_wstrb <= final_strb;
                  state <= 8'h10;
               end
           end else if(!hasStoredData) begin
              hasStoredData <= 1'b1;
              storedData <= out_data;
           end
        end
        8'h10: begin
         if(axi_transfer) begin
            state <= 8'h20;
            m_axi_wlast <= 1'b0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b1;
         end
        end
        8'h20: begin
           if(m_axi_bvalid) begin
              state <= 8'h0;
              m_axi_bready <= 1'b0;
              dma_ready <= 1'b1;
           end
        end
        default:;
      endcase
      end
   end

endmodule
