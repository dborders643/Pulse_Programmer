// ============================================================================
// Module Name:  phase_accumulator
// Description:  Increments the LUT index by the frequency tuning word (FTW).
// ============================================================================
`timescale 1ns / 1ps
module phase_accumulator(
    input wire clk_150mhz,              // 150 MHz clock from PLL
    input wire [29:0] ftw,              // frequency tuning word calculated from C program sent via LW_AXI bus
    input wire rst,                     // master reset switch coming from on board button (will have to update this)
    output reg [29:0] accumulated_phase // output value from phase accumulator
    );

    always@(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            accumulated_phase <= 30'b0;
        end else begin
            accumulated_phase <= accumulated_phase + ftw;       // step through sine LUT at 'ftw' pace
        end
    end
endmodule
