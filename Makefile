# ============================================================================
# fastjsond - High-Performance JSON Parser for D
# ============================================================================

# Compiler Configuration
DC       := ldc2
CXX      := clang++
AR       := ar

# Directories
BUILD_DIR    := build
SRC_DIR      := source
TEST_DIR     := tests
C_SRC_DIR    := $(SRC_DIR)/fastjsond/c

# Output
LIB_NAME     := libfastjsond.a
LIB_OUT      := $(BUILD_DIR)/$(LIB_NAME)

# Compiler Flags
DFLAGS       := -O3 -I$(SRC_DIR)
DFLAGS_DEBUG := -g -I$(SRC_DIR)
DFLAGS_LIB   := $(DFLAGS) -lib -oq

# C++ Flags for simdjson
CXXFLAGS     := -O3 -std=c++17 -DNDEBUG
CXXFLAGS     += -fPIC
# Enable all SIMD optimizations
CXXFLAGS     += -march=native

# Architecture-specific flags
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
    # Apple Silicon
    CXXFLAGS += -DSIMDJSON_IMPLEMENTATION_ARM64=1
else ifeq ($(UNAME_M),x86_64)
    # Intel/AMD
    CXXFLAGS += -mavx2 -mbmi -mpclmul
endif

# Source Files
D_SOURCES   := $(shell find $(SRC_DIR) -name '*.d' ! -path '*/c/*')
CPP_SOURCES := $(wildcard $(C_SRC_DIR)/*.cpp)
CPP_OBJECTS := $(patsubst $(C_SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(CPP_SOURCES))

# Test files (auto-discovered)
TEST_SOURCES := $(wildcard $(TEST_DIR)/*.d)
TEST_TARGETS := $(patsubst $(TEST_DIR)/%.d,$(BUILD_DIR)/%,$(TEST_SOURCES))

# ============================================================================
# Phony Targets
# ============================================================================

.PHONY: all clean lib test bench help info

# Default Target
all: lib

# Help
help:
	@echo ""
	@echo "fastjsond - High-Performance JSON Parser for D"
	@echo ""
	@echo "Build Targets:"
	@echo "  make all          - Build library (default)"
	@echo "  make lib          - Build static library"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make rebuild      - Clean and rebuild"
	@echo ""
	@echo "Test Targets:"
	@echo "  make test         - Run native API tests (30 tests)"
	@echo "  make test-std     - Run std API tests (36 tests)"
	@echo "  make test-all     - Run all tests (66 tests)"
	@echo ""
	@echo "Benchmark Targets:"
	@echo "  make bench        - Run basic benchmarks"
	@echo "  make bench-heavy  - Run with MB payload tests"
	@echo "  make bench-extreme - Run with GB payload tests"
	@echo "  make bench-all    - Run all benchmarks"
	@echo ""
	@echo "  make info         - Show build configuration"
	@echo ""
	@echo "Build directory: $(BUILD_DIR)/"
	@echo "Library output:  $(LIB_OUT)"

# ============================================================================
# Build Rules
# ============================================================================

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Compile simdjson (C++)
$(BUILD_DIR)/simdjson.o: $(C_SRC_DIR)/simdjson.cpp | $(BUILD_DIR)
	@echo "[CXX] Compiling simdjson..."
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Pattern rule: compile any C++ source
$(BUILD_DIR)/%.o: $(C_SRC_DIR)/%.cpp | $(BUILD_DIR)
	@echo "[CXX] Compiling $*..."
	@$(CXX) $(CXXFLAGS) -I$(C_SRC_DIR) -c $< -o $@

# Compile D sources
$(BUILD_DIR)/fastjsond.o: $(D_SOURCES) | $(BUILD_DIR)
	@echo "[DC] Compiling D sources..."
	@$(DC) $(DFLAGS) -c $(D_SOURCES) -of=$@ -od=$(BUILD_DIR)

# Build static library
lib: $(LIB_OUT)

$(LIB_OUT): $(CPP_OBJECTS) $(BUILD_DIR)/fastjsond.o
	@echo "[AR] Creating library..."
	@$(AR) rcs $@ $^
	@echo "✓ Library built: $@"
	@echo "  Size: $$(du -h $@ | cut -f1)"

# ============================================================================
# Tests (Pattern Rule - builds any test automatically)
# ============================================================================

# Pattern rule: build any test from tests/*.d
$(BUILD_DIR)/%: $(TEST_DIR)/%.d $(LIB_OUT) | $(BUILD_DIR)
	@echo "[DC] Building $*..."
	@$(DC) $(DFLAGS) $< $(LIB_OUT) -L-lc++ -of=$@ -od=$(BUILD_DIR)
	@echo "✓ Built: $@"

# Run native API tests
test: $(BUILD_DIR)/native_test
	@echo ""
	@echo "Running Native API Tests..."
	@echo "============================"
	@$(BUILD_DIR)/native_test

# Run std API tests  
test-std: $(BUILD_DIR)/std_test
	@echo ""
	@echo "Running Std API Tests..."
	@echo "========================"
	@$(BUILD_DIR)/std_test

# Run all tests
test-all: $(BUILD_DIR)/native_test $(BUILD_DIR)/std_test
	@echo ""
	@echo "Running All Tests..."
	@echo "===================="
	@$(BUILD_DIR)/native_test
	@echo ""
	@$(BUILD_DIR)/std_test
	@echo ""
	@echo "✓ All 66 tests passed!"

# Build all tests
tests-build: $(TEST_TARGETS)
	@echo "✓ All tests built in $(BUILD_DIR)/"
	@echo "  Targets: $(notdir $(TEST_TARGETS))"

# Run benchmarks
bench: lib
	@cd benchmarks && make run

bench-heavy: lib
	@cd benchmarks && make run-heavy

bench-extreme: lib
	@cd benchmarks && make run-extreme

bench-all: lib
	@cd benchmarks && make run-all

# ============================================================================
# Utility Targets
# ============================================================================

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

# Show build info
info:
	@echo "Build Configuration"
	@echo "==================="
	@echo "D Compiler:    $(DC)"
	@echo "C++ Compiler:  $(CXX)"
	@echo "Architecture:  $(UNAME_M)"
	@echo "D Flags:       $(DFLAGS)"
	@echo "C++ Flags:     $(CXXFLAGS)"
	@echo ""
	@echo "Source Files"
	@echo "============"
	@echo "D Sources:     $(words $(D_SOURCES)) files"
	@echo "C++ Sources:   $(words $(CPP_SOURCES)) files"
	@echo ""
	@echo "Output"
	@echo "======"
	@echo "Library:       $(LIB_OUT)"

# Rebuild everything
rebuild: clean all
