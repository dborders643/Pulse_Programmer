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

    def _get_words(self, sequence):
        """Internal helper method to compile sequence commands into 32-bit words."""
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

        return compiled_words

    def compile(self, sequence, output_filename="sequence.bin"):
        """Takes a Sequence instance and compiles it to binary"""
        compiled_words = self._get_words(sequence)

        # --- WRITE TO BINARY FILE ---
        with open(output_filename, "wb") as f:
            for word in compiled_words:
                f.write(struct.pack("<I", word))

        print(f"Success! Compiled {len(compiled_words)} instructions to {output_filename}")
        return compiled_words

    def print_debug(self, sequence):
        """Prints a human-readable bit breakdown of each instruction."""
        op_names = {0: 'FREQ ', 1: 'PHS  ', 2: 'PULSE', 3: 'DELAY'}
        
        # Get compiled 32-bit words cleanly
        compiled_words = self._get_words(sequence)

        print("\n" + "="*76)
        print(f"{'IDX':<3} | {'TYPE':<5} | {'OP(31:30)':<9} | {'VALUE BITS (29:0)':<37} | {'RAW HEX'}")
        print("="*76)

        for i, word in enumerate(compiled_words):
            opcode = (word >> 30) & 0x3
            val = word & 0x3FFF_FFFF
            
            # Format bits
            op_bin  = f"{opcode:02b}"
            val_bin = f"{val:030b}"
            
            # Group 30-bit value into clean 4-bit nibbles for visual
            val_formatted = f"{val_bin[:2]} {val_bin[2:6]} {val_bin[6:10]} {val_bin[10:14]} {val_bin[14:18]} {val_bin[18:22]} {val_bin[22:26]} {val_bin[26:]}"

            print(f"#{i:<2} | {op_names[opcode]} | {op_bin:<9} | {val_formatted:<33} | 0x{word:08X}")
            
        print("="*76 + "\n")