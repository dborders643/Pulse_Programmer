// ============================================================================
// Module Name:  sine_pac
// Description:  The Sine Phase-to-Amplitude Converter (PAC) takes a variable
// 'lut_idx' and polls the appropriate sine value using a precalculated sine
// table. The distance between each 'lut_idx' value is variable and dependent
// on the 'ftw', which the logic can be seen in module "phase_accumulator".
// ============================================================================
`timescale 1ns / 1ps
module sine_pac(
    input wire clk_150mhz,      // 150 MHz clock from PLL
    input wire rst,             // master reset switch on-board
    input wire [29:0] lut_idx,  // sine LUT index set by FTW from the phase accumulator
    output reg [9:0] db         // output data bits going into the external DAC
    );

    // assign the top 10 MSBs of the LUT index to the output (DAC only has 10 db pins) 
    wire [9:0] lut_addr;
    assign lut_addr = lut_idx[29:20];

    reg [9:0] sine_lut [1023:0];    // defines array of 1024x10 of memory -> "1024 rows of 10 columns of memory"

    initial begin
        $readmemh("sine_lut.hex", sine_lut);   // read precalculated hex sine LUT formated like 0x000
    end

    always@(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            db <= 10'h1FF;          // using centered sine LUT so 1FF == 0, min=0x000, max=0x3FF, mean=0x1FF
        end else begin
            db <= sine_lut[lut_addr];
        end
    end

endmodule