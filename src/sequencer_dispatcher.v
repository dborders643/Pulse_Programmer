// ==========================================================================================================================================================
// Module Name: sequencer_dispatcher
// Description: This module is the brains of the instruction set decomposition. Every instruction sent from the HPS to the aysnc FIFO to the pulse sequencer
//              is a 2-word 32-bit value (2 32-bit values). A FSM is used to step through the interpretation of each word. The first word contains the OPCODE
//              which tells the state machine what type of information is coming in the next word. The second word then contains the raw data of either the
//              ftw, pulse duration, phase offset, etc. 
// ==========================================================================================================================================================
`timescale 1ns / 1ps
module sequencer_dispatcher(
    input wire clk_150mhz,          // 150 MHz clock coming from the DDS output (PLL block)
    input wire rst,                 // on-board master reset
    input wire [31:0] q,            // raw data from the async FIFO module
    input wire rdempty,             // tells if the async FIFO block is empty
    input wire timer_busy,          // tells dispatcher if pulse controller is already counting down
    output reg rdreq,               // lets the async FIFO block know the sequencer wants to read 
    output reg [31:0] ftw,          // output ftw value directed into the DDS core
    output reg [31:0] ptw,          // output ptw value directed into the DDS core
    output reg [31:0] timer_data,   // pulse duration raw data into pulse controller
    output reg timer_start          // bit to trigger the pulse controller
    );

    // ========================================================
    // Moore Finite State Machine (FSM)
    // ========================================================

    // FSM encoding
    localparam IDLE          = 3'd0;
    localparam FETCH_OPCODE  = 3'd1;
    localparam DECODE_OPCODE = 3'd2;
    localparam UPDATE_FTW    = 3'd3;
    localparam UPDATE_PTW    = 3'd4;
    localparam UPDATE_TIMER  = 3'd5;

    // Instruction Opcodes (word 1)
    localparam OP_SET_FTW = 32'h0000_0001;  // prepares dispatcher to send raw packet to ftw register
    localparam OP_SET_PTW = 32'h0000_0002;  // prepares dispatcher to send raw packet to ptw register
    localparam OP_TIMER   = 32'h0000_0003;  // prepares dispatcher to send raw packet to timer register

    // Internal register
    reg [2:0] state;

    // Sequential Logic
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            // reset all states and safely mute the RF pulse
            state <= IDLE;
            rdreq <= 1'b0;
            timer_start <= 1'b0;
            ftw <= 32'd0;
            ptw <= 32'd0;
            timer_data <= 32'd0;
        end else begin
            // pulse trigger must only be high for one cycle
            timer_start <= 1'b0;

            // States Defined
            case(state)
                IDLE: begin
                    rdreq <= 1'b0;
                    state <= IDLE;
                    if (~rdempty && ~timer_busy) begin
                        rdreq <= 1'b1;          // pull rdreq high to ask FIFO for data
                        state <= FETCH_OPCODE; 
                    end
                end 

                // we need FETCH_OPCODE because the sequencer dispatcher can only take in the one word we want
                // so 'rdreq' must pull high then pull low immediately out of the IDLE state
                FETCH_OPCODE: begin
                    rdreq <= 1'b0;
                    state <= DECODE_OPCODE;
                end

                DECODE_OPCODE: begin 
                    if (q == OP_SET_FTW) begin
                        rdreq <= 1'b1;          // ask FIFO for FTW payload
                        state <= UPDATE_FTW;
                    end else if (q == OP_SET_PTW) begin
                        rdreq <= 1'b1;          // ask FIFO for PTW payload
                        state <= UPDATE_PTW;
                    end else if (q == OP_TIMER) begin
                        rdreq <= 1'b1;          // ask FIFO for Timer payload
                        state <= UPDATE_TIMER;
                    end else begin
                        state <= IDLE;          // unknown opcode, abort                        
                    end
                end

                UPDATE_FTW: begin
                    rdreq <= 1'b0;              // only grab the single word we want
                    ftw <= q;                   // assign raw packet to ftw bus
                    state <= IDLE;              // go back to start
                end

                UPDATE_PTW: begin 
                    rdreq <= 1'b0;
                    ptw <= q;                   // assign payload to ptw bus
                    state <= IDLE;
                end

                UPDATE_TIMER: begin
                    rdreq <= 1'b0;
                    timer_data <= q;
                    timer_start <= 1'b1;        // trigger pulse controller
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
