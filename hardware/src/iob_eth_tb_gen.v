`timescale 1ns/1ps

`include "iob_eth_defs.vh"

// Testbench module to exercise the iob_eth module
// For now, simple acts as a loopback, sending any message received back after a few cycles

module iob_eth_tb_gen(
    input  RX_CLK,
    input [3:0] RX_DATA,
    input RX_DV,

    input  TX_CLK,
    output reg [3:0] TX_DATA,
    output reg TX_EN,

    input clk,
    input reset
    );

reg [15:0] counter;

reg  [3:0] savedRX[4000:0];
wire [3:0] loopbackTX[4000:0];

generate
    genvar eth_tb_i;

    for(eth_tb_i = 0; eth_tb_i < 12; eth_tb_i = eth_tb_i + 1)
    begin
      assign loopbackTX[eth_tb_i] = savedRX[12+eth_tb_i]; // Swap the MAC addresses (12 nibbles == 6 bytes)
      assign loopbackTX[12+eth_tb_i] = savedRX[eth_tb_i];
    end

    for(eth_tb_i = 24; eth_tb_i < 4000; eth_tb_i = eth_tb_i + 1)
    begin
      assign loopbackTX[eth_tb_i] = savedRX[eth_tb_i]; // The remaining message + payload remains the same
    end
endgenerate

reg [15:0] savedRXCounter;
reg [15:0] sendingTXCounter;

`define SEND_ARRAY loopbackTX

wire [7:0] data = {`SEND_ARRAY[sendingTXCounter],`SEND_ARRAY[sendingTXCounter-1]};

reg rxPartEnabled;
reg [3:0] rxPartState;
reg [15:0] rxWaitReg;
reg rxReset;

reg [15:0] txSendSize,rxSendSize; // Do not send the last 4 crc bytes, since 

reg txPartEnabled;
reg [3:0] txPartState;
reg txReset;

reg rxEnableTx;
reg txEnableRx;

always @(posedge RX_CLK,posedge reset)
begin
      rxEnableTx <= 0;

      if(rxPartEnabled)
      begin
        case(rxPartState)
        4'h0: begin // Wait for 
            if(RX_DV && RX_DATA == 4'hD) begin
                rxPartState <= 4'h1;
            end
        end
        4'h1: begin // Collect nibbles until end of message
            if(RX_DV) begin
                savedRX[savedRXCounter] <= RX_DATA;
                savedRXCounter <= savedRXCounter + 1;
            end else begin
                rxPartState <= 4'h2;
            end
        end
        4'h2: begin // Wait some cycles before starting TX
            rxWaitReg <= rxWaitReg + 1;
            if(rxWaitReg == 10) begin
                rxEnableTx <= 1; // Start TX
                txSendSize <= savedRXCounter - 11'h8;
                rxPartEnabled <= 0;
                rxReset <= 1;
            end
        end
        endcase
      end

      if(txEnableRx)
      begin
        rxPartEnabled <= 1;
      end

      if(reset | rxReset)
      begin
            rxPartState <= 0;
            rxWaitReg <= 0;
            rxReset <= 0;
            savedRXCounter <= 0;
      end

      if(reset)
      begin
            rxPartEnabled <= 1; // Start enabled
            txSendSize <= 0;
      end
end

// crc
reg             crc_en;
wire [31:0]     crc_value;
wire [31:0]     crc_out;

iob_eth_crc
 crc_eth (
         .clk(TX_CLK),
         .rst(reset),

         .start(txPartState == 0),

         .data_in(data),
         .data_en(crc_en),
         .crc_out(crc_value)
         );

function [7:0] reverse_byte;
  input [7:0]    word;
  integer        i;

  begin
     for (i=0; i < 8; i=i+1)
       reverse_byte[i]=word[7-i];
  end
endfunction

assign crc_out = ~{reverse_byte(crc_value[31:24]),
                  reverse_byte(crc_value[23:16]),
                  reverse_byte(crc_value[15:8]),
                  reverse_byte(crc_value[7:0])};

always @(posedge TX_CLK,posedge reset)
begin
      txEnableRx <= 0;

      if(txPartEnabled)
      begin
        case(txPartState)
        4'h0: begin // Start the sending process
            TX_EN <= 1;
            TX_DATA <= 4'h5;
            txPartState <= 4'h1;
        end
        4'h1: begin
            TX_DATA <= 4'hD;
            txPartState <= 4'h2;
        end
        4'h2: begin // Send all data except the CRC bytes
            TX_DATA <= `SEND_ARRAY[sendingTXCounter];
        sendingTXCounter <= sendingTXCounter + 1;

            if(sendingTXCounter[0] == 1'b0)
                crc_en <= 1'b1;
            else
                crc_en <= 1'b0;

            if(sendingTXCounter == rxSendSize) begin
                TX_DATA <= crc_out[27:24];
                txPartState <= 4'h3;
                crc_en <= 1'b0;
            end
        end
        4'h3: begin
            TX_DATA <= crc_out[31:28];
            txPartState <= 4'h4;
        end

        4'h4: begin
            TX_DATA <= crc_out[19:16];
            txPartState <= 4'h5;
        end

        4'h5: begin
            TX_DATA <= crc_out[23:20];
            txPartState <= 4'h6;
        end

        4'h6: begin
            TX_DATA <= crc_out[11:8];
            txPartState <= 4'h7;
        end

        4'h7: begin
            TX_DATA <= crc_out[15:12];
            txPartState <= 4'h8;
        end

        4'h8: begin
            TX_DATA <= crc_out[3:0];
            txPartState <= 4'h9;
        end

        4'h9: begin
            TX_DATA <= crc_out[7:4];
            txPartState <= 4'hA;
        end
        
        4'hA: begin
            TX_EN <= 0;
            txPartState <= 4'h0;
            txPartEnabled <= 0;
            txEnableRx <= 1;
            txReset <= 1;
        end
        endcase
      end

      if(rxEnableTx)
      begin
        txPartEnabled <= 1;
        rxSendSize <= txSendSize;
      end

      if(reset | txReset)
      begin
            txPartEnabled <= 0;
            txPartState <= 0;
            txReset <= 0;
            TX_EN <= 0;
            crc_en <= 0;
            rxSendSize <= 0;
            sendingTXCounter <= 0;
      end

end

endmodule