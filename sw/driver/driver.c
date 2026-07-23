#include <stdio.h>
#include <stdlib.h>
#include "driver.h"

// ============================================================================
// TOGGLE THIS: Set to 1 to test on PC, Set to 0 for Real FPGA Board
// ============================================================================
#define MOCK_FPGA 1 

#if MOCK_FPGA
    // --- MOCK PC TESTING MODE ---
    static uint32_t mock_fpga_memory[2]; // Fake 8-byte memory space
    static volatile uint32_t *fpga_ptr = mock_fpga_memory;

    int fpga_init(void) {
        printf("[MOCK] Virtual FPGA memory initialized.\n");
        return 0;
    }

    void fpga_cleanup(void) {
        printf("[MOCK] Virtual FPGA memory cleaned up.\n");
    }

    int fpga_load_bram(const uint32_t *data, size_t word_count) {
        if (!fpga_ptr) return -1;
        
        printf("[MOCK] Streaming %zu words into virtual BRAM (FIFO)...\n", word_count);
        for (size_t i = 0; i < word_count; i++) {
            fpga_ptr[REG_DATA_OFFSET] = data[i];
            // Print what would have been written to hardware
            printf("       -> BRAM Input [Word %zu]: 0x%08X\n", i, data[i]);
        }
        return 0;
    }

    void fpga_start(void) {
        if (!fpga_ptr) return;
        fpga_ptr[REG_START_OFFSET] = START_VAL;
        printf("[MOCK] Hardware trigger bit set to: %d\n", fpga_ptr[REG_START_OFFSET]);
    }

#else
    // --- REAL HARDWARE MODE ---
    #include <fcntl.h>
    #include <sys/mman.h>
    #include <unistd.h>

    static int dev_mem_fd = -1;
    static volatile uint32_t *fpga_ptr = NULL;

    int fpga_init(void) {
        dev_mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
        if (dev_mem_fd < 0) {
            perror("[ERROR] Failed to open /dev/mem");
            return -1;
        }
        fpga_ptr = (volatile uint32_t *)mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, dev_mem_fd, TARGET_BASE_ADDR);
        if (fpga_ptr == MAP_FAILED) {
            perror("[ERROR] mmap failed");
            close(dev_mem_fd);
            dev_mem_fd = -1;
            return -1;
        }
        return 0;
    }

    void fpga_cleanup(void) {
        if (fpga_ptr != NULL && fpga_ptr != MAP_FAILED) {
            munmap((void *)fpga_ptr, 4096);
            fpga_ptr = NULL;
        }
        if (dev_mem_fd >= 0) {
            close(dev_mem_fd);
            dev_mem_fd = -1;
        }
    }

    int fpga_load_bram(const uint32_t *data, size_t word_count) {
        if (!fpga_ptr) return -1;
        for (size_t i=0; i<word_count; i++) {
            fpga_ptr[REG_DATA_OFFSET] = data[i];
        }
        return 0;
    }

    void fpga_start(void) {
        if (!fpga_ptr) return;
        fpga_ptr[REG_START_OFFSET] = START_VAL;
    }
#endif