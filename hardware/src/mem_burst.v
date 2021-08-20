`timescale 1ns/1ps

// After asserting run, it outputs a burst of data coming from a memory block with a one cycle read latency (data <= block[addr])
module mem_burst_in #(
        parameter DATA_W = 32,
        parameter ADDR_W = 9
    )
    (
        // Burst configuration
        input [ADDR_W-1:0] start_addr,

        // After asserting start, start_addr is sampled
        input start,

        // Simple interface for data_in (ready = 1)
        input [DATA_W-1:0] data_in,
        input valid,

        // Connect to memory unit
        output reg [DATA_W-1:0] data,
        output reg [ADDR_W-1:0] addr,
        output reg write,

        // System connection
        input clk,
        input rst
    );

reg increment_addr;

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        addr <= 0;
        data <= 0;
        write <= 0;
        increment_addr <= 0;
    end else begin
        write <= 0;
        increment_addr <= 0;

        if(start)
            addr <= start_addr;

        if(increment_addr)
            addr <= addr + 1;

        if(valid) begin
            data <= data_in;
            increment_addr <= 1'b1;
            write <= 1;
        end
    end
end

endmodule

// After asserting start, it outputs a burst of data coming from a memory block with a one cycle read latency (data <= block[addr])
module mem_burst_out #(
        parameter DATA_W = 32,
        parameter ADDR_W = 8
    )
    (
        // Burst configuration
        input [ADDR_W-1:0] start_addr,

        // After asserting start, start_addr and len are sampled and the bursting begins
        input start,

        // Connect to memory unit
        output reg [ADDR_W-1:0] addr,
        input [DATA_W-1:0]      data_in,

        // Simple interface for data_out
        output wire [DATA_W-1:0] data_out,
        output reg valid,
        input      ready,

        // System connection
        input clk,
        input rst
    );

reg init;
reg stored;
reg [DATA_W-1:0] storedData;

assign data_out = (stored ? storedData : data_in);

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        valid <= 0;
        stored <= 0;
        addr <= 0;
        init <= 0;
        storedData <= 0;
    end else begin
        if(start) begin
            init <= 1'b1;
            addr <= start_addr;
            valid <= 0;
            stored <= 0;
            storedData <= 0;
        end else if(init) begin
            valid <= 1'b1;
            init <= 1'b0;
            addr <= addr + 1;
        end else if(valid) begin
            if(ready) begin
                addr <= addr + 1;

                if(stored) begin
                    stored <= 1'b0;
                    storedData <= 0;
                end
            end else if(!stored) begin
                stored <= 1'b1;
                storedData <= data_in;
            end
        end
    end
end

endmodule