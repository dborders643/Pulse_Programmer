// ============================================================================
// Module Name:  nco
// Description:  Wraps modules phase accumulator and sine_pac and also adds
//               the Phase Tuning Word (PTW), this register offsets the 
//               the accumulated phase, adding a phase offset. 
// ============================================================================
`timescale 1ns / 1ps
module nco(
    input wire clk_150mhz,      // 150 MHz clock generated from PLL
    input wire rst,             // master switch on-board
    input wire [28:0] ftw,      // 29-bit register sitting in fabric changing from C program
    input wire [28:0] ptw,      // 29-bit Phase Tuning Word (PTW) from C program
    input wire [28:0] atw,      // 29-bit scaling factor to scale the amplitude of the ouput wave
    input phase_rst,            // phase reset from sequencer
    output wire signed [9:0] db // 10-bit output going to external DAC (on GPIO pins)
    );

    // interconnects
    wire [28:0] lut_idx;
    wire [28:0] accumulated_phase;
    wire signed [9:0] lut_out;

    // PTW Logic: inject phase offset
    assign lut_idx = accumulated_phase + ptw;

    // instantiate phase accumulator
    phase_accumulator u_phase_accumulator (
        .clk_150mhz         (clk_150mhz),
        .rst                (rst),
        .ftw                (ftw),
        .phase_rst          (phase_rst),
        .accumulated_phase  (accumulated_phase)
    );

    // TODO: instantiate a envelope accumulator. This must also include a 'etw'. Must edit files, nco, sequencer. Also need to create a 'envelope_accumulator.v' module
    // TODO: generate a envelope.hex file and change the ip RAM block to automatically load that
    // instantiate pulse shaper
    pulse_shaper u_pulse_shaper(
        .clk_50mhz  (clk_50mhz),
        .clk_150mhz (clk_150mhz),
        .rst        (rst),
        .lut_idx    (lut_idx),
        .env_idx    (env_idx),  // !: this won't work in current state. Look to TODOs to find fix.
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),
        .wr_en      (wr_en),
        .lut_out    (lut_out)
    );

    // implement ATW logic
    reg signed [20:0] product;  // multiplying bytes increases bit size

    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            product <= 21'sd0;  // sd means signed decimal
        end else begin
            product <= lut_out * $signed({1'b0, atw[10:0]});     // only want atw to be a value from [0,1024] (11-bit) and have to lead with 0 to enforce twos complement
        end
    end

    // pull top 10 bits of product
    assign db = product[19:10];

endmodule