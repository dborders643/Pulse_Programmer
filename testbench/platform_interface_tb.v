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
    localparam OPCODE_SET_FTW = 32'h0000_0001;
    localparam OPCODE_SET_PTW = 32'h0000_0002;
    localparam OPCODE_TIMER = 32'h0000_0003;

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
            // write to data reg
            @(posedge clk_50mhz);
            avs_write_data = data;
            avs_write = 1'b1;
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
        // passing in 1 MHz desired f_out --> FTW = f_out * 2^N/f_ref_clk ==> FTW = 1e6*2^32 / 150e6 = 32'd28633115 = 32'h01B4_E61B
        avalon_write(OPCODE_SET_FTW);
        avalon_write(32'h01B4_E61B);
        #100;

        // 3. Execute an RF Pulse (Duration = 500 clock cycles, bit 32 = 1)
        // instruction word 1: opcode
        avalon_write(OPCODE_TIMER);
        // instruction word 2: payload (bit 32 is 1 for db output enable, lower bits define count)
        avalon_write(32'h8000_01F4);

        // Wait in simulation while the hardware countdown executes the pulse 
        // At 150 MHz, 500 cycles is ~3.33 us
        #4000;

        // 4. Execute a Delay (Duration = 300 clock cycles, bit 32 = 0)
        avalon_write(OPCODE_TIMER);
        avalon_write(32'h0000_012C);

        // wait for delay to complete
        #3000;

        // try reset
        rst = 1'b1;
        #100;

        // End Simulation
        $stop;
    end

endmodule