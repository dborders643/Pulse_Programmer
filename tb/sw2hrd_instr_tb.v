// ============================================================================
// Module Name: platform_interface_tb.v
// Description: Tests if rf pulse works using ISA opcodes
// ============================================================================
`timescale 1ns / 1ps

module sw2hrd_instr_tb();

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

        // instructions
        avalon_write_FIFO(32'h40000300);
        avalon_write_FIFO(32'h01111111);
        avalon_write_FIFO(32'h28000000);
        avalon_write_FIFO(32'h60123456);
        avalon_write_FIFO(32'h800001C1);
        avalon_write_FIFO(32'hA000001D);
        avalon_write_FIFO(32'h40000400);
        avalon_write_FIFO(32'h02222222);
        avalon_write_FIFO(32'h60369D03);
        avalon_write_FIFO(32'h80000095);

        // start experiment
        avalon_write_control(32'd1); 

        // wait for experiment to complete
        #15000;

        // End Simulation
        $stop;
    end

endmodule