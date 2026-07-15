// ============================================================================
// Module Name:  pll_150mhz
// Description:  Phase-Locked Loop (PLL) simulation block. This module is NOT
//               an emulation NOR the IP Catalog block. It is described here 
//               purely for testbench purposes.
// ============================================================================
`timescale 1ns / 1ps
module pll_150mhz(
    input wire refclk,      // input 50 MHz on-board clock
    input wire rst,         // on-board master reset
    output reg outclk_0,    // output 150 MHz clock
    output reg locked       // tells if loop is stable or still in transient --> 0 == transient, 1 == stable
    );

    // Initialize PLL Behavior
    initial begin
        outclk_0 = 0;
        locked = 0;
    end

    // Simulate Lock Delay
    always@(posedge refclk or posedge rst) begin
        if (rst) begin
            locked <= 0;
        end else begin
            #100 locked <= 1;   // lock after a brief delay (100 ns)
        end
    end

    // Generate 150 MHz clock output (period = ~6.67 ns)
    always begin
        #3.333 outclk_0 = ~outclk_0;
    end

endmodule