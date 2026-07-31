// ============================================================================
// Module Name:  accumulator
// Description:  Increments the LUT index by the frequency tuning word (FTW).
//               And increments the env_ind by the etw.
// ============================================================================
`timescale 1ns / 1ps
module accumulator(
    input wire clk_150mhz,              // 150 MHz clock from PLL
    input wire rst,                     // master reset switch coming from on board
    input wire carrier_rst,             // reset for the continously counting carrier wave
    input wire env_en,                  // enable to start envelope when in COUNTDOWN state
    input wire [28:0] ftw,              // ftw calculated from software
    input wire [28:0] ptw,              // ptw calculated from software
    input wire [28:0] etw,              // etw calculated from software
    output wire [9:0] carrier_idx,      // carrier index to traverse through ROM at ftw pace
    output wire [9:0] env_idx           // envelope index to traverse through RAM at etw pace
    );

    // interconnects
    reg  [28:0] carrier_acc;    // 29-bit carrier 
    reg  [28:0] env_acc;        // 29-bit envelope
    wire [28:0] acc_phase;      // 29-bit accumulated phase 
    
    // Offset initial phase
    assign acc_phase = carrier_acc + ptw;

    // carrier_idx logic
    always@(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            carrier_acc <= 29'd0;
        end else begin
            if (carrier_rst) begin
                carrier_acc <= 29'd0;
            end else begin
            carrier_acc <= carrier_acc + ftw;
            end
        end
    end

    // env_idx logic
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            env_acc <= 29'd0;
        end else if (env_en) begin
            // check if env_acc has stepped through max RAM addr (10'd1023)
            if (env_acc[28:19] >= 10'd1023) begin
                env_acc <= env_acc;     // hold at max RAM addr
            end else begin
               env_acc <= env_acc + etw; 
            end
        end else begin
            env_acc <= 29'd0;
        end
    end
    
    // assign outputs
    assign carrier_idx = acc_phase[28:19];
    assign env_idx     = env_acc[28:19]; 

endmodule