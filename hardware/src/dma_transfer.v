`timescale 1ns / 1ps

`include "axi.vh"

// Implements strobe and multiple transfers for when length is bigger than allowed by AXI
module dma_transfer #(
        parameter DMA_DATA_W = 32,
                 // AXI4 interface parameters
        parameter AXI_ADDR_W = `AXI_ADDR_W,
        parameter AXI_DATA_W = DMA_DATA_W
	)(
		// DMA configuration 
		input [AXI_ADDR_W-1:0] addr,
		input [31:0] length,
		input readNotWrite, // If 0 - write, 1 - read
		input start,

		// DMA status
		output reg ready,

		// Simple interface for data_in
		input [DMA_DATA_W-1:0] data_in,
		input valid_in,
		output ready_in,

		// Simple interface for data_out
		output [DMA_DATA_W-1:0] data_out,
		output wor valid_out,
		input ready_out,

		// DMA AXI connection
		`include "cpu_axi4_m_if.v"

		input clk,
		input rst
	);

	reg [31:0] stored_len,next_stored_len;

    reg [31:0] address;
    wire [31:0] wdata;
    reg [3:0] wstrb;
    wire [31:0] rdata;

    reg [7:0] dma_len;
    wire dma_ready;
    wire n_ready;
    reg output_stored;

eth_burst_align align( // Read
    .offset(address[1:0]),

    .data_in(rdata),
    .valid_in(n_ready & readNotWrite),

    .data_out(data_out),
    .valid_out(valid_out),
    .ready_out(ready_out),

	.clk(clk),
	.rst(rst)
	);

	wire [3:0] initial_strb,final_strb;
    wire split_valid;

eth_burst_split split( // Write
    .addr(address),
    .len(stored_len),

    .data_in(data_in),
    .valid_in(valid_in),
    .ready_in(ready_in),

    .data_out(wdata),
    .valid_out(split_valid),
    .ready_out(m_axi_wready & !dma_ready),

    .initial_strb(initial_strb),
    .final_strb(final_strb),

    .clk(clk),
    .rst(rst)
	);

    reg w_valid,r_valid;

	wire valid = w_valid | r_valid;

dma_axi dma(
    .valid(valid),
    .address(address),
    .wdata(wdata),
    .wstrb(wstrb),
    .rdata(rdata),
    .ready(n_ready),

    // DMA signals
    .dma_len(dma_len),
    .dma_ready(dma_ready),
    .error(),

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
    //.m_axi_bid(m_axi_bid),
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
    //.m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    .clk(clk),
    .rst(rst)
	);

wire [1:0] offset = address[1:0];

reg [31:0] axi_len;
reg [3:0] state,state_next;
reg ready_next;

always @(posedge clk,posedge rst)
begin
	if(rst) begin
		address <= 0;
		dma_len <= 0;
		stored_len <= 0;
		ready <= 0;
		state <= 0;
	end else begin
		state <= state_next;
        ready <= ready_next;

		if(start)
		begin
			address <= addr;
			stored_len <= length;

            if(length[31:2] >= 255)
                dma_len <= 8'hff;
            else
                dma_len <= length[31:2];
		end
	end
end

// Calculates auxiliary values
always @*
begin
	axi_len = 0;

	if(offset[1:0] == 2'b00 & stored_len[1:0] == 2'b00)
        axi_len = stored_len[9:2] - 8'h1;
    else if((offset[1:0] == 2'b10 && stored_len[1:0] == 2'b11) ||
            (offset[1:0] == 2'b11 && stored_len[1:0] >= 2'b10))
        axi_len = stored_len[9:2] + 8'h1;
    else
        axi_len = stored_len[9:2];
end

reg output_last;
assign valid_out = output_last;

always @*
begin
	next_stored_len = stored_len;
	state_next = state;
    r_valid = 0;
    ready_next = 1;
    output_last = 0;
    w_valid = 0;
    wstrb = 0;

	case(state)
		8'h0: begin // Wait for start
			if(start) begin
				state_next = 8'h1;
                ready_next = 0;
			end
		end
		8'h1: begin // Program DMA
			if(readNotWrite) begin
                r_valid = 1'b1;
                if(m_axi_rready & m_axi_rvalid)
                    state_next = 8'h2;
            end else begin
                wstrb = initial_strb;
                w_valid = split_valid;
                
                if(m_axi_wready & m_axi_wvalid)
                    state_next = 8'h2;
            end
		end
		8'h2: begin // Wait for end of transfer            
            if(readNotWrite) begin // Read
                r_valid = 1'b1;

                if(m_axi_rlast)
                    state_next = 8'h4;
            end else begin // Write
                w_valid = split_valid;
                wstrb = 4'hf;

                if(m_axi_wlast) begin
                    state_next = 8'h4;
                    wstrb = final_strb;
                end
            end
		end
        8'h4: begin
            if(readNotWrite) begin // Read
                output_last = 1'b1; // Output the last bytes
                if(ready_out)
                    state_next = 8'h0;
            end else begin // Write
                if(!valid_out)
                    state_next = 8'h0;
            end
        end
	endcase

    if(state_next != 8'h0)
        ready_next = 0;
end

endmodule