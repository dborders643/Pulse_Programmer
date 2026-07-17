// ============================================================================
// Module Name: platform_interface_tb.v
// Description: Tests if rf pulse works using ISA opcodes
// ============================================================================
`include "../src/platform_interface.v"
`timescale 1ns / 1ps

module platform_interface_tb();

    // testbench stimulus signals
    reg clk_50mhz;
    reg rst;
    reg [31:0] avs_write_data;
    reg avs_write;
    // output
    wire [9:0] db;

    // opcodes defined
    localparam OP_FTW = 2'b00;
    localparam OP_PTW = 2'b01; 
    localparam OP_PULSE = 2'b10;
    localparam OP_DELAY = 2'b11;

    // instantiate top-level module (platform_interface.v)
    platform_interface dut (
        .clk_50mhz      (clk_50mhz),
        .rst            (rst),
        .avs_write_data (avs_write_data),
        .avs_write      (avs_write),
        .db             (db)
    );

    // 50 MHz clock generation (20 ns period)
    always begin
        #10 clk_50mhz = ~clk_50mhz;
    end

    // Helper Task to mimic HPS bus write
    task avalon_write;
        input [31:0] data;
        begin
            avs_write_data = data;
            avs_write = 1'b1;
            @(posedge clk_50mhz);
            #1;
            avs_write = 1'b0;
        end
    endtask

    // Simulation Process
    initial begin
        // initialize inputs
        clk_50mhz = 1'b0;
        rst = 1'b0;
        avs_write_data = 32'h0;
        avs_write = 1'b0;

        // 1. System Reset
        #40;
        rst = 1'b1;
        #40;
        rst = 1'b0;
        #100;       // wait for PLL sim block to stabilize and lock

        // 2. Configure Frequency (FTW)
        // passing in 1 MHz desired f_out --> FTW = f_out * 2^N/f_ref_clk ==> FTW = 1e6*2^30 / 150e6 = 30'd7158279 = 30'h6D3A07
        avalon_write({OP_FTW, 30'h6D3A07});
        #100;
        
        // 3. Execute an RF Pulse (Duration = 500 clock cycles)
        avalon_write({OP_PULSE, 30'h1F4});
        #1000;

        // 4. Configure Phase Offset  (PTW)
        // passing in 90 degree desired phase_deg --> PTW = (phase_deg * 2^N) / 360 ==> PTW = (90 * 2^30) / 360 = 30'd268435456 = 30'h10000000
        avalon_write({OP_PTW, 30'h10000000});


        // Wait in simulation while the hardware countdown executes the pulse 
        // At 150 MHz, 500 cycles is ~3.33 us
        #4000;  // 4 us

        // 4. Execute a Delay (Duration = 300 clock cycles, bit 32 = 0)
        avalon_write({OP_DELAY, 30'h12C});

        // wait for delay to complete
        #3000;

        // End Simulation
        $stop;
    end

endmodule