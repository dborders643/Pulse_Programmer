#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include "driver.h"

static int dev_mem_fd = -1;
static volatile uint32_t *fpga_ptr = NULL;

int fpga_init(void) {
    dev_mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (dev_mem_fd < 0) {
        perror("[ERROR] Failed to open /dev/mem (Did you run with sudo/root?)");
        return -1;
    }

    // Map physical FPGA address space into virtual memory pointer 
    fpga_ptr = (volatile uint32_t *)mmap(
        NULL,
        4096,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        dev_mem_fd,
        TARGET_BASE_ADDR
    );

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
    if (!fpga_ptr) {
        fprintf(stderr, "[ERROR] FPGA driver not initialized\n");
        return -1;
    }

    // write sequence words sequentially into the BRAM input port
    for (size_t i=0; i<word_count; i++) {
        fpga_ptr[REG_DATA_OFFSET] = data[i];
    }

    return 0;
}

void fpga_start(void) {
    if (!fpga_ptr) return;

    // pulse the start trigger register to initialize hardware execution
    fpga_ptr[REG_START_OFFSET] = START_VAL;
}