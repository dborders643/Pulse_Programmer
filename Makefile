# ============================================================================
# DIRECTORIES & TARGETS
# ============================================================================
BIN_DIR := sw/bin

# Executable Targets
TARGET_ARM := $(BIN_DIR)/runner
TARGET_MOCK := $(BIN_DIR)/local_runner
SEQUENCE_BIN := $(BIN_DIR)/sequence.bin

# Toolchains
CC_ARM := "C:/Program Files (x86)/Arm/GNU Toolchain mingw-w64-i686-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc.exe"
CC_PC  := gcc

# Source files
SRCS := sw/driver/driver.c sw/driver/runner.c
INCLUDES := -Isw/driver

# Compiler Flags
CFLAGS := -std=c99

# ============================================================================
# MAKE RULES
# ============================================================================
all: arm

# Helper rule to ensure the bin directory exists before building
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# 1. Compile for the Real FPGA Board (ARM)
arm: | $(BIN_DIR)
	$(CC_ARM) $(CFLAGS) $(SRCS) $(INCLUDES) -o $(TARGET_ARM)
	@echo "Success: Built '$(TARGET_ARM)' for ARM hardware."

# 2. Compile for Local PC Testing (Mock)
mock: | $(BIN_DIR)
	$(CC_PC) $(CFLAGS) $(SRCS) $(INCLUDES) -o $(TARGET_MOCK)
	@echo "Success: Built '$(TARGET_MOCK)' for local PC testing."

# 3. Generate sequence.bin and move it into sw/bin/
sequence: | $(BIN_DIR)
	python3 sw/compiler/test.py

# 4. Automate the entire Local Test Pipeline
test: sequence mock
	@echo "\n--- RUNNING MOCK TEST ---"
	./$(TARGET_MOCK) $(SEQUENCE_BIN)

# 5. Clean up all generated files
clean:
	rm -rf $(BIN_DIR) test_run.bin
	@echo "Cleaned up all compiled binaries and the output directory."