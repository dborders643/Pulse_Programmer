// ============================================================================
// Module Name: dds_tb.v
// Description: Tests if DDS module works, this only tests DDS hardware, not ISA
// ============================================================================
`include "../src/dds.v"
`timescale 1ns / 1ps

module dds_tb;

    //Ports
    reg  clk_50mhz;
    reg  rst;
    reg [31:0] ftw;
    reg [31:0] ptw;
    wire [9:0] db;
    wire  clk_150mhz;

    dds  dds_inst (
        .clk_50mhz  (clk_50mhz),
        .rst        (rst),
        .ftw        (ftw),
        .ptw        (ptw),
        .db         (db),
        .clk_150mhz (clk_150mhz)
    );

    // 50 MHz clock generation
    always begin
        #10 clk_50mhz = ~clk_50mhz ;
    end

    // Begin Simulation
    initial begin
        // initialize inputs
        clk_50mhz = 0;
        rst = 0;
        ftw = 0;
        ptw = 0;

        // 1. System Reset
        #40;
        rst = 1'b1;
        #40;
        rst = 1'b0;
        #100;       // wait for PLL sim block to stabilize and lock

        // 2. Configure Frequency (FTW)
        // passing in 1 MHz desired f_out --> FTW = (f_out * 2^N) / f_ref_clk ==> FTW = (1e6*2^32) / 150e6 = 32'd28633115 = 32'h01B4_E61B
        ftw = 32'h01B4_E61B;
        #1000;

        // 3. Configure Phase Offset  (PTW)
        // passing in 90 degree desired phase_deg --> PTW = (phase_deg * 2^N) / 360 ==> PTW = (90 * 2^32) / 360 = 32'd1073741824 = 32'h4000_0000
        ptw = 32'h4000_0000;
        #1000;

        // 4. Turn off DDS
        rst = 1;
        #100;

        // End Simulation
        $stop;
    end

endmodule