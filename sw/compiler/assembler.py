# Imports
import struct
from pulse_lib import Sequence

# Helper Functions
def freq2ftw(freq: float):
    """Converts desired frequency to designated ftw value for 32-bit hardware"""
    N = 30              # 30 bits designated to ftw value
    f_ref_clk = 150.0   # 150 MHz -> remember incoming frequency is in MHz
    ftw = (freq * 2**N) / f_ref_clk
    return ftw

def phase2ptw(phase_deg: float):
    """Converts desired phase into a raw ptw value for 32-bit hardware"""
    M = 30
    ptw = (phase_deg * 2**M) / 360.0
    return ptw

class Compiler:
    def __init__(self, clk_mhz=150):
        self.clk_mhz = clk_mhz
        self.ns_per_cycle = 1000 / clk_mhz

        # Verilog Opcodes --> fit in bits 31:30
        self.OP_FTW   = 0x0 # 2'b00
        self.OP_PTW   = 0x1 # 2'b01
        self.OP_PULSE = 0x2 # 2'b10
        self.OP_DELAY = 0x3 # 2'b11

    def compile(self, sequence, output_filename="sequence.bin"):
        """Takes a Sequence instance and compiles it to binary."""
        compiled_words = []
        op_mask = 0x3
        val_mask = 0x3FFF_FFFF  # 30-bit mask (bits 29:0)
        # Read the .commands list inside the Sequence object
        for cmd in sequence.commands:
            cmd_type = cmd['type']

            if cmd_type == 'FREQ':
                opcode = self.OP_FTW
                val = int(freq2ftw(cmd['freq_mhz'])) & val_mask

            elif cmd_type == 'PHS':
                opcode = self.OP_PTW
                val = int(phase2ptw(cmd['phase_deg'])) & val_mask

            elif cmd_type == 'PULSE':
                opcode = self.OP_PULSE
                val = int(cmd['duration_ns'] / self.ns_per_cycle) & val_mask

            elif cmd_type == 'DELAY':
                opcode = self.OP_DELAY
                val = int(cmd['duration_ns'] / self.ns_per_cycle) & val_mask

            else:
                continue

            # --- BIT PACKING ---
            # [2-bit OPCODE (31:30)] | [30-bit value (29:0)]
            word32 = ((opcode & op_mask) << 30) | (val & val_mask)
            compiled_words.append(word32)

        # --- WRITE TO BINARY FILE ---
        with open(output_filename, "wb") as f:
            for word in compiled_words:
                f.write(struct.pack("<I", word))

        print(f"Success! Compiled {len(compiled_words)} instructions to {output_filename}")
        return compiled_words