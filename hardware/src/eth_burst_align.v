`timescale 1ns / 1fs

`include "iob_lib.vh"

// Given unaligned data, it aligns it. (Example: transforms A000 - EDCB - 00GF into DCBA - 0GFE)
// To be used in a burst transfer
// There is a two cycle resting period between asserting last and starting a new burst align (asserting first)
module eth_burst_align (
        input [31:0] data,
        input [3:0] strobe, // The strobe must be continuous (initial must be: 1000 or 1100 or 1110 or 1111, then it must be 1111, until the last data where strobe must be 0001 or 0011 or 0111 or 1111)
        input valid,
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
reg rst_int;          // Set things to zero, unless there is a misaligned_final
reg misaligned_final; // Does a final misaligned 
reg [3:0] misaligned_strobe;

always @(posedge clk,posedge rst)
begin
	if(rst)
	begin
		data_out <= 0;
		data_valid <= 0;
		strobe_out <= 0;
		last_out <= 1'b0;
		first <= 1'b1;
		initial_strobe <= 4'h0;
		stored_bytes <= 0;
		rst_int <= 1'b0;
		misaligned_final <= 1'b0;
		misaligned_strobe <= 0;
	end
	else if(!delay) 
	begin

    if(first) // First enabled means not running. The initial cycle does not assert data_valid
    	data_valid <= 1'b0;
    else
    	data_valid <= valid;

    case(1'b1)
    rst_int: begin
		data_out <= 0;
		data_valid <= 0;
		strobe_out <= 0;
		last_out <= 1'b0;
		first <= 1'b1;
		initial_strobe <= 4'h0;
		stored_bytes <= 0;
		rst_int <= 1'b0;
		misaligned_final <= 1'b0;
		misaligned_strobe <= 0;
    end
    valid: begin
        if(first)
		begin
		    first <= 1'b0;
			initial_strobe <= strobe;
			case(1'b1)
			  strobe[0]: stored_bytes <= data;              // 1111
			  strobe[1]: stored_bytes[23:0] <= data[31:8];  // 1110
			  strobe[2]: stored_bytes[15:0] <= data[31:16]; // 1100
			  strobe[3]: stored_bytes[7:0] <= data[31:24];  // 1000
			  default:;
			endcase
		end
		else if(last)
		begin
			case(1'b1)
			  initial_strobe[0]: begin // Initial 1111
			  	data_out <= stored_bytes;
			  	stored_bytes <= data;
			  	misaligned_strobe <= strobe; // Wathever strobe we got is the final one
			  	misaligned_final <= 1'b1;
			  end
			  initial_strobe[1]: begin // Initial 1110
			  	data_out <= {data[7:0],stored_bytes[23:0]};
			    stored_bytes <= data[31:8];
			  	case(1'b1)
			  		strobe[0]: begin // 1111 -> Misaligned 0111
			  			misaligned_strobe <= 4'b0111;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[1]: begin // 0111 -> Misaligned 0011 
			  			misaligned_strobe <= 4'b0011;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[2]: begin // 0011 -> Misaligned 0001
			  			misaligned_strobe <= 4'b0001;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[3]: begin; // 0001 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end
			        default:;
			  	endcase
			  end
			  initial_strobe[2]: begin // Initial 1100
			    data_out <= {data[15:0],stored_bytes[15:0]};
			    stored_bytes <= data[31:16];
			  	case(1'b1)
			  		strobe[0]: begin // 1111 -> Misaligned 0011
			  			misaligned_strobe <= 4'b0011;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[1]: begin // 0111 -> Misaligned 0001 
			  			misaligned_strobe <= 4'b0001;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[2]: begin; // 0011 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end 
			  		strobe[3]: begin; // 0001 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end
			        default:;
			  	endcase
			  end
			  initial_strobe[3]: begin // Initial 1000
			    data_out <= {data[23:0],stored_bytes[7:0]};
			    stored_bytes <= data[31:24];
			  	case(1'b1)
			  		strobe[0]: begin // 1111 -> Misaligned 0001
			  			misaligned_strobe <= 4'b0001;
			  			misaligned_final <= 1'b1;
			  		end
			  		strobe[1]: begin; // 0111 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end  
			  		strobe[2]: begin; // 0011 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end  
			  		strobe[3]: begin; // 0001 -> Aligned
			  			rst_int <= 1'b1;
			  			last_out <= 1'b1;
			  		end
			        default:;
			  	endcase
			  end
              default:;
			endcase
		end
		else // Strobe must be 1111
		begin
			strobe_out <= 4'hf;
			case(1'b1)
			  initial_strobe[0]: begin
			  	data_out <= stored_bytes;
			  	stored_bytes <= data;
			  end
			  initial_strobe[1]: begin
			  	data_out <= {data[7:0],stored_bytes[23:0]};
			    stored_bytes <= data[31:8];
			  end
			  initial_strobe[2]: begin
			  	data_out <= {data[15:0],stored_bytes[15:0]};
			    stored_bytes <= data[31:16];
			  end
			  initial_strobe[3]: begin
			  	data_out <= {data[23:0],stored_bytes[7:0]};
			    stored_bytes <= data[31:24];
			  end
			  default:;
			endcase
		end
	end
    misaligned_final: begin
    	misaligned_final <= 1'b0;
    	data_out <= stored_bytes;
    	data_valid <= 1'b1;
    	last_out <= 1'b1;
    	rst_int <= 1'b1;
    end
    default:;
    endcase
    end
end

endmodule