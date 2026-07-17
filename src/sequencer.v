// ==========================================================================================================================================================
// Module Name: sequencer
// Description: This module is the brains of the instruction set decomposition. This module is a FSM that splices the incoming data 'q' into 2 pieces. The 
//              first is a 2-bit opcode called 'tag' which tells the FSM what type of data to expect. The other 30 bits are the raw data which contain either
//              a ftw, ptw, or timer (in clock cycles) value. The sequencer is tied to the asynchronous FIFO and output multiplexer.  
// ==========================================================================================================================================================
`timescale 1ns / 1ps
module sequencer(
    input wire clk_150mhz,  // 150 MHz clock coming from the DDS output (PLL block)
    input wire rst,         // on-board master reset
    input wire rdempty,     // tells if the async FIFO block is empty
    input wire [31:0] q,    // raw data from the async FIFO module
    input wire run_enable,  // input from 'avs_addr' to start FSM
    output reg rdreq,       // acknowledges q to be sent (FIFO is in show-ahead mode)
    output reg [29:0] ftw,  // output ftw value directed into the NCO
    output reg [29:0] ptw,  // output ptw value directed into the NCO
    output reg phase_rst,   // output trigger to reset phase before pulse on NCO
    output reg trigger,     // output trigger on external board to sync up oscilloscope
    output reg pulse        // enable to pulse NCO to GPIO output pins
    );

    // ========================================================
    // Moore Finite State Machine (FSM)
    // ========================================================

    // TODO: update FSM and logic to include macros
    // PERF: ^ (finished)
    // FSM encoding
    localparam IDLE          = 2'b00;       // FSM stands still until software pulls 'run_enable' high
    localparam START_TRIGGER = 2'b01;       // pulls an external wire high presummably hooked up to an o-scope for probing
    localparam DECODE        = 2'b10;       // decodes word into a ftw, ptw, pulse, or delay
    localparam COUNTDOWN     = 2'b11;       // counts down the pulse or delay data

    // Instruction Opcodes
    localparam OP_FTW   = 2'b00;
    localparam OP_PTW   = 2'b01;
    localparam OP_PULSE = 2'b10;
    localparam OP_DELAY = 2'b11;
    
    // data slicing ==> 32-bit input == 2-bit tag OPCODE || 30-bit data
    wire [1:0] tag = q[31:30];
    wire [29:0] data = q[29:0];

    // Internal register
    reg [1:0] state;
    reg [29:0] timer;

    // Sequential Logic
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            // reset all states and safely mute the RF pulse
            state <= IDLE;
            rdreq <= 1'b0;
            ftw <= 30'd0;
            ptw <= 30'd0;
            timer <= 30'd0;
            phase_rst <= 1'b0;
            trigger <= 1'b0;
            pulse <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    state <= IDLE;
                    rdreq <= 1'b0;
                    phase_rst <= 1'b0;
                    trigger <= 1'b0;
                    if (~rdempty && run_enable) begin
                        state <= START_TRIGGER;
                    end
                end

                START_TRIGGER: begin
                    rdreq <= 1'b0;
                    phase_rst <= 1'b0;
                    trigger <= 1'b1;
                    state <= DECODE;
                end

                DECODE: begin
                    trigger <= 1'b0;
                    // acknowledge word consumption
                    if (~rdempty) begin
                        rdreq <= 1'b1;
                    end
                    // Decode OPCODES
                    case(tag)
                        OP_FTW: begin
                            ftw <= data;
                            phase_rst <= 1'b0;
                            pulse <= 1'b0;
                            if (~rdempty) begin
                                state <= DECODE;
                            end else begin
                                state <= IDLE;
                            end
                        end

                        OP_PTW: begin
                            ptw <= data;
                            phase_rst <= 1'b0;
                            pulse <= 1'b0;
                            if (~rdempty) begin
                                state <= DECODE;
                            end else begin
                                state <= IDLE;
                            end
                        end

                        OP_PULSE: begin
                            timer <= data;
                            phase_rst <= 1'b1;
                            pulse <= 1'b1;
                            state <= COUNTDOWN;
                        end

                        OP_DELAY: begin
                            timer <= data;
                            phase_rst <= 1'b1;
                            pulse <= 1'b0;
                            state <= COUNTDOWN;
                        end
                    endcase
                end

                COUNTDOWN: begin
                    rdreq <= 1'b0;
                    phase_rst <= 1'b0;
                    trigger <= 1'b0;
                    if (timer >= 30'd1) begin
                        timer <= timer - 30'd1;
                        state <= COUNTDOWN;
                    end else begin
                        if (~rdempty) begin
                            state <= DECODE;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end 
            endcase
        end
    end
endmodule