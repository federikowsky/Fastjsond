# fastjsond Benchmarks

Comprehensive benchmark suite comparing:

- **std.json** - D standard library JSON parser
- **fastjsond.std** - fastjsond compatibility layer (drop-in std.json replacement)
- **fastjsond native** - Zero-copy, maximum performance API

## Running Benchmarks

```bash
cd benchmarks
make run             # Basic tests + edge cases
make run-heavy       # + MB payload tests (1MB to 100MB)
make run-extreme     # + GB payload tests (500MB to 5GB)
make run-errors      # Error handling benchmarks
make run-all         # Everything
```

Or use the benchmark binary directly:
```bash
../build/benchmark              # Basic tests
../build/benchmark --heavy      # + Heavy tests
../build/benchmark --extreme    # + Extreme tests  
../build/benchmark --errors     # + Error tests
../build/benchmark --all        # All tests
```

## Benchmark Categories

### Basic Tests
| Test | Payload | Description |
|------|---------|-------------|
| Tiny JSON | 2 B | Minimal `{}` |
| Simple JSON | 45 B | Small object with few fields |
| Medium JSON | 200 B | Nested object |
| Complex JSON | 331 B | API response with arrays |
| Very Complex | 3.6 KB | E-commerce order payload |

### Edge Cases
- Empty structures, Unicode-heavy, Escape-heavy
- Whitespace-heavy, Number edge cases
- Long strings (1KB), Deep nesting (30 levels)
- Wide objects (200 fields), Sparse arrays

### Iteration Patterns
- Array iteration, Object iteration
- Random access, Sequential access, Mixed access

### Realistic Payloads
- Twitter-like, GitHub-like, E-commerce order
- GeoJSON, Log entries, Config files

### Stress Tests
- 1K records, 10K records
- Large arrays (10K, 50K numbers)

### Heavy Tests (MB Payloads)
- 1 MB, 5 MB, 10 MB, 50 MB, 100 MB

### Extreme Tests (GB Payloads)
- 500 MB, 1 GB, 2 GB, 5 GB

### Error Handling Tests
- Invalid syntax, Truncated JSON
- Unterminated strings, Invalid numbers
- Trailing content, Control characters
- Invalid escapes, Invalid Unicode

## Results

### Basic Tests (MacBook Pro M4)

| Benchmark | std.json | fastjsond.std | fastjsond native | Speedup |
|-----------|----------|---------------|------------------|---------|
| Simple (45B) | 114 MB/s | 144 MB/s | 682 MB/s | 6.0x |
| Medium (200B) | 133 MB/s | 203 MB/s | 1,955 MB/s | 14.6x |
| Complex (331B) | 135 MB/s | 201 MB/s | 2,036 MB/s | 15.1x |
| Very Complex (3.6KB) | 222 MB/s | 477 MB/s | 4,006 MB/s | 18.1x |

### Heavy Tests (MB Payloads)

| Payload | std.json | fastjsond.std | fastjsond native | Speedup |
|---------|----------|---------------|------------------|---------|
| 1 MB | 8.45 ms (118 MB/s) | 5.03 ms (199 MB/s) | 0.59 ms (1,694 MB/s) | **14.3x** |
| 5 MB | 45.82 ms (109 MB/s) | 27.50 ms (182 MB/s) | 3.07 ms (1,630 MB/s) | **14.9x** |
| 10 MB | 82.22 ms (122 MB/s) | 53.15 ms (188 MB/s) | 6.83 ms (1,463 MB/s) | **12.0x** |
| 50 MB | 458.06 ms (109 MB/s) | 277.29 ms (180 MB/s) | 37.32 ms (1,340 MB/s) | **12.3x** |
| 100 MB | 818.66 ms (122 MB/s) | 664.31 ms (151 MB/s) | 126.49 ms (791 MB/s) | **6.5x** |

### Extreme Tests (GB Payloads)

| Payload | std.json | fastjsond native | Speedup |
|---------|----------|------------------|---------|
| 500 MB | 9.0 sec (56 MB/s) | 1.05 sec (476 MB/s) | **8.6x** |
| 1 GB | ~18 sec | ~2 sec | ~9x |

### Error Handling Performance

fastjsond detects errors **93-210x faster** than std.json:

| Error Type | std.json | fastjsond native | Speedup |
|------------|----------|------------------|---------|
| Invalid JSON Syntax | 0.75 ms | 0.008 ms | **93x** |
| Truncated JSON | 0.72 ms | 0.005 ms | **144x** |
| Unterminated Strings | 0.80 ms | 0.005 ms | **160x** |
| Invalid Escapes | 0.86 ms | 0.004 ms | **210x** |
| Invalid Numbers | 0.76 ms | 0.005 ms | **152x** |

Note: std.json doesn't detect trailing content errors (false positives).

## Why fastjsond is Faster

1. **SIMD Parsing** - simdjson processes 64 bytes at a time using AVX2/NEON
2. **Zero-Copy Strings** - Native API returns slices into original buffer
3. **Reusable Parser** - Internal buffers are reused across parses
4. **Lazy Parsing** - Values are decoded on-demand
5. **Cache-Friendly** - Memory layout optimized for CPU caches

## Notes

- First run may include JIT compilation overhead
- Results vary based on CPU architecture (AVX2, ARM NEON)
- Memory pressure affects large payload tests
- GB tests require 16GB+ RAM
- `fastjsond.std` copies data for std.json compatibility
