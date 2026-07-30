// ==========================================================================================================================================================
// Module Name: sequencer
// Description: This module is the brains of the instruction set decomposition. This module is a FSM that splices the incoming data 'q' into 2 pieces. The 
//              first is a 3-bit opcode called 'tag' which tells the FSM what type of data to expect. The other 29 bits are the raw data which contain either
//              a ftw, ptw, atw, etw, or timer (in clock cycles) value. The sequencer is tied to the asynchronous FIFO and output multiplexer.  
// ==========================================================================================================================================================
`timescale 1ns / 1ps
module sequencer(
    input wire clk_150mhz,  // 150 MHz clock coming from the DDS output (PLL block)
    input wire rst,         // on-board master reset
    input wire rdempty,     // tells if the async FIFO block is empty
    input wire run_enable,  // input from 'avs_addr' to start FSM
    input wire [31:0] q,    // raw data from the async FIFO module
    output reg rdreq,       // acknowledges q to be sent (FIFO is in show-ahead mode)
    output reg [28:0] ftw,  // output ftw value directed into the NCO
    output reg [28:0] ptw,  // output ptw value directed into the NCO
    output reg [28:0] atw,  // output atw value directed into the NCO
    output reg [28:0] etw,  // output etw value directed into the NCO
    output reg carrier_rst, // enable to start accumulator countdown
    output reg env_en,      // enable envelope to start counting
    output reg trigger,     // output trigger on external board to sync up oscilloscope
    output reg pulse        // enable to pulse NCO to GPIO output pins
    );

    // ========================================================
    // Moore Finite State Machine (FSM)
    // ========================================================

    // FSM encoding
    localparam IDLE          = 2'b00;       // FSM stands still until software pulls 'run_enable' high
    localparam START_TRIGGER = 2'b01;       // pulls an external wire high presummably hooked up to an o-scope for probing
    localparam DECODE        = 2'b10;       // decodes word into a ftw, ptw, pulse, or delay
    localparam COUNTDOWN     = 2'b11;       // counts down the pulse or delay data

    // Instruction Opcodes
    localparam OP_FTW   = 3'b000;
    localparam OP_PTW   = 3'b001;
    localparam OP_ATW   = 3'b010;
    localparam OP_ETW   = 3'b011;
    localparam OP_PULSE = 3'b100;
    localparam OP_DELAY = 3'b101;
    
    // data slicing ==> 32-bit input == 3-bit tag OPCODE || 29-bit data
    wire [2:0] tag = q[31:29];
    wire [28:0] data = q[28:0];

    // Internal register
    reg [1:0] state;
    reg [28:0] timer;

    // Sequential Logic
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            // reset all states and safely mute the RF pulse
            state <= IDLE;
            rdreq <= 1'b0;
            ftw <= 29'd0;
            ptw <= 29'd0;
            atw <= 29'b0;
            timer <= 29'd0;
            carrier_rst <= 1'b0;
            env_en <= 1'b0;
            trigger <= 1'b0;
            pulse <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    state <= IDLE;
                    rdreq <= 1'b0;
                    carrier_rst <= 1'b0;
                    trigger <= 1'b0;
                    pulse <= 1'b0;
                    if (~rdempty & run_enable) begin
                        state <= START_TRIGGER;
                    end
                end

                START_TRIGGER: begin
                    rdreq <= 1'b1;
                    carrier_rst <= 1'b0;
                    trigger <= 1'b1;
                    state <= DECODE;
                end

                DECODE: begin
                    trigger <= 1'b0;
                    carrier_rst <= 1'b1;
                    if (rdreq & ~rdempty) begin
                        case(tag)

                            OP_FTW: begin
                                ftw <= data;
                                pulse <= 1'b0;
                                if (~rdempty) begin
                                    state <= DECODE;
                                    rdreq <= 1'b1;
                                end else begin
                                    state <= IDLE;
                                end
                            end

                            OP_PTW: begin
                                ptw <= data;
                                pulse <= 1'b0;
                                if (~rdempty) begin
                                    state <= DECODE;
                                    rdreq <= 1'b1;
                                end else begin
                                    state <= IDLE;
                                end
                            end

                            OP_ATW: begin
                                atw <= data;
                                pulse <= 1'b0;
                                if (~rdempty) begin
                                    state <= DECODE;
                                    rdreq <= 1'b1;
                                end else begin
                                    state <= IDLE;
                                end
                            end

                            OP_ETW: begin
                                etw <= data;
                                pulse <= 1'b0;
                                if (~rdempty) begin
                                    state <= DECODE;
                                    rdreq <= 1'b1;
                                end else begin
                                    state <= IDLE;
                                end
                            end

                            OP_PULSE: begin
                                timer <= data;
                                pulse <= 1'b1;
                                rdreq <= 1'b0;
                                env_en <= 1'b1; 
                                state <= COUNTDOWN;
                            end

                            OP_DELAY: begin
                                timer <= data;
                                pulse <= 1'b0;
                                rdreq <= 1'b0;
                                state <= COUNTDOWN;
                            end
                        endcase
                    end else begin
                        state <= IDLE;
                    end
                end

                COUNTDOWN: begin
                    rdreq <= 1'b0;
                    carrier_rst <= 1'b0;
                    trigger <= 1'b0;
                    if (timer >= 29'd1) begin
                        timer <= timer - 29'd1;
                        state <= COUNTDOWN;
                    end else begin
                        env_en <= 1'b0;
                        pulse <= 1'b0;
                        if (~rdempty) begin
                            state <= DECODE;
                            rdreq <= 1'b1;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end 
            endcase
        end
    end
endmodule