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
    reg [31:0] avs_addr;
    // output
    wire trigger;
    wire clk_150mhz;
    wire [9:0] db;

    // opcodes defined
    localparam OP_FTW = 2'b00;
    localparam OP_PTW = 2'b01; 
    localparam OP_PULSE = 2'b10;
    localparam OP_DELAY = 2'b11;

    // instantiate top-level module (platform_interface.v)
    platform_interface inst (
        .clk_50mhz      (clk_50mhz),
        .rst            (rst),
        .avs_write_data (avs_write_data),
        .avs_write      (avs_write),
        .avs_addr       (avs_addr),
        .clk_150mhz     (clk_150mhz),
        .trigger        (trigger),
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
            avs_addr = 32'd0;
            avs_write_data = data;
            avs_write = 1'b1;
            @(posedge clk_50mhz);
            avs_write = 1'b0;
            avs_write_data = 32'd0;
        end
    endtask

    // Helper Task to mimic starting experiment
    task avalon_write_control;
        input reg control;
        begin
            @(posedge clk_50mhz);
            avs_addr = 32'd1;
            avs_write_data = {31'd0, control};
            avs_write = 1'b1;
            @(posedge clk_50mhz);
            avs_write = 1'b0;
            avs_addr = 32'd0;
            avs_write_data = 32'd0;
        end
    endtask


    // Simulation Process
    initial begin
        // initialize inputs
        clk_50mhz = 1'b0;
        rst = 1'b0;
        avs_write_data = 32'h0;
        avs_write = 1'b0;
        avs_addr = 32'd0;

        // 1. System Reset
        #40;
        rst = 1'b1;
        #40;
        rst = 1'b0;
        #100;       // wait for PLL sim block to stabilize and lock

        // 2. Configure Frequency (FTW)
        // passing in 1 MHz desired f_out --> FTW = f_out * 2^N/f_ref_clk ==> FTW = 1e6*2^30 / 150e6 = 30'd7158279 = 30'h6D3A07
        avalon_write_FIFO({OP_FTW, 30'h6D3A07});
        #200;

        // 3. Load RF Pulse (Duration = 500 clock cycles)
        avalon_write_FIFO({OP_PULSE, 30'h1F4});
        #200;

        // 4. Configure Phase Offset  (PTW)
        // passing in 90 degree desired phase_deg --> PTW = (phase_deg * 2^N) / 360 ==> PTW = (90 * 2^30) / 360 = 30'd268435456 = 30'h10000000
        // avalon_write({OP_PTW, 30'h10000000});


        // Wait in simulation while the hardware countdown executes the pulse 
        // At 150 MHz, 500 cycles is ~3.33 us
        //#4000;  // 4 us

        // 4. Load Delay (Duration = 300 clock cycles, bit 32 = 0)
        avalon_write_FIFO({OP_DELAY, 30'h12C});
        #200;
        
        // 5. Reconfigure Frequency (FTW)
        avalon_write_FIFO({OP_FTW,30'h4444444});
        #200;

        // 6. Pulse one more time
        avalon_write_FIFO({OP_PULSE, 30'h1F4});
        #200;

        // 7. Start Experiment
        avalon_write_control(32'd1); 

        // wait for experiment to complete
        #15000;

        // End Simulation
        $stop;
    end

endmodule