// ============================================================================
// Module Name:  pulse_shaper
// Description:  The Sine Phase-to-Amplitude Converter (PAC) takes a variable
// 'lut_idx' and polls the appropriate sine value using a precalculated sine
// table. The distance between each 'lut_idx' value is variable and dependent
// on the 'ftw', which the logic can be seen in module "phase_accumulator".
// ============================================================================
`timescale 1ns / 1ps
module pulse_shaper(
    input wire clk_50mhz,               // 50 MHz brought in for the RAM block (write side)
    input wire clk_150mhz,              // 150 MHz clock from PLL (read side)
    input wire rst,                     // master reset switch on-board
    input wire env_en,                  // acts as a rdreq for the RAM block (defaults idle value to 'd0 instead of 'd11)
    input wire [9:0] carrier_idx,       // sine LUT index set by FTW from the phase accumulator (ftw-stepped)
    input wire [9:0] env_idx,           // envelope RAM index, from envelope_accumulator (etw-stepped)
    input wire [9:0] wr_addr,           // write address from HPS
    input wire [9:0] wr_data,           // RL agent adjusted envelope values (won't actually use this for awhile)
    input wire wr_en,                   // write enable from HPS
    output reg [9:0] debug_env,         // outputs plain envelope for debugging purposes
    output reg signed [9:0] debug_car,  // outputs plain carrier for debugging purposes
    output reg signed  [9:0] wave_out   // output data bits going into the external DAC
    );

    // Create ROM Array
    reg [9:0] sine_lut [1023:0];    // defines array of 1024x10 of memory -> "1024 rows of 10 columns of memory"

    // Read carrier ROM block
    initial begin
        $readmemh("sine_lut_2comp.hex", sine_lut);   // read precalculated hex sine LUT formated like 0x000
    end

    // Envelope RAM block Instantiation
    wire [9:0] env_data;

    // Instantiate RAM block
    ram_2_port u_ram_2_port(
        .data      (wr_data),
        .rdaddress (env_idx),
        .rdclock   (clk_150mhz),
        .wraddress (wr_addr),
        .wrclock   (clk_50mhz),
        .wren      (wr_en),
        .q         (env_data)
    );

    // interconnects
    reg signed [20:0] car_env_prod;
    reg signed [9:0] sine_val;
    // gate env_data with env_en
    wire signed [9:0] eff_env = env_en ? env_data : 10'd0;

    // BRAM read -> make sure sine_lut ROM is put into BRAM and shares same clock latency as RAM block
    always @(posedge clk_150mhz) begin
        sine_val <= sine_lut[carrier_idx];
    end

    // Multiply carrier and envelope, rescale back to 10 bits
    always@(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            wave_out <= 10'h000;          // using two's complement so range is [-512,511]
            car_env_prod <= 21'sd0;
        end else begin
            car_env_prod <= $signed({1'b0, eff_env}) * sine_val;   // multiplies carrier x envelope
            wave_out <= car_env_prod[19:10];
            debug_env <= eff_env;
            debug_car <= sine_val;
        end
    end

endmodule