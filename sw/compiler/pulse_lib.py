class Sequence:
    """
    Main sequence builder. Tracks user commands and formats them into hardware instructions for the FPGA.
    """

    # TODO: Going to have to rework sturcture so that software supports follwing functionality:
    # TODO: - Able to compute optimal flip angle and/or quantum gate operation (requested by user in script) using provided power amplification and pulse duration
    # TODO:   (see rf_amp_calc.py and technical note for theory and calculation, in NMR_Spectrometer directory).
    # TODO: - Able to switch between transmit (Tx) and receieve (Rx) mode based off user command.
    # TODO: - Include scripting for 'Inversion Recovery', 'CPMG', 'Hahn Echo', and 'Free Induction Decay' pulse sequences for popular quantum cdontrol experiments
    # TODO:   and to find T_1, T_2, and T_2* times for specific setup.
    # TODO: - software will send this word and another holding the FSM in COUNTDOWN for the desired amount of time to receive

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