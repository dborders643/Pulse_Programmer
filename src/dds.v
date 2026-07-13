// ============================================================================
// Module Name:  dds
// Description:  Direct Digital Synthesis module. Wraps the NCO module and 
//               Quartus IP PLL block into a single module. Due to cross 
//               domain crossing (CDC), sychronizers are used to protect 
//               against potential metastability issues. 
// ============================================================================
`timescale 1ns / 1ps
module dds(
    input wire clk_50mhz,   // 50 MHz on-board crystal oscillator. Used to feed into the PLL block
    input wire rst,         // on-board master reset switch
    input wire [31:0] ftw,  // this ftw input is clocked at 150 MHz due to the async FIFO
    input wire [31:0] ptw,  // input phase offset value
    output wire [9:0] db,   // 10-bit output fed directly into external DAC
    output wire clk_150mhz  // we output the 150 MHz clock so that we can feed this into the IP asynchronous FIFO block in the dds_wrapper 
    );

    // internal wires to connect PLL to NCO
    wire locked;
    wire nco_rst;

    // define nco_rst logic: locked needs to be inverted and OR'd with 'rst'
    assign nco_rst = ~locked | rst;

    // instantiate IP Catalog PLL module
    pll_150mhz u_pll_150mhz (
        .refclk     (clk_50mhz),
        .rst        (rst),
        .outclk_0   (clk_150mhz),
        .locked     (locked)
    );

    // instantiate nco module
    nco u_nco (
        .clk_150mhz (clk_150mhz),
        .rst        (nco_rst),
        .ftw        (ftw),
        .ptw        (ptw),
        .db         (db)
    );

endmodule
