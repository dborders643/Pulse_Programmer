#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "driver.h"

int main(int argc, char *argv[]) {
    // 1. Check if the user passed the binary file as an argument
    if (argc != 2) {
        printf("Usage %s <sequence.bin>\n", argv[0]);
        return EXIT_FAILURE;
    }

    const char *filename = argv[1];

    // 2. Open the compiled binary file
    FILE *file = fopen(filename, "rb");
    if (!file) {
        perror("[ERROR] Could not open sequence file");
        return EXIT_FAILURE;
    }

    // 3. Determine the size of the file to allocate memory
    fseek(file, 0, SEEK_END);
    long filesize = ftell(file);
    rewind(file);

    // Each instruction is a 32-bit word (4 bytes, 8 nibbles)
    if (filesize % 4 != 0) {
        fprintf(stderr, "[ERROR] File size is not a multiple of 4 bytes\n");
        return EXIT_FAILURE;
    }

    size_t word_count = filesize/4;
    uint32_t *sequence_data = (uint32_t *)malloc(filesize);
    if (!sequence_data) {
        perror("[ERROR] Memory allocation failed");
        fclose(file);
        return EXIT_FAILURE;
    }

    // 4. Read the file into sequence_data array
    size_t read_count = fread(sequence_data, 4, word_count, file);
    fclose(file);

    if (read_count != word_count) {
        fprintf(stderr, "[ERROR] Failed to read all data from file\n");
        free(sequence_data);
        return EXIT_FAILURE;
    }

    printf("Loaded %zu words from %s\n", word_count, filename);

    // ========================================================================
    // FPGA HARDWARE EXECUTION
    // ========================================================================
    
    // Initialize memory mapping
    if (fpga_init() != 0) {
        free(sequence_data);
        return EXIT_FAILURE;
    }

    printf("Writing sequence to FPGA BRAM...\n");
    if (fpga_load_bram(sequence_data, word_count) != 0) {
        fpga_cleanup();
        free(sequence_data);
        return EXIT_FAILURE;
    }

    printf("Triggering sequence start...\n");
    fpga_start();

    printf("Sequence execution triggered successfully\n");

    // Clean up hardware mapping and free memory
    fpga_cleanup();
    free(sequence_data);

    return EXIT_SUCCESS;
}