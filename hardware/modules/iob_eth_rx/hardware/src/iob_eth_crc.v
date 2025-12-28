// SPDX-FileCopyrightText: 2025 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps
module iob_eth_crc (
   input             arst_i,
   input             clk_i,
   input             start_i,
   input      [ 7:0] data_i,
   input             data_en_i,
   output reg [31:0] crc_o
);

   always @(posedge clk_i or posedge arst_i)
       if (arst_i) begin
           crc_o <= 32'hffffffff;
       end else if (start_i) begin
           crc_o <= 32'hffffffff;
       end else if (data_en_i) begin
         crc_o[0] <= ^{crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[1] <= ^{crc_o[25], crc_o[31], data_i[0], data_i[6], 
                       crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[2] <= ^{crc_o[26], data_i[5], crc_o[25], crc_o[31], data_i[0], 
                       data_i[6], crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[3] <= ^{crc_o[27], data_i[4], crc_o[26], data_i[5], 
                       crc_o[25], crc_o[31], data_i[0], data_i[6]};
         crc_o[4] <= ^{crc_o[28], data_i[3], crc_o[27], data_i[4], crc_o[26], 
                       data_i[5], crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[5] <= ^{crc_o[29], data_i[2], crc_o[28], data_i[3], crc_o[27], 
                       data_i[4], crc_o[25], crc_o[31], data_i[0], data_i[6], 
                       crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[6] <= ^{crc_o[30], data_i[1], crc_o[29], data_i[2], crc_o[28], 
                       data_i[3], crc_o[26], data_i[5], crc_o[25], crc_o[31], 
                       data_i[0], data_i[6]};
         crc_o[7] <= ^{crc_o[31], data_i[0], crc_o[29], data_i[2], crc_o[27], 
                       data_i[4], crc_o[26], data_i[5], crc_o[24], data_i[7]};
         crc_o[8] <= ^{crc_o[0], crc_o[28], data_i[3], crc_o[27], data_i[4], 
                       crc_o[25], data_i[6], crc_o[24], data_i[7]};
         crc_o[9] <= ^{crc_o[1], crc_o[29], data_i[2], crc_o[28], data_i[3], 
                       crc_o[26], data_i[5], crc_o[25], data_i[6]};
         crc_o[10] <= ^{crc_o[2], crc_o[29], data_i[2], crc_o[27], data_i[4], 
                        crc_o[26], data_i[5], crc_o[24], data_i[7]};
         crc_o[11] <= ^{crc_o[3], crc_o[28], data_i[3], crc_o[27], data_i[4], 
                        crc_o[25], data_i[6], crc_o[24], data_i[7]};
         crc_o[12] <= ^{crc_o[4], crc_o[29], data_i[2], crc_o[28], data_i[3], 
                        crc_o[26], data_i[5], crc_o[25], data_i[6], crc_o[24], 
                        crc_o[30], data_i[1], data_i[7]};
         crc_o[13] <= ^{crc_o[5], crc_o[30], data_i[1], crc_o[29], data_i[2], 
                        crc_o[27], data_i[4], crc_o[26], data_i[5], crc_o[25], 
                        crc_o[31], data_i[0], data_i[6]};
         crc_o[14] <= ^{crc_o[6], crc_o[31], data_i[0], crc_o[30], data_i[1], 
                        crc_o[28], data_i[3], crc_o[27], data_i[4], crc_o[26], 
                        data_i[5]};
         crc_o[15] <= ^{crc_o[7], crc_o[31], data_i[0], crc_o[29], data_i[2], 
                        crc_o[28], data_i[3], crc_o[27], data_i[4]};
         crc_o[16] <= ^{crc_o[8], crc_o[29], data_i[2], crc_o[28], 
                        data_i[3], crc_o[24], data_i[7]};
         crc_o[17] <= ^{crc_o[9], crc_o[30], data_i[1], crc_o[29], 
                        data_i[2], crc_o[25], data_i[6]};
         crc_o[18] <= ^{crc_o[10], crc_o[31], data_i[0], crc_o[30], 
                        data_i[1], crc_o[26], data_i[5]};
         crc_o[19] <= ^{crc_o[11], crc_o[31], data_i[0], crc_o[27], data_i[4]};
         crc_o[20] <= ^{crc_o[12], crc_o[28], data_i[3]};
         crc_o[21] <= ^{crc_o[13], crc_o[29], data_i[2]};
         crc_o[22] <= ^{crc_o[14], crc_o[24], data_i[7]};
         crc_o[23] <= ^{crc_o[15], crc_o[25], data_i[6], crc_o[24], 
                        crc_o[30], data_i[1], data_i[7]};
         crc_o[24] <= ^{crc_o[16], crc_o[26], data_i[5], crc_o[25], 
                        crc_o[31], data_i[0], data_i[6]};
         crc_o[25] <= ^{crc_o[17], crc_o[27], data_i[4], crc_o[26], data_i[5]};
         crc_o[26] <= ^{crc_o[18], crc_o[28], data_i[3], crc_o[27], data_i[4], 
                        crc_o[24], crc_o[30], data_i[1], data_i[7]};
         crc_o[27] <= ^{crc_o[19], crc_o[29], data_i[2], crc_o[28], data_i[3], 
                        crc_o[25], crc_o[31], data_i[0], data_i[6]};
         crc_o[28] <= ^{crc_o[20], crc_o[30], data_i[1], crc_o[29], 
                        data_i[2], crc_o[26], data_i[5]};
         crc_o[29] <= ^{crc_o[21], crc_o[31], data_i[0], crc_o[30], 
                        data_i[1], crc_o[27], data_i[4]};
         crc_o[30] <= ^{crc_o[22], crc_o[31], data_i[0], crc_o[28], data_i[3]};
         crc_o[31] <= ^{crc_o[23], crc_o[29], data_i[2]};
      end

endmodule
