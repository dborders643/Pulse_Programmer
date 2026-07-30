// ============================================================================
// Module Name: platform_interface
// Description: This module is a custom wrapper. The module does this:
//      1. Connects the HPS demands to the sequencer via the light-weight 
//         AXI bus using an asynchronous FIFO IP block (in show ahead mode).
//      2. Instantiates the PLL block for 150 MHz operation. 
//      3. Connects the sequencer outputs to the nco to generate the 
//         desired pulse.
//      4. Generates the multiplexer that outputs the data bits into the DAC. 
// ============================================================================
`timescale 1ns / 1ps
module platform_interface(
  input wire clk_50mhz,               // 50 MHz crystal oscillator
  input wire rst,                     // on-board reset
  input wire [31:0] avs_write_data,   // 32-bit avalon write data
  input wire avs_write,               // avalon write enable
  input wire [11:0] avs_addr,         // routes data into FIFO, control, and RAM
  output wire clk_150mhz,             // output 150 MHz clock for external DAC clock
  output wire trigger,                // output trigger for the oscilloscope to synchronize oscilloscope reading and RF pulses
  output wire signed [9:0] db         // 10-bit external DAC output 
  );

  // ========================================================
  // Internal Interconnect Wires
  // ========================================================

  // FIFO <==> Sequencer
  wire [31:0] q_bus;
  wire rdempty_flag;
  wire rdreq_sig;

  // Sequencer <==> NCO
  wire [28:0] ftw_bus;
  wire [28:0] ptw_bus;
  wire [28:0] atw_bus;
  wire [28:0] etw_bus;
  wire carrier_rst_flag;
  wire env_en_flag;

  // NCO <==> MUX
  wire signed [9:0] nco_db;

  // Sequencer --> MUX
  wire pulse_flag;

  // PLL <==> NCO
  wire locked;
  wire local_rst;

  // ========================================================
  // Memory Map & Address Decoding
  // ========================================================
  // Addresses 0x000 to 0x3FF (0 to 1023): Envelope RAM 
  // Address 0x400 (1024): Asynchronous FIFO
  // Address 0x401 (1025): Run Enable Register
  wire ram_wr_en    = (avs_addr < 12'h400) & avs_write;
  wire wrreq_in     = (avs_addr == 12'h400) & avs_write;
  wire run_en_write = (avs_addr == 12'h401) & avs_write;

  // RAM write addr takes lower bits of avs_addr & ram_data does the same
  wire [9:0] ram_wr_addr = avs_addr[9:0];
  wire [9:0] ram_data = avs_write_data[9:0];

  // Internal Registers
  reg run_enable;
  reg sync_1;
  reg sync_2;

  // define local_rst logic: locked needs to be inverted and OR'd with 'rst'
  assign local_rst = ~locked | rst;
  // Output MUX (If pulse is active, output sine wave. Otherwise, output silence)
  assign db = pulse_flag ? nco_db : 10'h000;

  // ========================================================
  // Run Enable Register & CDC Synchronizer
  // ========================================================
  // First stage: 50 MHz run_enable register
  always @(posedge clk_50mhz or posedge rst) begin
    if (rst) begin
      run_enable <= 1'b0;
    end else if (run_en_write) begin
      run_enable <= avs_write_data[0];
    end
  end

  // Second & Third stage: 150 MHz synchronizer pipeline
  always @(posedge clk_150mhz or posedge local_rst) begin
    if (local_rst) begin
      sync_1 <= 1'b0;
      sync_2 <= 1'b0;
    end else begin
      sync_1 <= run_enable;
      sync_2 <= sync_1;
    end
  end

  // ========================================================
  // Module Instantiations
  // ========================================================

  // instantiate Asynchronous FIFO
  async_FIFO u_async_FIFO (
    .aclr   (rst),
    .data   (avs_write_data),
    .rdclk  (clk_150mhz),
    .rdreq  (rdreq_sig),
    .wrclk  (clk_50mhz),
    .wrreq  (wrreq_in),
    .q      (q_bus),
    .rdempty(rdempty_flag),
    .wrfull ()                // we don't need this port
  );

  // instantiate Sequencer 
  sequencer u_sequencer (
    .clk_150mhz (clk_150mhz),
    .rst        (local_rst),
    .rdempty    (rdempty_flag),
    .q          (q_bus),
    .run_enable (sync_2),
    .rdreq      (rdreq_sig),
    .ftw        (ftw_bus),
    .ptw        (ptw_bus),
    .atw        (atw_bus),
    .etw        (etw_bus),
    .carrier_rst(carrier_rst_flag),
    .env_en     (env_en_flag),
    .trigger    (trigger),
    .pulse      (pulse_flag)
  );

  // instantiate IP Catalog PLL module
  pll_150mhz u_pll_150mhz (
    .refclk     (clk_50mhz),
    .rst        (rst),
    .outclk_0   (clk_150mhz),
    .locked     (locked)
  );  

  // instantiate the NCO module
  nco  u_nco (
    .clk_50mhz  (clk_50mhz),
    .clk_150mhz (clk_150mhz),
    .rst        (local_rst),
    .carrier_rst(carrier_rst_flag),
    .env_en     (env_en_flag),
    .wr_addr    (ram_wr_addr),
    .wr_data    (ram_data),
    .wr_en      (ram_wr_en),
    .ftw        (ftw_bus),
    .ptw        (ptw_bus),
    .atw        (atw_bus),
    .etw        (etw_bus),
    .db         (nco_db)
  );

  endmodule