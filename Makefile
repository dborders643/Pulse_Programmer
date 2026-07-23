# ============================================================================
# TOOLCHAINS & TARGETS
# ============================================================================
# Cross-compiler for the physical ARM FPGA board
CC_ARM := arm-none-linux-gnueabihf-gcc
TARGET_ARM := runner

# Native compiler for your local Windows PC (via SoC EDS Shell)
CC_PC := gcc
TARGET_MOCK := local_runner

# Source files
SRCS := driver.c runner.c
INCLUDES := -I.

# ============================================================================
# MAKE RULES
# ============================================================================
# Default command if you just type 'make'
all: arm

# 1. Compile for the Real FPGA Board (ARM)
arm:
	$(CC_ARM) $(SRCS) $(INCLUDES) -o $(TARGET_ARM)
	@echo "Success: Built '$(TARGET_ARM)' for ARM hardware."

# 2. Compile for Local PC Testing (Mock)
mock:
	$(CC_PC) $(SRCS) $(INCLUDES) -o $(TARGET_MOCK)
	@echo "Success: Built '$(TARGET_MOCK)' for local PC testing."

# 3. Generate the sequence.bin using your Python assembler
sequence:
	python test.py

# 4. Automate the entire Local Test Pipeline
test: sequence mock
	@echo "\n--- RUNNING MOCK TEST ---"
	./$(TARGET_MOCK) sequence.bin

# 5. Clean up all generated files
clean:
	rm -f $(TARGET_ARM) $(TARGET_MOCK) sequence.bin test_run.bin
	@echo "Cleaned up all compiled binaries."