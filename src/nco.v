// ============================================================================
// Module Name:  nco
// Description:  Wraps modules phase accumulator and sine_pac and also adds
//               the Phase Tuning Word (PTW), this register offsets the 
//               the accumulated phase, adding a phase offset. 
// Notes: port 'phase_rst' is used in the case where an experiment wants to 
//        pulse with delays and wants a precise phase for each pulse. This is 
//        required as the architecture of the NCO is constantly calculating the 
//        output so 'phase_rst' clears the accumulated phase for the next cycle.
// ============================================================================
`timescale 1ns / 1ps
module nco(
    input wire clk_150mhz,  // 150 MHz clock generated from PLL
    input wire rst,         // master switch on-board
    input wire [29:0] ftw,  // 30-bit register sitting in fabric changing from C program
    input wire [29:0] ptw,  // 30-bit Phase Tuning Word (PTW) from C program
    output wire [9:0] db    // 10-bit output going to external DAC (on GPIO pins)
    );
    // TODO: include 'phase_rst' logic
    // interconnects
    wire [29:0] lut_idx;
    wire [29:0] accumulated_phase;

    // PTW Logic: inject phase offset
    assign lut_idx = accumulated_phase + ptw;

    // instantiate phase accumulator
    phase_accumulator u_phase_accumulator (
        .clk_150mhz         (clk_150mhz),
        .rst                (rst),
        .ftw                (ftw),
        .accumulated_phase  (accumulated_phase)
    );

    // instantiate sine PAC
    sine_pac u_sine_pac (
        .clk_150mhz (clk_150mhz),
        .rst        (rst),
        .lut_idx    (lut_idx),
        .db         (db)
    );

endmodule
