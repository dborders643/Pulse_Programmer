// ============================================================================
// Module Name:  nco
// Description:  Wraps accumulator and pulse_shaper module. Also scales output
//               wave to a normalized user demanded wave from [0,1.0] 
// ============================================================================
`timescale 1ns / 1ps
module nco(
    input wire clk_50mhz,       // 50 MHz for RAM block
    input wire clk_150mhz,      // 150 MHz clock generated from PLL
    input wire rst,             // master switch on-board
    input wire carrier_rst,     // carrier reset to reset continously counting phase
    input wire env_en,          // envelope enable from sequencer
    input wire [9:0] wr_addr,   // write address from HPS
    input wire [9:0] wr_data,   // data containing updated envelope values via the RL agent
    input wire wr_en,           // RAM write enable from HPS
    input wire [28:0] ftw,      // 29-bit register sitting in fabric changing from C program
    input wire [28:0] ptw,      // 29-bit Phase Tuning Word (PTW) from C program
    input wire [28:0] atw,      // 29-bit scaling factor to scale the amplitude of the ouput wave
    input wire [28:0] etw,      // 29-bit envelope tuning word to step through pulse at correct rate
    output wire signed [9:0] db // 10-bit output going to external DAC (on GPIO pins)
    );

    // interconnects
    wire [9:0] carrier_idx_bus;
    wire [9:0] env_idx_bus;
    wire signed [9:0] wave_out;

    // instantiate accumulator
    accumulator u_accumulator(
        .clk_150mhz  (clk_150mhz),
        .rst         (rst),
        .carrier_rst (carrier_rst),
        .env_en      (env_en),
        .ftw         (ftw),
        .ptw         (ptw),
        .etw         (etw),
        .carrier_idx (carrier_idx_bus),
        .env_idx     (env_idx_bus)
    );

    // instantiate pulse shaper
    pulse_shaper u_pulse_shaper(
        .clk_50mhz   (clk_50mhz),
        .clk_150mhz  (clk_150mhz),
        .rst         (rst),
        .carrier_idx (carrier_idx_bus),
        .env_idx     (env_idx_bus),
        .wr_addr     (wr_addr),     // ?: what does this do
        .wr_data     (wr_data),     // ?: what does this do
        .wr_en       (wr_en),       // ?: what does this do
        .wave_out    (wave_out)
    );

    // ATW logic
    reg signed [20:0] product;  // multiplying bytes increases bit size

    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            product <= 21'sd0;  // sd means signed decimal
        end else begin
            product <= wave_out * $signed({1'b0, atw[10:0]});     // only want atw to be a value from [0,1024] (11-bit) and have to lead with 0 to enforce twos complement
        end
    end

    // pull top 10 bits of product
    assign db = product[19:10];

endmodule