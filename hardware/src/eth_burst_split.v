`timescale 1ns / 1fs

`include "iob_lib.vh"

// Given aligned data, it unaligns it to store into the correct positions
// To be used in a burst transfer
module eth_burst_split (
        input [31:0] data,
        input valid,
        input [3:0] strobe, // This is the initial strobe for the output (if data is DCBA and strobe is 1110, then first data_out is CBA0) (allowed: 1111, 1110, 1100, 1000)
        input last,         // Asserted for the last valid data   

        output reg [31:0] data_out,
        output reg data_valid,
        output reg [3:0] strobe_out,
        output reg last_out,

        input wire delay,

        input clk,
        input rst
        );

reg first;
reg [3:0] initial_strobe;
reg [31:0] stored_bytes;
reg rst_int;          // Set things to zero
reg misaligned_final; // Does a final misaligned 

always @(posedge clk,posedge rst)
begin
    if(rst)
    begin
        first <= 1'b1;
        data_out <= 0;
        data_valid <= 0;
        strobe_out <= 0;
        last_out <= 1'b0;
        initial_strobe <= 4'h0;
        stored_bytes <= 0;
        rst_int <= 1'b0;
        misaligned_final <= 1'b0;
    end 
    else if(!delay) 
    begin

    data_valid <= valid;

    case(1'b1)
    rst_int: begin
        first <= 1'b1;
        data_out <= 0;
        data_valid <= 0;
        strobe_out <= 0;
        last_out <= 1'b0;
        initial_strobe <= 4'h0;
        stored_bytes <= 0;
        rst_int <= 1'b0;
        misaligned_final <= 1'b0;
    end
    valid: begin
        if(first)
        begin
            initial_strobe <= strobe;
            strobe_out <= strobe;
            first <= 1'b0;

            case(1'b1)
                strobe[0]: data_out <= data;              // 1111
                strobe[1]: data_out[31:8] <= data[23:0];  // 1110
                strobe[2]: data_out[31:16] <= data[15:0]; // 1100
                strobe[3]: data_out[31:24] <= data[7:0];  // 1000
                default:;
            endcase

            case(1'b1)
                strobe[0]:;                                   // 1111
                strobe[1]: stored_bytes[7:0] <= data[31:24];  // 1110
                strobe[2]: stored_bytes[15:0] <= data[31:16]; // 1100
                strobe[3]: stored_bytes[23:0] <= data[31:8];  // 1000
                default:;
            endcase
        end
        else 
        begin
            strobe_out <= 4'hf;
            if(last)
            begin
                if(initial_strobe[0]) begin
                    last_out <= 1'b1;
                    data_valid <= 1'b1;
                    rst_int <= 1'b1;
                end else begin
                    misaligned_final <= 1'b1;
                end
            end

            case(1'b1)
                initial_strobe[0]: data_out <= data;                            // 1111
                initial_strobe[1]: data_out <= {data[23:0],stored_bytes[7:0]};  // 1110
                initial_strobe[2]: data_out <= {data[15:0],stored_bytes[15:0]}; // 1100
                initial_strobe[3]: data_out <= {data[7:0],stored_bytes[23:0]};  // 1000
                default:;
            endcase

            case(1'b1)
                initial_strobe[0]:;                                   // 1111
                initial_strobe[1]: stored_bytes[7:0] <= data[31:24];  // 1110
                initial_strobe[2]: stored_bytes[15:0] <= data[31:16]; // 1100
                initial_strobe[3]: stored_bytes[23:0] <= data[31:8];  // 1000
                default:;
            endcase
        end
    end
    misaligned_final: begin
        data_out <= stored_bytes;
        misaligned_final <= 1'b0;
        last_out <= 1'b1;
        data_valid <= 1'b1;
        rst_int <= 1'b1;

        case(1'b1)
            initial_strobe[0]: ;
            initial_strobe[1]: strobe_out <= 4'b0001;
            initial_strobe[2]: strobe_out <= 4'b0011;
            initial_strobe[3]: strobe_out <= 4'b0111;
            default:;
        endcase
    end
    default:;
    endcase
    end
end

endmodule