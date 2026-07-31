class Sequence:
    """
    Main sequence builder. Tracks user commands and formats them into hardware instructions for the FPGA.
    """

    def __init__(self):
        self.commands = []                  # initialize an empty set of strings named 'commands'

    def set_freq(self, freq: float):
        """Set a frequency to your pulse(s) (freq in MHz)"""
        self.commands.append({
            'type': 'FREQ',
            'freq_mhz': freq
        })

    def set_phs_off(self, offset: float):
        """Set a phase offset (offset in degrees)"""
        self.commands.append({
            'type': 'PHS',
            'phase_deg': offset
        })

    def set_amp(self, amp: float):
        """Set the amplitude of your wave. Range is [0,1]"""
        self.commands.append({
            'type': 'AMP',
            'ampl': amp
        })

    def pulse(self, duration: float):
        """Add a pulse command (duration in ns)"""
        self.commands.append({
            'type': 'PULSE',
            'duration_ns': duration
        })

    def delay(self, duration: float):
        """Add a delay command (duration in ns)"""
        self.commands.append({
            'type': 'DELAY',
            'duration_ns': duration
        })