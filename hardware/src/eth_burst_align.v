`timescale 1ns / 1fs

`include "iob_lib.vh"

// Given the initial byte offset, this module aligns incoming data
// If aligned, after asserting transfer, data_out will be valid after one cycle (first_transfer_valid is asserted to indicate this)
// If unaligned, the first transfer will not produce valid data_out, but afterwards, after every transfer, data_out will be valid
module eth_burst_align (
        input [31:0] data,
        input transfer,  // When asserted, indicates that a transfer occured and the bytes not sent from data are stored for the next transfer
        input [1:0] offset,
        input [9:0] len,
        input remaining_data, // When asserted, it sets data with the remaining data left to store

        output reg [31:0] data_out,
        output reg [31:0] last_data_out,
        output reg [7:0] axi_len,

        output wire first_transfer_valid,

        input clk,
        input rst
    );

assign first_transfer_valid = (offset == 2'b00);

reg [23:0] stored_data;

always @*
begin
    axi_len = 8'h0;

    if(offset[1:0] == 2'b00)
    last_data_out = stored_data;

    if(offset[1:0] == 2'b00 & len[1:0] == 2'b00)
        axi_len = len[9:2] - 8'h1;
    else if((offset[1:0] == 2'b10 && len[1:0] == 2'b11) ||
            (offset[1:0] == 2'b11 && len[1:0] >= 2'b10))
        axi_len = len[9:2] + 8'h1;
    else
        axi_len = len[9:2];
end

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 0;
    end 
    else if(transfer || remaining_data) begin
        case(offset[1:0])
        2'b00:;
        2'b01: stored_data <= data[31:8];
        2'b10: stored_data[15:0] <= data[31:16];
        2'b11: stored_data[7:0] <= data[31:24];
        endcase
        case(offset[1:0])
        2'b00: data_out <= data; 
        2'b01: data_out <= {data[7:0],stored_data};
        2'b10: data_out <= {data[15:0],stored_data[15:0]};
        2'b11: data_out <= {data[23:0],stored_data[7:0]};
        endcase
    end
end

endmodule