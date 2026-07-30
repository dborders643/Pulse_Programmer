# Imports
import struct
from pulse_lib import Sequence

# bit masks
op_mask = 0x7           # 3-bit mask
val_mask = 0x1FFF_FFFF  # 29-bit mask (bits 28:0)

# Helper Functions
def freq2ftw(freq: float):
    """Converts desired frequency to designated ftw value for 32-bit hardware."""
    N = 29              # 29 bits designated to ftw value
    f_ref_clk = 150.0   # 150 MHz -> remember incoming frequency is in MHz
    ftw = (freq * 2**N) / f_ref_clk
    return int(round(ftw))

def phase2ptw(phase_deg: float):
    """Converts desired phase into a raw ptw value for 32-bit hardware."""
    M = 29
    ptw = (phase_deg * 2**M) / 360.0
    return int(round(ptw))

def amp2atw(ampl: float):
    """Converts normalized amplitude [0,1.0] to a atw."""
    ampl = max(0.0, min(1.0, ampl)) # limits input to range [0,1]
    K = 10
    atw = ampl * (2**K - 1)
    return int(round(atw))

def dur2etw(duration: float, clk_mhz: float = 150.0):
    """Converts pulse duration input into a etw for gaussian envelope pulse shaping."""
    N = 29
    ns_per_cycle = 1000 / clk_mhz
    cycles = duration / ns_per_cycle

    if cycles <= 0:
        return 0
    etw = (2**N) / cycles
    return int(round(etw))

class Compiler:
    def __init__(self, clk_mhz=150):
        self.clk_mhz = clk_mhz
        self.ns_per_cycle = 1000 / clk_mhz

        # Verilog Opcodes --> fit in bits 31:29
        self.OP_FTW   = 0x0 # 3'b000
        self.OP_PTW   = 0x1 # 3'b001
        self.OP_ATW   = 0x2 # 3'b010
        self.OP_ETW   = 0x3 # 3'b011
        self.OP_PULSE = 0x4 # 3'b100
        self.OP_DELAY = 0x5 # 3'b101

    def _get_words(self, sequence):
        """Internal helper method to compile sequence commands into 32-bit words."""
        compiled_words = []
        # Read the .commands list inside the Sequence object
        for cmd in sequence.commands:
            cmd_type = cmd['type']

            # --- BIT PACKING ---
            # [3-bit OPCODE (31:29)] | [29-bit value (28:0)]

            if cmd_type == 'FREQ':
                opcode = self.OP_FTW
                val = freq2ftw(cmd['freq_mhz']) & val_mask
                word32 = ((opcode & op_mask) << 29) | val
                compiled_words.append(word32)

            elif cmd_type == 'PHS':
                opcode = self.OP_PTW
                val = phase2ptw(cmd['phase_deg']) & val_mask
                word32 = ((opcode & op_mask) << 29) | val
                compiled_words.append(word32)

            elif cmd_type == 'AMP':
                opcode = self.OP_ATW
                val = amp2atw(cmd['ampl']) & val_mask
                word32 = ((opcode & op_mask) << 29) | val
                compiled_words.append(word32)

            elif cmd_type == 'PULSE':
                # 1). Calculate & send etw instruction word
                etw_val = dur2etw(cmd['duration_ns'], self.clk_mhz) & val_mask
                word_etw = ((self.OP_ETW & op_mask) << 29) | etw_val
                compiled_words.append(word_etw)

                # 2). Calculate & send pulse instruction word
                pulse_val = int(cmd['duration_ns'] / self.ns_per_cycle) & val_mask
                word_pulse = ((self.OP_PULSE & op_mask) << 29) | pulse_val
                compiled_words.append(word_pulse)

            elif cmd_type == 'DELAY':
                opcode = self.OP_DELAY
                val = int(cmd['duration_ns'] / self.ns_per_cycle) & val_mask
                word32 = ((opcode & op_mask) << 29) | val
                compiled_words.append(word32)


            else:
                continue

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
        op_names = {0: 'FREQ ', 1: 'PHS  ', 2: 'AMP  ', 3: 'ENV  ', 4: 'PULSE', 5: 'DELAY'}
        
        # Get compiled 32-bit words cleanly
        compiled_words = self._get_words(sequence)

        print("\n" + "="*76)
        print(f"{'IDX':<3} | {'TYPE':<5} | {'OP(31:29)':<9} | {'VALUE BITS (28:0)':<36} | {'RAW HEX'}")
        print("="*76)

        for i, word in enumerate(compiled_words):
            opcode = (word >> 29) & op_mask
            val = word & val_mask
            
            # Format bits
            op_bin  = f"{opcode:03b}"
            val_bin = f"{val:029b}"
            
            # Group 29-bit value into clean 4-bit nibbles for visual
            val_formatted = f"{val_bin[:1]} {val_bin[1:5]} {val_bin[5:9]} {val_bin[9:13]} {val_bin[13:17]} {val_bin[17:21]} {val_bin[21:25]} {val_bin[25:]}"

            print(f"#{i:<2} | {op_names.get(opcode, 'UNK  ')} | {op_bin:<9} | {val_formatted:<33} | 0x{word:08X}")
            
        print("="*76 + "\n")