`timescale 1ns/1ps
module iob_eth_crc (
			input 		  clk,
			input 		  rst,
			input 		  start,
			input [3:0] 	  data,
			input 		  data_valid,
			output reg [31:0] crc
			);

   reg [3:0] 	 byte_cnt;  
   reg [3:0] 	 reversed; 
   reg [31:0] 	 crc_reg;
   wire [31:0] 	 next_crc;  

   //Generator polynomial is X"04C11DB7"
   //32   26   23   22   16   12   11   10   8   7   5   4   2   
   //x  + x  + x  + x  + x  + x  + x  + x  + x + x + x + x + x + x + 1

   integer 	 i;

   assign next_crc[0] = data[3] ^ crc_reg[28];
   assign next_crc[1] = data[2] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[2] = data[1] ^ crc_reg[30] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[3] = data[0] ^ crc_reg[31] ^ crc_reg[30] ^ crc_reg[29];
   assign next_crc[4] = crc_reg[0] ^ crc_reg[31] ^ crc_reg[30] ^ crc_reg[28];
   assign next_crc[5] = crc_reg[1] ^ crc_reg[31] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[6] = crc_reg[2] ^ crc_reg[30] ^ crc_reg[29];
   assign next_crc[7] = crc_reg[3] ^ crc_reg[31] ^ crc_reg[30] ^ crc_reg[28];
   assign next_crc[8] = crc_reg[4] ^ crc_reg[31] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[9] = crc_reg[5] ^ crc_reg[30] ^ crc_reg[29];
   assign next_crc[10] = crc_reg[6] ^ crc_reg[31] ^ crc_reg[30] ^ crc_reg[28];
   assign next_crc[11] = crc_reg[7] ^ crc_reg[31] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[12] = crc_reg[8] ^ crc_reg[30] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[13] = crc_reg[9] ^ crc_reg[31] ^ crc_reg[30] ^ crc_reg[29];
   assign next_crc[14] = crc_reg[10] ^ crc_reg[31] ^ crc_reg[30];
   assign next_crc[15] = crc_reg[11] ^ crc_reg[31];
   assign next_crc[16] = crc_reg[12] ^ crc_reg[28];
   assign next_crc[17] = crc_reg[13] ^ crc_reg[29];
   assign next_crc[18] = crc_reg[14] ^ crc_reg[30];
   assign next_crc[19] = crc_reg[15] ^ crc_reg[31];
   assign next_crc[20] = crc_reg[16];
   assign next_crc[21] = crc_reg[17];
   assign next_crc[22] = crc_reg[18] ^ crc_reg[28];
   assign next_crc[23] = crc_reg[19] ^ crc_reg[29] ^ crc_reg[28];
   assign next_crc[24] = crc_reg[20] ^ crc_reg[30] ^ crc_reg[29];
   assign next_crc[25] = crc_reg[21] ^ crc_reg[31] ^ crc_reg[30];
   assign next_crc[26] = crc_reg[22] ^ crc_reg[31] ^ crc_reg[28];
   assign next_crc[27] = crc_reg[23] ^ crc_reg[29];
   assign next_crc[28] = crc_reg[24] ^ crc_reg[30];
   assign next_crc[29] = crc_reg[25] ^ crc_reg[31];
   assign next_crc[30] = crc_reg[26];
   assign next_crc[31] = crc_reg[27];
   
   always @*
     for (i=0; i <= 31; i = i + 1)
       crc[i] =  ~crc_reg[31 - i];

   always @*
     for (i=0; i <= 3; i = i + 1)
       reversed[i] = data[3 - i];
   

   always @(posedge clk, posedge rst)
      if(rst) begin
	 byte_cnt <= 4'b0;
	 crc_reg <= 32'b0;
      end else if(start) begin
         byte_cnt <= 0;
         crc_reg <= 32'b0;
      end else if(data_valid) 
        if(byte_cnt != 8) begin
           crc_reg <= {crc_reg[27:0], ~reversed};
           byte_cnt <= byte_cnt + 1'b1;
        end else 
          crc_reg <= next_crc;

endmodule
