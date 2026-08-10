// SPDX-FileCopyrightText: 2026 IObundle
//
// SPDX-License-Identifier: CERN-OHL-S-2.0

// Simulation-only Clause 22 MDIO PHY model.
// Responds to read/write transactions on the MDIO bus when PHY_ADDR matches.
// Output is driven on negedge MDC per IEEE 802.3 Clause 22:
// "The PMA shall not update the MDIO output signal until after the falling
//  edge of MDC."

`timescale 1ns / 1ps

module iob_phy_model #(
    parameter PHY_ADDR = 5'd0
) (
    input  wire mdc_i,
    inout  wire mdio_io
);

    reg [15:0] regs [0:31];

    reg mdio_d1;
    reg       in_frame;
    reg [6:0] bit_cnt;
    reg [4:0] phy_addr;
    reg [4:0] reg_addr;
    reg       op_read;
    reg       match;
    reg [15:0] rd_shift;
    reg       mdio_out;
    reg       mdio_oe;

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 16'd0;
        regs[0] = 16'h1000;  // BMCR
        regs[1] = 16'h782D;  // BMSR
        regs[2] = 16'h0141;  // PHY_ID1
        regs[3] = 16'h0CC2;  // PHY_ID2
        mdio_d1   = 1'b1;
        in_frame  = 1'b0;
        bit_cnt   = 7'd0;
        mdio_oe   = 1'b0;
        mdio_out  = 1'b0;
        match     = 1'b0;
        op_read   = 1'b0;
        phy_addr  = 5'd0;
        reg_addr  = 5'd0;
        rd_shift  = 16'd0;
    end

    assign mdio_io = mdio_oe ? (mdio_out ? 1'b1 : 1'b0) : 1'bz;

    // Posedge: state machine and input sampling
    always @(posedge mdc_i) begin
        mdio_d1 <= mdio_io;

        if (!in_frame) begin
            bit_cnt <= 7'd0;
            match   <= 1'b0;

            if (mdio_d1 && !mdio_io) begin
                in_frame <= 1'b1;
            end
        end else begin
            bit_cnt <= bit_cnt + 1'b1;

            case (bit_cnt)
                7'd0: begin end                       // start bit (controller bc=33)

                7'd1: begin
                    op_read <= mdio_io;
                    $display("PHY_TRACE t=%0t cas1 op_read=%0d mdio_io=%0d", $time, mdio_io, mdio_io);
                end
                7'd2: begin end                       // opcode LSB (controller bc=35)

                7'd3:  phy_addr[4] <= mdio_io;        // controller bc=36
                7'd4:  phy_addr[3] <= mdio_io;        // controller bc=37
                7'd5:  phy_addr[2] <= mdio_io;        // controller bc=38
                7'd6:  phy_addr[1] <= mdio_io;        // controller bc=39
                7'd7:  begin                          // controller bc=40
                    phy_addr[0] <= mdio_io;
                    match       <= (phy_addr == PHY_ADDR);
                end

                7'd8:  reg_addr[4] <= mdio_io;        // controller bc=41
                7'd9:  reg_addr[3] <= mdio_io;        // controller bc=42
                7'd10: reg_addr[2] <= mdio_io;        // controller bc=43
                7'd11: reg_addr[1] <= mdio_io;        // controller bc=44
                7'd12: reg_addr[0] <= mdio_io;        // controller bc=45

                7'd13: begin                          // controller bc=46
                    if (match && op_read) rd_shift <= regs[reg_addr];
                end

                default: begin
                    // Write data sample (controller bc=48-63)
                    if (bit_cnt >= 7'd15 && bit_cnt <= 7'd30) begin
                        if (match && !op_read) begin
                            if (bit_cnt == 7'd15 || bit_cnt == 7'd30)
                                $display("PHY_TRACE t=%0t WRITE_DATA bc=%d mdio_io=%d", $time, bit_cnt, mdio_io);
                            rd_shift <= {rd_shift[14:0], mdio_io};
                        end
                    end

                    if (bit_cnt == 7'd31) begin       // end frame (controller bc=64)
                        $display("PHY_TRACE t=%0t cas31 END_FRAME op_read=%d reg_addr=%d match=%d", $time, op_read, reg_addr, match);
                        in_frame <= 1'b0;
                        if (match && !op_read) begin
                            regs[reg_addr] <= rd_shift;
                            $display("PHY_TRACE t=%0t cas31 WRITE reg[%d] <= 0x%04h", $time, reg_addr, rd_shift);
                        end
                    end
                end
            endcase
        end
    end

    // Negedge: drive outputs per Clause 22 (PHY updates MDIO on falling edge of MDC).
    // At negedge, bit_cnt has already been incremented by NBA from the preceding
    // posedge, so bit_cnt maps to controller bc as: negedge_bit_cnt = posedge_case + 1.
    // This means: negedge bit_cnt=14 (after posedge case 13) = controller bc=47,
    // negedge bit_cnt=15 (after posedge case 14) = controller bc=48, etc.
    always @(negedge mdc_i) begin
        if (in_frame && match && op_read) begin
            if (bit_cnt == 7'd14) begin               // controller bc=47 (TA: drive 0)
                mdio_out <= 1'b0;
                mdio_oe  <= 1'b1;
                $display("PHY_TRACE t=%0t negedge DRIVE_TA", $time);
            end else if (bit_cnt >= 7'd15 && bit_cnt <= 7'd30) begin  // D15-D0
                if (bit_cnt == 7'd15 || bit_cnt == 7'd30)
                    $display("PHY_TRACE t=%0t negedge READ_DATA bc=%d rd_shift[15]=%d", $time, bit_cnt, rd_shift[15]);
                mdio_out <= rd_shift[15];
                mdio_oe  <= 1'b1;
                rd_shift <= {rd_shift[14:0], 1'b0};
            end else begin
                mdio_oe <= 1'b0;
            end
        end else begin
            mdio_oe <= 1'b0;
        end
    end

endmodule
