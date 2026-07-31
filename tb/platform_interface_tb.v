// ============================================================================
// Module Name: platform_interface_tb.v
// Description: Tests if rf pulse works using ISA opcodes
// ============================================================================
`timescale 1ns / 1ps

module platform_interface_tb();

    // testbench stimulus signals
    reg clk_50mhz;
    reg rst;
    reg [31:0] avs_write_data;
    reg avs_write;
    reg [11:0] avs_addr;
    // output
    wire trigger;
    wire clk_150mhz;
    wire [9:0] db;
    wire [9:0] debug_env;
    wire [9:0] debug_car;

    // opcodes defined
    localparam OP_FTW   = 3'b000;
    localparam OP_PTW   = 3'b001;
    localparam OP_ATW   = 3'b010;
    localparam OP_ETW   = 3'b011;
    localparam OP_PULSE = 3'b100;
    localparam OP_DELAY = 3'b101;

    // instantiate top-level module (platform_interface.v)
    platform_interface inst (
        .clk_50mhz      (clk_50mhz),
        .rst            (rst),
        .avs_write_data (avs_write_data),
        .avs_write      (avs_write),
        .avs_addr       (avs_addr),
        .clk_150mhz     (clk_150mhz),
        .trigger        (trigger),
        .debug_env      (debug_env),
        .debug_car      (debug_car),
        .db             (db)
    );

    // 50 MHz clock generation (20 ns period)
    always begin
        #10 clk_50mhz = ~clk_50mhz;
    end

    // Helper Task to mimic FIFO write
    task avalon_write_FIFO;
        input [31:0] data;
        begin
            @(posedge clk_50mhz);
            avs_addr = 12'h400;      // address 1024 = FIFO
            avs_write_data = data;
            avs_write = 1'b1;
            @(posedge clk_50mhz);
            avs_write = 1'b0;
            avs_write_data = 32'd0;
        end
    endtask

    // Helper Task to mimic starting experiment
    task avalon_write_control;
        input [31:0] control;
        begin
            @(posedge clk_50mhz);
            avs_addr = 12'h401;      // address 1025 = run_enable (control)
            avs_write_data = control;
            avs_write = 1'b1;
            @(posedge clk_50mhz);
            avs_write = 1'b0;
            avs_addr = 12'h0;
            avs_write_data = 32'd0;
        end
    endtask

    // Helper Task to mimic a RAM write
    task avalon_write_RAM;
        input [9:0] addr;
        input [9:0] data;
        begin
            @(posedge clk_50mhz);
            avs_addr = {2'd0, addr};
            avs_write_data = {22'd0, data};
            avs_write = 1'b1;
            @(posedge clk_50mhz);
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
        avs_addr = 12'd0;

        // System Reset
        #40;
        rst = 1'b1;
        #40;
        rst = 1'b0;
        #100;       // wait for PLL sim block to stabilize and lock

        // 1. Set Amplitude of Wave
        avalon_write_FIFO({OP_ATW, 29'h3FF}); // 100%

        // 2. Configure Frequency (FTW)
        // passing in 1 MHz desired f_out --> FTW = f_out * 2^N/f_ref_clk ==> FTW = 1e6*2^30 / 150e6 = 30'd7158279 = 30'h6D3A07
        avalon_write_FIFO({OP_FTW, 29'h369D03});

        // 3. Load RF Pulse (Duration = 500 clock cycles) (ETW generates before PULSE)
        avalon_write_FIFO({OP_ETW, 29'h010624E});
        avalon_write_FIFO({OP_PULSE, 29'h1F4});

        // 4. Load Delay (Duration = 300 clock cycles, bit 32 = 0)
        avalon_write_FIFO({OP_DELAY, 29'h12C});
        
        // 5. Reconfigure Frequency (FTW)
        avalon_write_FIFO({OP_FTW, 29'hDA740E});

        // 6. Configure Phase Offset  (PTW)
        // passing in 90 degree desired phase_deg --> PTW = (phase_deg * 2^N) / 360 ==> PTW = (90 * 2^30) / 360 = 30'd268435456 = 30'h10000000
        avalon_write_FIFO({OP_PTW, 29'h8000000});

        // 7. Change Amplitude to 30%
        avalon_write_FIFO({OP_ATW, 29'h133});

        // 8. Pulse one more time
        avalon_write_FIFO({OP_ETW, 29'h010624E});
        avalon_write_FIFO({OP_PULSE, 29'h1F4});

        // 8. Start Experiment
        avalon_write_control(32'd1); 

        // wait for experiment to complete
        #15000;

        // End Simulation
        $stop;
    end

endmodule