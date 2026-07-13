// ============================================================================
// Module Name: platform_interface
// Description: This module is a custom wrapper. The module does these things:
//      1. Connects the HPS demands to the pulse sequencer via the light-weight 
//         AXI bus using an asynchronous FIFO IP block. 
//      2. Connects the pulse sequencer outputs to the dds to generate the 
//         desired pulse.
//      3. Generates the multiplexer that outputs the data bits into the DAC. 
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
    
    // FIFO <==> Sequencer Dispatcher
    wire [31:0] q_bus;
    wire rdempty_flag;
    wire rdreq_sig;
    
    // 150 MHz Clock Routing
    wire clk_150mhz_net;
    
    // Sequencer <==> DDS
    wire [31:0] ftw_bus;
    wire [31:0] ptw_bus;
    
    // DDS <==> MUX
    wire [9:0] dds_db_out;

    // Sequencer <==> Pulse Controller
    wire [31:0] timer_data_bus;
    wire timer_start_flag;
    wire timer_busy_flag;

    // Pulse Controller --> MUX
    wire pulse_active_flag;
    

    // ========================================================
    // Combinational Logic
    // ========================================================

    // FIFO Write Gate (Protects against overwriting full FIFO)
    assign wrreq_in = avs_write & ~wrfull_out; 
    
    // Output MUX (If pulse is active, output sine wave. Otherwise, output silence)
    assign db = pulse_active_flag ? dds_db_out : 10'h1FF;

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
    sequencer_dispatcher u_sequencer_dispatcher(
        .clk_150mhz  (clk_150mhz_net),
        .rst         (rst),
        .q           (q_bus),
        .rdempty     (rdempty_flag),
        .timer_busy  (timer_busy_flag),
        .rdreq       (rdreq_sig),
        .ftw         (ftw_bus),
        .ptw         (ptw_bus),
        .timer_data  (timer_data_bus),
        .timer_start (timer_start_flag)
    );
    
    // instantiate DDS Core
    dds u_dds(
        .clk_50mhz  (clk_50mhz),
        .rst        (rst),
        .ftw        (ftw_bus),
        .ptw        (ptw_bus),
        .db         (dds_db_out),
        .clk_150mhz (clk_150mhz_net)
    );
    
    // instantiate pulse controller
    pulse_controller u_pulse_controller(
        .clk_150mhz   (clk_150mhz_net),
        .rst          (rst),
        .timer_start  (timer_start_flag),
        .timer_data   (timer_data_bus),
        .timer_busy   (timer_busy_flag),
        .pulse_active (pulse_active_flag)
    );

endmodule