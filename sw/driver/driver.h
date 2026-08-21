#ifndef DRIVER_H
#define DRIVER_H

#include <stdint.h>
#include <stddef.h>

// ============================================================================
// INTEL SOC MEMORY MAP CONFIGURATION
// ============================================================================
// LW HPS2FPGA AXI Bridge Address
#define HW_REGS_BASE        0xFF200000
// Offset for pulse_programmer_0
#define PULSE_PROG_BASE     0x00000000
// Combined absolute base addr for mmap()
#define TARGET_BASE_ADDR    (HW_REGS_BASE + PULSE_PROG_BASE)
// Memory span
#define TARGET_SPAN         0x4000
// 32-bit word offsets
#define REG_DATA_OFFSET     0x400   // word 0 (byte offset 0x00) --> BRAM input
#define REG_START_OFFSET    0x401   // word 1 (byte offset 0x04) --> Start trigger

#define START_VAL           1       // write 32'd1 to trigger hardware

// ============================================================================
// FUNCTION DECLARATIONS
// ============================================================================
int fpga_init(void);
void fpga_cleanup(void);
int fpga_load_bram(const uint32_t *data, size_t word_count);
void fpga_start(void);

#endif // DRIVER_H