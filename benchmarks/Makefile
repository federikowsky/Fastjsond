# fastjsond Benchmark Makefile

DC       := ldc2
BUILD    := ../build
LIB      := $(BUILD)/libfastjsond.a
SRC      := ../source

DFLAGS   := -O3 -release -I$(SRC)

.PHONY: all run run-heavy run-extreme run-errors run-all clean quick profile help

all: $(BUILD)/benchmark

help:
	@echo ""
	@echo "  make run          - Run basic benchmarks"
	@echo "  make run-heavy    - Run with MB payload tests"
	@echo "  make run-extreme  - Run with GB payload tests"
	@echo "  make run-errors   - Run error handling benchmarks"
	@echo "  make run-all      - Run all benchmarks"
	@echo "  make quick        - Quick build (less optimized)"
	@echo "  make clean        - Remove build artifacts"
	@echo ""

# Build and run benchmarks
run: $(BUILD)/benchmark
	@$(BUILD)/benchmark

run-heavy: $(BUILD)/benchmark
	@$(BUILD)/benchmark --heavy

run-extreme: $(BUILD)/benchmark
	@$(BUILD)/benchmark --extreme

run-errors: $(BUILD)/benchmark
	@$(BUILD)/benchmark --errors

run-all: $(BUILD)/benchmark
	@$(BUILD)/benchmark --all

$(BUILD)/benchmark: benchmark.d $(LIB)
	@echo "Building benchmark..."
	@$(DC) $(DFLAGS) benchmark.d $(LIB) -L-lc++ -of=$@

# Ensure library is built
$(LIB):
	@echo "Building library first..."
	@cd .. && make lib

clean:
	@rm -f $(BUILD)/benchmark $(BUILD)/benchmark_quick $(BUILD)/benchmark_profile
	@echo "Clean complete"

# Quick run with less optimization for faster compile
quick:
	@echo "Quick benchmark (less optimized)..."
	@$(DC) -O -I$(SRC) benchmark.d $(LIB) -L-lc++ -of=$(BUILD)/benchmark_quick
	@$(BUILD)/benchmark_quick

# Profile run
profile:
	@echo "Building with profiling..."
	@$(DC) $(DFLAGS) -profile benchmark.d $(LIB) -L-lc++ -of=$(BUILD)/benchmark_profile
	@$(BUILD)/benchmark_profile
