`timescale 1ns / 1fs

`include "iob_lib.vh"

module eth_burst_split #(
		parameter NO_SMALL_TRANSFER = 1) // If 1, disallows transfers with len < 4 (Less logic and better timing). Otherwise, set it to zero
	(
        input [31:0] data,
        input transfer,  // When asserted, indicates that a transfer occured and the bytes not sent from data are stored for the next transfer
        input [1:0] offset,
        input [9:0] len, // Transfer length, in bytes. Must be smaller than 1024 bytes (maximum length for a 4 byte size burst). Not the same as axi len, this encodes directly the amount of bytes to transfer (len == zero is not valid)
        
        output reg [31:0] data_out, // Data out depends on len.
        
        output reg [3:0] initial_strb,
        output reg [3:0] final_strb,   // Only meaningful for transfers where axi_len > 0
        output reg [7:0] axi_len,

        input clk,
        input rst
    );

reg [23:0] stored_data;

wire [9:0] len_minus_1 = (len - 10'h1);
wire [9:0] len_plus_1 = (len + 10'h1);
wire [9:0] len_plus_2 = (len + 10'h2);

always @*
begin
    data_out = 32'h0;
    initial_strb = 4'h0;
    final_strb = 4'h0;
    axi_len = 8'h0;

    case(offset[1:0])
    2'b00: begin
    	axi_len = len_minus_1[9:2];
        data_out = data;

        case(len[1:0])
            2'b00: final_strb = 4'b1111;
            2'b01: final_strb = 4'b0001;
            2'b10: final_strb = 4'b0011;
            2'b11: final_strb = 4'b0111;
        endcase

		if(NO_SMALL_TRANSFER || (len >= 4))
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
        data_out = {data[23:0],stored_data[7:0]};

        case(len[1:0])
            2'b00: final_strb = 4'b0001;
            2'b01: final_strb = 4'b0011;
            2'b10: final_strb = 4'b0111;
            2'b11: final_strb = 4'b1111;
        endcase

		if(NO_SMALL_TRANSFER || (len >= 3))
			initial_strb = 4'b1110;
		else begin
            case(len[1:0])
                2'b00: initial_strb = 4'h0000;
                2'b01: initial_strb = 4'b0010;
                2'b10: initial_strb = 4'b0110;
                2'b11: initial_strb = 4'b1110;
            endcase
        end
    end
    2'b10: begin
		axi_len = len_plus_1[9:2];
        data_out = {data[15:0],stored_data[15:0]};

        case(len[1:0])
            2'b00: final_strb = 4'b0011;
            2'b01: final_strb = 4'b0111;
            2'b10: final_strb = 4'b1111;
            2'b11: final_strb = 4'b0001;
        endcase

        if(NO_SMALL_TRANSFER || (len >= 2))
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
        data_out = {data[7:0],stored_data[23:0]};       
        initial_strb = 4'b1000;

        case(len[1:0])
            2'b00: final_strb = 4'b0111;
            2'b01: final_strb = 4'b1111;
            2'b10: final_strb = 4'b0001;
            2'b11: final_strb = 4'b0011;
        endcase
    end
    default:;
    endcase
end

always @(posedge clk,posedge rst)
begin
	if(rst) begin
		stored_data <= 0;
	end 
	else if(transfer) begin
		case(offset[1:0])
		2'b00:;
		2'b01: stored_data[7:0] <= data[31:24];
		2'b10: stored_data[15:0] <= data[31:16];
		2'b11: stored_data <= data[31:8];
		default:;
		endcase
	end
end

endmodule