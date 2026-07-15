// ============================================================================
// Module Name: platform_interface
// Description: This module is a custom wrapper. The module does this:
//      1. Connects the HPS demands to the sequencer via the light-weight 
//         AXI bus using an asynchronous FIFO IP block.
//      2. Instantiates the PLL block for 150 MHz operation. 
//      3. Connects the sequencer outputs to the dds to generate the 
//         desired pulse.
//      4. Generates the multiplexer that outputs the data bits into the DAC. 
// ============================================================================
`timescale 1ns / 1ps
module platform_interface(
    input wire clk_50mhz,               // 50 MHz crystal oscillator
    input wire rst,                     // on-board reset
    input wire [31:0] avs_write_data,   // 32-bit avalon write data
    input wire avs_write,               // avalon write enable
    output [9:0] db                     // 10-bit external DAC output 
    );
    
    // 
    // ========================================================
    // Internal Interconnect Wires
    // ========================================================

    // FIFO
    wire wrreq_in;
    wire wrfull_out;
    
    // FIFO <==> Sequencer
    wire [31:0] q_bus;
    wire rdempty_flag;
    wire rdreq_sig;
    
    // 150 MHz Clock Routing
    wire clk_150mhz_net;
    
    // Sequencer <==> NCO
    wire [29:0] ftw_bus;
    wire [29:0] ptw_bus;
    
    // NCO <==> MUX
    wire [9:0] nco_db_out;

    // Sequencer --> MUX
    wire pulse_active_flag;

    // PLL <==> NCO
    wire locked;
    wire nco_rst;

    // ========================================================
    // Combinational Logic
    // ========================================================

    // FIFO Write Gate (Protects against overwriting full FIFO)
    assign wrreq_in = avs_write & ~wrfull_out; 

    // define nco_rst logic: locked needs to be inverted and OR'd with 'rst'
    assign nco_rst = ~locked | rst;
    
    // Output MUX (If pulse is active, output sine wave. Otherwise, output silence)
    assign db = pulse_active_flag ? nco_db_out : 10'h1FF;

    // ========================================================
    // Module Instantiations
    // ========================================================

    // instantiate Asycnhronous FIFO
    async_FIFO u_async_FIFO (
        .aclr   (rst),
        .data   (avs_write_data),
        .rdclk  (clk_150mhz_net),
        .rdreq  (rdreq_sig),
        .wrclk  (clk_50mhz),
        .wrreq  (wrreq_in),
        .q      (q_bus),
        .rdempty(rdempty_flag),
        .wrfull (wrfull_out)
    );

    // instantiate Sequencer Dispatcher 
    sequencer sequencer_inst (
    .clk_150mhz (clk_150mhz_net),
    .rst        (rst),
    .rdempty    (rdempty_flag),
    .q          (q_bus),
    .rdreq      (rdreq_sig),
    .ftw        (ftw_bus),
    .ptw        (ptw_bus),
    .pulse      (pulse_active_flag)
  );

    // instantiate IP Catalog PLL module
    pll_150mhz u_pll_150mhz (
        .refclk     (clk_50mhz),
        .rst        (rst),
        .outclk_0   (clk_150mhz_net),
        .locked     (locked)
    );

    // instantiate the NCO module
    nco  nco_inst (
    .clk_150mhz (clk_150mhz_net),
    .rst        (rst),
    .ftw        (ftw_bus),
    .ptw        (ptw_bus),
    .db         (nco_db_out)
  );
endmodule