`timescale 1ns / 1fs

`include "axi.vh"
`include "iob_lib.vh"

module eth_burst_split #(
        parameter ADDR_W = `AXI_ADDR_W,
        parameter DATA_W = 32,
        parameter LEN_W = 16
    ) 
    (
        input [ADDR_W-1:0] addr,
        input [LEN_W-1:0] len, // Transfer length, in bytes. 

        // Simple interface for data_in
        input [DATA_W-1:0] data_in,
        input valid_in,
        output ready_in,

        // Simple interface for data_out
        output reg [DATA_W-1:0] data_out,
        output reg valid_out,
        input ready_out,

        output reg [3:0] initial_strb,
        output reg [3:0] final_strb,

        input clk,
        input rst
    );

wire [1:0] offset = addr[1:0];

assign ready_in = ready_out;

reg [23:0] stored_data;

wire [9:0] len_minus_1 = (len - 10'h1);
wire [9:0] len_plus_1 = (len + 10'h1);
wire [9:0] len_plus_2 = (len + 10'h2);

reg [7:0] axi_len;

always @*
begin
    initial_strb = 4'h0;
    final_strb = 4'h0;
    axi_len = 8'h0;

    case(offset[1:0])
    2'b00: begin
        axi_len = len_minus_1[9:2];

        case(len[1:0])
        2'b00: final_strb = 4'b1111;
        2'b01: final_strb = 4'b0001;
        2'b10: final_strb = 4'b0011;
        2'b11: final_strb = 4'b0111;
        endcase

        if(len >= 4)
            initial_strb = 4'b1111;
        else begin
            case(len[1:0])
            2'b00: initial_strb = 4'b0000;
            2'b01: initial_strb = 4'b0001;
            2'b10: initial_strb = 4'b0011;
            2'b11: initial_strb = 4'b0111;
            endcase
        end
    end
    2'b01: begin
        axi_len = len[9:2];

        case(len[1:0])
        2'b00: final_strb = 4'b0001;
        2'b01: final_strb = 4'b0011;
        2'b10: final_strb = 4'b0111;
        2'b11: final_strb = 4'b1111;
        endcase

        if(len >= 3)
            initial_strb = 4'b1110;
        else begin
            case(len[1:0])
            2'b00: initial_strb = 4'b0000;
            2'b01: initial_strb = 4'b0010;
            2'b10: initial_strb = 4'b0110;
            2'b11: initial_strb = 4'b1110;
            endcase
        end
    end
    2'b10: begin
        axi_len = len_plus_1[9:2];

        case(len[1:0])
        2'b00: final_strb = 4'b0011;
        2'b01: final_strb = 4'b0111;
        2'b10: final_strb = 4'b1111;
        2'b11: final_strb = 4'b0001;
        endcase

        if(len >= 2)
            initial_strb = 4'b1100;
        else begin
            case(len[1:0])
            2'b00: initial_strb = 4'b0000;
            2'b01: initial_strb = 4'b0100;
            2'b10: initial_strb = 4'b1100;
            2'b11: initial_strb = 4'b1100;
            endcase
        end
    end
    2'b11: begin
        axi_len = len_plus_2[9:2];       
        initial_strb = 4'b1000;

        case(len[1:0])
        2'b00: final_strb = 4'b0111;
        2'b01: final_strb = 4'b1111;
        2'b10: final_strb = 4'b0001;
        2'b11: final_strb = 4'b0011;
        endcase
    end
    endcase
end

always @(posedge clk,posedge rst)
begin
    if(rst) begin
        stored_data <= 0;
        data_out <= 0;
        valid_out <= 0;
    end else begin
        if(!valid_in & valid_out & ready_out) // A transfer occured
            valid_out <= 1'b0;

        if(valid_in & !valid_out)
            valid_out <= 1'b1;

        if(valid_in & (ready_out | !valid_out)) begin
            case(offset[1:0])
            2'b00:;
            2'b01: stored_data[7:0] <= data_in[31:24];
            2'b10: stored_data[15:0] <= data_in[31:16];
            2'b11: stored_data <= data_in[31:8];
            endcase
            case(offset[1:0])
            2'b00: data_out <= data_in;
            2'b01: data_out <= {data_in[23:0],stored_data[7:0]};
            2'b10: data_out <= {data_in[15:0],stored_data[15:0]};
            2'b11: data_out <= {data_in[7:0],stored_data[23:0]};
            endcase
        end
    end
end

endmodule