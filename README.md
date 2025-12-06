# fastjsond

**High-Performance JSON Parser for D** - A wrapper around [simdjson](https://github.com/simdjson/simdjson), the world's fastest JSON parser.

[![Build Status](https://img.shields.io/badge/tests-66%20passing-brightgreen)](tests/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- 🚀 **10-20x faster** than `std.json` on typical workloads
- 🎯 **Zero-copy native API** - strings point directly into source buffer
- 🔄 **Drop-in replacement** - `fastjsond.std` is compatible with `std.json`
- 🛡️ **SIMD accelerated** - uses AVX2/NEON for maximum throughput
- 📦 **No GC allocations** in native API hot paths

## Quick Start

```d
// Drop-in replacement for std.json
import fastjsond.std;

auto json = parseJSON(`{"name": "Aurora", "version": 2}`);
string name = json["name"].str;
long ver = json["version"].integer;
```

```d
// Native zero-copy API for maximum performance
import fastjsond;

auto parser = Parser();
auto doc = parser.parse(`{"name": "Aurora", "version": 2}`);

// Zero-copy - getString returns a slice into the original buffer
const(char)[] name = doc.root["name"].getString;
long ver = doc.root["version"].getInt;

// Copy only when you need to keep the string
string nameCopy = name.idup;
```

## Installation

### Using Make (Recommended)

```bash
git clone https://github.com/federikowsky/fastjsond.git
cd fastjsond
make lib      # Build static library
make test     # Run tests (66 tests)
make bench    # Run benchmarks
```

### Using DUB

```bash
dub build
```

## API Overview

### Native API (`fastjsond`)

Zero-copy, maximum performance. Strings are borrowed references valid only while Document exists.

```d
import fastjsond;

auto parser = Parser();  // Reuse for efficiency
auto doc = parser.parse(jsonString);

if (!doc.valid) {
    writeln("Error: ", doc.errorMessage);
    return;
}

auto root = doc.root;

// Type checking
if (root["field"].isString) { ... }
if (root["field"].isNumber) { ... }

// Value extraction (throws on type mismatch)
long n = root["count"].getInt;
double d = root["price"].getDouble;
bool b = root["active"].getBool;
const(char)[] s = root["name"].getString;  // Zero-copy!

// Safe extraction with Result
if (auto result = root["optional"].tryInt) {
    writeln("Value: ", result.value);
}

// Iteration
foreach (item; root["items"]) {
    writeln(item["name"].getString);
}

foreach (key, val; root["config"]) {
    writeln(key, " = ", val);
}
```

### Std API (`fastjsond.std`)

Drop-in replacement for `std.json`. Copies all data for safety.

```d
import fastjsond.std;

// Identical to std.json
auto json = parseJSON(`{"name": "test", "values": [1, 2, 3]}`);
string name = json["name"].str;

foreach (val; json["values"].array) {
    writeln(val.integer);
}

// Serialization
string output = toJSON(json);
string pretty = toPrettyJSON(json);
```

## Benchmark Results

Tested on Apple M4, parsing various JSON payloads:

| Payload Size | std.json | fastjsond.std | fastjsond native | Speedup |
|--------------|----------|---------------|------------------|---------|
| 45 B | 114 MB/s | 144 MB/s | 682 MB/s | **6x** |
| 200 B | 133 MB/s | 203 MB/s | 1,955 MB/s | **14.6x** |
| 3.6 KB | 222 MB/s | 477 MB/s | 4,006 MB/s | **18x** |
| 1 MB | 118 MB/s | 199 MB/s | 1,694 MB/s | **14.3x** |
| 100 MB | 122 MB/s | 151 MB/s | 791 MB/s | **6.5x** |
| 500 MB | 56 MB/s | 57 MB/s | 476 MB/s | **8.6x** |

### Error Detection Speed

fastjsond is **93-210x faster** at detecting invalid JSON:

| Error Type | std.json | fastjsond native | Speedup |
|------------|----------|------------------|---------|
| Invalid syntax | 0.75 ms | 0.008 ms | **93x** |
| Truncated JSON | 0.72 ms | 0.005 ms | **144x** |
| Invalid escapes | 0.86 ms | 0.004 ms | **210x** |

Run benchmarks:
```bash
cd benchmarks
make run           # Basic + edge cases
make run-heavy     # + MB payloads
make run-extreme   # + GB payloads
make run-errors    # Error handling tests
```

## Project Structure

```
fastjsond/
├── source/fastjsond/
│   ├── package.d       # Public exports
│   ├── parser.d        # Parser implementation
│   ├── document.d      # Document type
│   ├── value.d         # Value type (zero-copy)
│   ├── types.d         # JsonType, JsonError enums
│   ├── bindings.d      # D → C bindings
│   ├── std.d           # std.json compatibility layer
│   └── c/
│       ├── api.cpp     # C API wrapper
│       ├── api.h       # C API header
│       ├── simdjson.cpp # simdjson (amalgamated)
│       └── simdjson.h
├── tests/
│   ├── native_test.d   # Native API tests (30 tests)
│   └── std_test.d      # Std API tests (36 tests)
├── benchmarks/
│   ├── benchmark.d     # Comprehensive benchmark suite
│   ├── Makefile
│   └── README.md
├── docs/
│   └── specs.md        # Full API specification
├── Makefile
├── dub.json
└── README.md
```

## Requirements

- **D Compiler**: LDC2 (recommended) or DMD
- **C++ Compiler**: Clang++ or G++ with C++17 support
- **Architecture**: x86-64 (AVX2) or ARM64 (NEON)

## Safety Notes

### Zero-Copy Lifetime

Native API strings are **borrowed references**. They become invalid when the Document is destroyed:

```d
// ⚠️ DANGER: Dangling pointer
const(char)[] getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString;  // Points into doc's buffer
}  // doc destroyed here!

// ✅ SAFE: Copy the string
string getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString.idup;  // Copied to GC heap
}

// ✅ SAFE: Use std API (auto-copies)
import fastjsond.std;
JSONValue json = parseJSON(`{"name": "test"}`);  // All strings copied
```

## License

MIT License - see [LICENSE](LICENSE) file.

## Acknowledgments

- [simdjson](https://github.com/simdjson/simdjson) - The amazing C++ JSON parser this wraps