// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0

// Standalone testbench for iob_eth_mii_management + iob_phy_model.
// Tests Clause 22 MDIO read/write transactions end-to-end.

`timescale 1ns / 1ps

module iob_miim_tb;

    reg clk_i;
    reg cke_i;
    reg arst_i;

    reg  [31:0] miimoder_i;
    reg  [31:0] miicommand_i;
    reg  [31:0] miiaddress_i;
    reg  [31:0] miitx_data_i;
    wire [31:0] miirx_data_o;
    wire [31:0] miistatus_o;
    wire        miicommand_clr_o;

    wire        mii_mdc_o;
    tri1        mii_mdio_io;  // tri1: resolves to 1 when all drivers are Z (pull-up)

    // MII Management controller
    iob_eth_mii_management #(
        .FPGA_TOOL("other")
    ) u_miim (
        .clk_i          (clk_i),
        .cke_i          (cke_i),
        .arst_i         (arst_i),
        .miimoder_i     (miimoder_i),
        .miicommand_i   (miicommand_i),
        .miiaddress_i   (miiaddress_i),
        .miitx_data_i   (miitx_data_i),
        .miirx_data_o   (miirx_data_o),
        .miistatus_o    (miistatus_o),
        .miicommand_clr_o(miicommand_clr_o),
        .mii_mdc_o      (mii_mdc_o),
        .mii_mdio_io    (mii_mdio_io)
    );

    // PHY model
    iob_phy_model #(
        .PHY_ADDR(5'd0)
    ) u_phy (
        .mdc_i  (mii_mdc_o),
        .mdio_io(mii_mdio_io)
    );

    // Clock generation (100 MHz)
    always #5 clk_i = ~clk_i;

    // Drive the MII management register interface
    task mii_write;
        input [4:0] phy_addr;
        input [4:0] reg_addr;
        input [15:0] data;
        reg [31:0] timeout;
        begin
            @(posedge clk_i) #1;
            miiaddress_i <= {19'd0, reg_addr, 3'd0, phy_addr};
            miitx_data_i <= {16'd0, data};
            miicommand_i <= 32'd4;
            @(posedge clk_i) #1;
            timeout = 0;
            while (miistatus_o[1]) begin
                @(posedge clk_i) #1;
                timeout = timeout + 1;
                if (timeout > 50000) begin
                    $display("  ERROR: mii_write timeout (busy stuck high)");
                    $finish;
                end
            end
            miicommand_i <= 32'd0;
            @(posedge clk_i) #1;
        end
    endtask

    task mii_read;
        input [4:0] phy_addr;
        input [4:0] reg_addr;
        output [15:0] data;
        reg [31:0] timeout;
        begin
            @(posedge clk_i) #1;
            miiaddress_i <= {19'd0, reg_addr, 3'd0, phy_addr};
            miicommand_i <= 32'd2;
            @(posedge clk_i) #1;
            timeout = 0;
            while (miistatus_o[1]) begin
                @(posedge clk_i) #1;
                timeout = timeout + 1;
                if (timeout > 50000) begin
                    $display("  ERROR: mii_read timeout (busy stuck high)");
                    $display("  DIAG: state=%0d bit_cnt=%0d mdc=%0d start_req=%0d",
                             u_miim.state, u_miim.bit_cnt, u_miim.mdc, u_miim.start_req);
                    $display("  DIAG: mdio_oe=%0d mdio_out=%0d mdio_iobuf_o=%0d mii_mdio_io=%0d",
                             u_miim.mdio_oe, u_miim.mdio_out, u_miim.mdio_iobuf_o, mii_mdio_io);
                    $display("  DIAG: op_read=%0d busy=%0d done_pulse=%0d mdc_rise=%0d mdc_fall=%0d",
                             u_miim.op_read, u_miim.busy, u_miim.done_pulse, u_miim.mdc_rise, u_miim.mdc_fall);
                    $display("  DIAG: state_nxt=%0d bit_cnt_nxt=%0d rx_data=%0h",
                             u_miim.state_nxt, u_miim.bit_cnt_nxt, u_miim.rx_data);
                    $finish;
                end
            end
            data = miirx_data_o[15:0];
            miicommand_i <= 32'd0;
            @(posedge clk_i) #1;
        end
    endtask

    integer errors;
    reg [15:0] rd_data;

    // Debug: trace PHY driving during frame
    reg [6:0] last_bc;
    reg [6:0] last_state_bc;
    initial begin last_bc = 0; last_state_bc = 0; end
    always @(posedge mii_mdc_o) begin
        if (u_miim.state != 0) begin
            if (u_miim.bit_cnt != last_state_bc) begin
                $display("STATE t=%0t state=%0d bc=%0d op_read=%0d cmd=%0d mdio_io=%0d ctrl_oe=%0d ctrl_out=%0d ctrl_out_nxt=%0d",
                         $time, u_miim.state, u_miim.bit_cnt, u_miim.op_read, miicommand_i, mii_mdio_io,
                         u_miim.mdio_oe, u_miim.mdio_out, u_miim.mdio_out_nxt);
                last_state_bc = u_miim.bit_cnt;
            end
        end else begin
            last_state_bc = 0;
        end
    end

    initial begin
        clk_i         = 0;
        cke_i         = 1;
        arst_i        = 0;
        miimoder_i    = 32'd0;
        miicommand_i  = 32'd0;
        miiaddress_i  = 32'd0;
        miitx_data_i  = 32'd0;
        errors        = 0;

        // Reset
        #10 arst_i = 1;
        #10 arst_i = 0;
        #10;

        // Let clkdiv_reg stabilize at default (40), then set divider to 4
        miimoder_i = 32'd4;
        // Wait for clkdiv_reg to take effect (needs one posedge clk_i)
        @(posedge clk_i) #1;
        @(posedge clk_i) #1;

    // Test 1: Write 0xA5A5 to PHY reg 0x1F, read back
    $write("Test 1: Write 0xA5A5 to PHY reg 0x1F, read back...");
    mii_write(5'd0, 5'h1F, 16'hA5A5);
    mii_read(5'd0, 5'h1F, rd_data);
    if (rd_data !== 16'hA5A5) begin
        $display("  FAIL: expected 0xA5A5, got 0x%04X", rd_data);
        errors = errors + 1;
    end else begin
        $display("  PASS");
    end

        // Test 2: Read PHY_ID1 register (reg 2)
        $write("Test 2: Read PHY_ID1 (reg 2), expected 0x0141...");
        mii_read(5'd0, 5'd2, rd_data);
        if (rd_data !== 16'h0141) begin
            $display("  FAIL: expected 0x0141, got 0x%04X", rd_data);
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end

        // Test 3: Read PHY_ID2 register (reg 3)
        $write("Test 3: Read PHY_ID2 (reg 3), expected 0x0CC2...");
        mii_read(5'd0, 5'd3, rd_data);
        if (rd_data !== 16'h0CC2) begin
            $display("  FAIL: expected 0x0CC2, got 0x%04X", rd_data);
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end

        // Test 4: Read back the written value from reg 0x1F
        $write("Test 4: Read back reg 0x1F, expected 0xA5A5...");
        mii_read(5'd0, 5'h1F, rd_data);
        if (rd_data !== 16'hA5A5) begin
            $display("  FAIL: expected 0xA5A5, got 0x%04X", rd_data);
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end

        // Test 5: Write 0x1234, read back
        $write("Test 5: Write 0x1234 to reg 0x10, read back...");
        mii_write(5'd0, 5'h10, 16'h1234);
        mii_read(5'd0, 5'h10, rd_data);
        if (rd_data !== 16'h1234) begin
            $display("  FAIL: expected 0x1234, got 0x%04X", rd_data);
            errors = errors + 1;
        end else begin
            $display("  PASS");
        end

        // Summary
        if (errors == 0) begin
            $display("=== ALL TESTS PASSED ===");
        end else begin
            $display("=== %0d TEST(S) FAILED ===", errors);
        end

        #100 $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("miim_tb.vcd");
        $dumpvars(0, iob_miim_tb);
    end

endmodule
