// ============================================================================
// Module Name: pulse_controller
// Description: Pulse duration and delay countdown logic 
// ============================================================================
`timescale 1ns / 1ps
module pulse_controller(
    input wire clk_150mhz,          // 150 MHz clock from PLL block
    input wire rst,                 // master on-board reset switch
    input wire timer_start,         // trigger from sequencer dispatcher to signal when to start counting down
    input wire [31:0] timer_data,   // raw pulse duration or delay in clock cycles
    output reg timer_busy,          // output signal telling sequencer dispatcher if timer is busy
    output wire pulse_active        // output signal to flip output pins on or off
    );

    // interconnects 
    reg [30:0] count;               // 31-bit countdown register
    wire pulse_trigger;             // 1-bit signal to drive pulse_active high  

    // slice timer payload
    assign pulse_trigger = timer_data[31];
    assign pulse_active = timer_busy & pulse_trigger; // pulse_active is driven high only is the timer is counting down and the payload says to pulse

    // -------------------------------------------------------------
    // Unified Sequential Logic (SR Latch and Down-Counter)
    // -------------------------------------------------------------

    always@(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            count <= 31'd0;
            timer_busy <= 1'b0;
        end else begin

            // MUX (input 1) & set logic
            if (timer_start) begin
                timer_busy <= 1'b1;             // signify clock is ticking down
                count <= timer_data[30:0];      // assign other 31 bits to the countdown clock 
            end

            // MUX (input 0), subtractor, zero detector
            else if (timer_busy) begin
                if (count == 31'd0) begin
                    timer_busy <= 1'b0;         // reset the SR latch 
                end else begin
                    count <= count - 31'd1;     // subtractor loop
                end
            end
        end
    end

endmodule