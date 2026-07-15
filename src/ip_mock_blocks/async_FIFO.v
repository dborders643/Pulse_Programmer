// ============================================================================
// Module Name:  pll_150mhz
// Description:  Asynchronous First-In-First-Out (FIFO) simulation block.
//               This module is NOT an emulation but rather a simulation to 
//               to mimic the Intel Quartus IP Catalog FIFO module for testbench
//               purposes.
// ============================================================================
`timescale 1ns / 1ps
module async_FIFO(
    input wire aclr,        // asynchrnous reset
    input wire [31:0] data, // packet input
    input wire rdclk,       // reading domain clock
    input wire rdreq,       // reading domain request
    input wire wrclk,       // writing domain clock
    input wire wrreq,       // writing domain request
    output reg [31:0] q,    // sychronzied packet output 
    output reg rdempty,     // tells if block is not receving packets
    output reg wrfull       // tells if block is full of data
    );

    // 16-word deep memory array for simulation (IP block is 4096 words deep)
    reg [31:0] mem [15:0];
    reg [3:0] wr_ptr, rd_ptr;
    reg [4:0] count;

    // Start simulation behavior
    initial begin
        wr_ptr = 0;
        rd_ptr = 0;
        count = 0;
        rdempty = 1;
        wrfull = 0;
    end

    // Write logic (50 MHz wrclk domain)
    always@(posedge wrclk or posedge aclr) begin
        if (aclr) begin
            wr_ptr <= 0;
        end else if (wrreq && !wrfull) begin
            mem[wr_ptr] <= data;        // push data into memory
            wr_ptr <= wr_ptr + 1;       // increment through writing memory
        end
    end

    // Read Logic (150 MHz rdclk domain)
    always@(posedge rdclk or posedge aclr) begin
        if (aclr) begin
            rd_ptr <= 0;
        end else if (rdreq && !rdempty) begin
            q <= mem[rd_ptr];           // link output data to memory
            rd_ptr <= rd_ptr + 1;       // increment through pulling synchronized data
        end 
    end

    // simple status flag helper (combines domains for simulation)
    always@(*) begin
        rdempty = (wr_ptr == rd_ptr);
        wrfull = (wr_ptr + 1'b1 == rd_ptr);
    end
endmodule