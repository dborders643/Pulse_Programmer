# Custom FPGA Pulse Programmer & Direct Digital Synthesizer (DDS)

This repository contains the Verilog HDL source code and companion C/Python software stack for a custom FPGA-based Pulse Programmer and Direct Digital Synthesizer (DDS). The system is designed to receive high-level instructions from a Hard Processor System (HPS) via a lightweight AXI bus, decode them in real-time, and generate phase-coherent, precisely timed RF pulses.

---

## Repository Structure

```text
.
├── sw/                         # Software Stack
│   ├── compiler/               # Python Assembly & DSL compiler
│   │   ├── pulse_lib.py        # High-level pulse sequence DSL
│   │   ├── assembler.py        # 32-bit binary encoder & instruction specs
│   │   └── test.py             # Test assembly scripts
│   ├── driver/                 # C Software Drivers & Hardware Abstraction Layer
│   │   ├── driver.h            # Memory-map, register offsets & function prototypes
│   │   ├── driver.c            # FPGA BRAM & control register drivers (Hardware/Mock)
│   │   └── runner.c            # CLI runner for binary sequence loading
│   └── bin/                    # Compiled binary outputs (git-ignored)
├── src/                        # Verilog HDL Hardware Source Files
├── tb/                         # Simulation Testbenches
├── output_files/               # Quartus Synthesis & Bitstream Output (.sof, .rbf)
└── Makefile                    # Unified build & test pipeline

```

---

## System Architecture

The architecture is divided into two primary execution domains: the **Control/Sequencing Domain** and the **RF/Synthesis Domain**. Cross-domain clocking is handled safely using an Asynchronous FIFO.

### 1. Top-Level Wrapper

* **`platform_interface.v`**: The physical top-level wrapper module. It connects the HPS demands to the sequencer via the lightweight AXI bus using an asynchronous FIFO in show-ahead mode. It handles clock routing by instantiating the PLL block for 150 MHz operation. Finally, it features an output multiplexer that routes either the active NCO output or a DC silence value (`10'h1FF`) to the external 10-bit DAC based on the sequencer's pulse flag.

### 2. The Sequencer Domain

* **`sequencer.v`**: The brains of the instruction set decomposition. This module utilizes a Moore Finite State Machine (FSM) to slice the incoming 32-bit data into a 2-bit opcode "tag" and a 30-bit payload. It decodes the payload into a frequency tuning word (ftw), phase tuning word (ptw), or timer countdown value. It acts as both the dispatcher and the pulse controller, counting down clock cycles for RF pulses and delays while generating external oscilloscope triggers and phase resets.

### 3. The Direct Digital Synthesis (DDS) Domain

* **`nco.v`**: The Numerically Controlled Oscillator that acts as a wrapper for the phase accumulator and sine Phase-to-Amplitude Converter (PAC). It injects the Phase Tuning Word (PTW) to offset the accumulated phase for real-time phase modulation.
* **`phase_accumulator.v`**: A register that steps forward by the Frequency Tuning Word (FTW) on every 150 MHz clock cycle. It features a synchronous `phase_rst` input from the sequencer to zero out the phase for precise multi-pulse alignment.
* **`sine_pac.v`**: The Sine Phase-to-Amplitude Converter (PAC). It truncates the 30-bit phase index into a 10-bit address (`lut_idx[29:20]`) and polls a precalculated lookup table memory block to output the proper 10-bit DAC value.

---

## Instruction Set Architecture (ISA)

The sequencer interprets 32-bit instruction packets directly.

* **Bits [31:30]:** Opcode Tag
* **Bits [29:0]:** Payload Data

| Opcode | Binary | Name | Description |
| --- | --- | --- | --- |
| `0x0` | `2'b00` | `OP_FTW` | Updates the Frequency Tuning Word (FTW) |
| `0x1` | `2'b01` | `OP_PTW` | Updates the Phase Tuning Word (PTW) |
| `0x2` | `2'b10` | `OP_PULSE` | Pulls RF gate high (`pulse = 1`), resets phase, and counts down duration (ns) |
| `0x3` | `2'b11` | `OP_DELAY` | Pulls RF gate low (`pulse = 0`), resets phase, and counts down duration (ns) |

---

## Software & Toolchain Workflow

The project includes a full software toolchain for generating, compiling, and loading sequence files onto the hardware.

### Python Assembler DSL

Python scripts inside `sw/compiler/` allow defining high-level pulse sequences in human-readable terms (MHz, degrees, nanoseconds) and compiling them to exact 32-bit `sequence.bin` binary payloads.

```python
from pulse_lib import Sequence
from assembler import Compiler

# Initialize Sequence and Compiler
seq = Sequence()
comp = Compiler()

# Define Pulse Instructions
seq.set_freq(1.0)       # 1.0 MHz
seq.set_phs_off(90)     # 90 degrees offset
seq.pulse(500)          # 500 ns pulse
seq.delay(200)          # 200 ns delay
seq.pulse(1000)         # 1000 ns pulse

# Compile & Debug Output
comp.compile(seq, output_filename="sw/bin/sequence.bin")
comp.print_debug(seq)
```

### Build & Automation Commands (`Makefile`)

The root `Makefile` automates both local testing on host x86 PCs (using mock FPGA abstraction) and ARM target compilation for the Intel Cyclone V SoC environment.

* **Run complete mock pipeline test:**
```bash
make test
```


*(Compiles Python sequence, builds local x86 runner, and validates binary loading in mock virtual memory).*
* **Compile for real physical ARM FPGA Board:**
```bash
make arm
```


*(Generates `sw/bin/runner` using the `arm-none-linux-gnueabihf-gcc` cross-compiler).*
* **Clean generated binaries & build trees:**
```bash
make clean
```

---

## Prerequisites & Setup

### Hardware & FPGA Tools

* Intel Quartus Prime (SoC / Cyclone V)
* Precalculated hexadecimal sine lookup table named `sine_lut.hex` (1024 rows x 10-bit width, centered at `10'h1FF` for DC 0).

### Required FPGA IP Blocks

1. **PLL (`pll_150mhz`)**: 50 MHz input reference clock -> 150 MHz system clock (`outclk_0`) + `locked` signal.
2. **Asynchronous FIFO (`async_FIFO`)**: 32-bit wide dual-clock FIFO for HPS-to-FPGA domain crossing.

### Software Toolchain

* Python 3.x (with standard libraries)
* GCC (for local x86 mock execution)
* Intel SoC EDS / `arm-none-linux-gnueabihf-gcc` cross-compiler toolchain

---

## Block Diagrams & State Machines

Below are the schematics and behavioral diagrams mapping the current FPGA architecture:

### Platform Interface Block Diagram
<div align="center">
  <img src="images/platform_interface.png" alt="Platform Interface Schematic">
</div>

### Sequencer State Diagram
<div align="center">
  <img src="images/sequencer_state_diagram.png" alt="Sequencer FSM">
</div>

### Numerically Controlled Oscillator Block Diagram
<div align="center">
  <img src="images/nco.png" alt="NCO Schematic">
</div>

### Phase Accumulator Block Diagram
<div align="center">
  <img src="images/phase_accumulator.png" alt="Phase Accumulator Schematic">
</div>

### Sine Phase-to-Amplitude Converter Block Diagram
<div align="center">
  <img src="images/sine_pac.png" alt="Sine PAC Schematic">
</div>