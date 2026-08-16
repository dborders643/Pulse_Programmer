// ==========================================================================================================================================================
// Module Name: sequencer
// Description: This module is the brains of the instruction set decomposition. This module is a FSM that splices the incoming data 'q' into 2 pieces. The 
//              first is a 3-bit opcode called 'tag' which tells the FSM what type of data to expect. The other 29 bits are the raw data which contain either
//              a ftw, ptw, atw, etw, or timer (in clock cycles) value. The sequencer is tied to the asynchronous FIFO and output multiplexer.  
// ==========================================================================================================================================================
`timescale 1ns / 1ps

// TODO: make the rx_en do this:
// TODO: - software will send a 32-bit data signal with top 3 bits containing OP_RX
// TODO: - the other 29-bits == 1, which will route to rx_en (output for rf switch)
// TODO: - software will send this word and another holding the FSM in COUNTDOWN for the desired amount of time to receive

module sequencer(
    // TODO: add in new output to control rf switch 'rx_en' (receive enable)
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
    output wire trigger,    // output trigger on external board to sync up oscilloscope
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
    // TODO: add in new opcode for rx_en 'OP_RX'
    localparam OP_FTW   = 3'b000;           // tells sequencer to route 'data' to 'ftw' output
    localparam OP_PTW   = 3'b001;           // tells sequencer to route 'data' to 'ptw' output
    localparam OP_ATW   = 3'b010;           // tells sequencer to route 'data' to 'atw' output
    localparam OP_ETW   = 3'b011;           // tells sequencer to route 'data' to 'etw' output
    localparam OP_PULSE = 3'b100;           // tells sequencer to route 'data' to 'timer' and pull 'pulse' output high
    localparam OP_DELAY = 3'b101;           // tells sequencer to route 'data' to 'timer' output but not pull 'pulse' high
    
    // data slicing ==> 32-bit input == 3-bit tag OPCODE || 29-bit data
    wire [2:0] tag = q[31:29];              // slices top 3 bits of q to cleanly seperate OPCODES
    wire [28:0] data = q[28:0];             // slices bottom 29 bits of q to seperate raw data

    // Internal register
    reg [1:0] state;                        // internal register holding current state of sequencer
    reg [28:0] timer;                       // internal timer counting down # of clock cycles sent from 'data' 
    reg trigger_raw;                        // raw trigger instantiated by 'START_TRIGGER' state
    reg [2:0] trigger_sr;                   // shift register to OR with raw to hold trigger output for 4 clock cycles

    // Sequential Logic
    //TODO: when rx_en == 1 : rf switch will change pipeline so coil -> switch -> LNA -> O-Scope, otherwise stay in transmit mode
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            // reset all states and safely mute the RF pulse
            state <= IDLE;
            rdreq <= 1'b0;
            ftw <= 29'd0;
            ptw <= 29'd0;
            atw <= 29'd0;
            etw <= 29'd0;
            timer <= 29'd0;
            carrier_rst <= 1'b0;
            env_en <= 1'b0;
            trigger_raw <= 1'b0;
            pulse <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    state <= IDLE;
                    rdreq <= 1'b0;
                    carrier_rst <= 1'b0;
                    trigger_raw <= 1'b0;
                    pulse <= 1'b0;
                    if (~rdempty & run_enable) begin
                        state <= START_TRIGGER;
                    end
                end

                START_TRIGGER: begin
                    rdreq <= 1'b1;
                    carrier_rst <= 1'b0;
                    trigger_raw <= 1'b1;
                    state <= DECODE;
                end

                DECODE: begin
                    trigger_raw <= 1'b0;
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
                                carrier_rst <= 1'b1;
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
                    trigger_raw <= 1'b0;
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

    // Cascade trigger signals together 
    always @(posedge clk_150mhz or posedge rst) begin
        if (rst) begin
            trigger_sr <= 3'b0;
        end else begin
            trigger_sr <= {trigger_sr[1:0], trigger_raw};
        end
    end

    // OR logic to output to 'trigger'
    assign trigger = trigger_raw | (|trigger_sr);

endmodule