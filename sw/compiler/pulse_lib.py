class Sequence:
    """
    Main sequence builder. Tracks user commands and formats them into hardware instructions for the FPGA.
    """

    def __init__(self):
        self.commands = []      # initialize an empty set of strings

    def set_freq(self, freq):
        """Set a frequency to your pulse(s) (freq in MHz)"""

    def set_phs_off(self, offset):
        """Set a phase offset (offset in degrees)"""

    def pulse(self, duration):
        """Add a pulse command (duraiton in ns)"""

    def delay(self, duration):
        """Add a delay command (duration in ns)"""

    def start(self):
        """Specific command to wake up hardware and start pulsing"""