`timescale 1ns / 1fs

`include "iob_lib.vh"

// Given the initial byte offset, this module aligns incoming data
// If aligned, after asserting transfer, data_out will be valid after one cycle (first_transfer_valid is asserted to indicate this)
// If unaligned, the first transfer will not produce valid data_out, but afterwards, after every transfer, data_out will be valid
module eth_burst_align #(
        parameter ADDR_W = `AXI_ADDR_W,
        parameter DATA_W = 32,
        parameter LEN_W = 16
        )(
        input [1:0] offset,

        // Simple interface for data_in (ready = 1)
        input [31:0] data_in,
        input valid_in,

        // Simple interface for data_out
        output reg [31:0] data_out,
        output reg valid_out,
        input ready_out,

        input clk,
        input rst
    );

reg [LEN_W-1:0] stored_len;

reg [31:0] stored_data;

always @*
begin
    data_out = 0;

    case(offset[1:0])
    2'b00: data_out = stored_data; 
    2'b01: data_out = {data_in[7:0],stored_data[23:0]};
    2'b10: data_out = {data_in[15:0],stored_data[15:0]};
    2'b11: data_out = {data_in[23:0],stored_data[7:0]};
    endcase
end

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 0;
        valid_out <= 0;
    end else begin
        if(!valid_in & valid_out & ready_out) // A transfer occured
            valid_out <= 1'b0;

        if(valid_in & !valid_out)
            valid_out <= 1'b1;

        if(valid_in & (ready_out | !valid_out)) begin
            case(offset[1:0])
            2'b00: stored_data <= data_in;
            2'b01: stored_data[23:0] <= data_in[31:8];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data[7:0] <= data_in[31:24];
            endcase
        end
    end
end

endmodule