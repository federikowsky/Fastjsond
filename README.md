# fastjsond

High-performance JSON parser for D.

Built on [simdjson](https://github.com/simdjson/simdjson), the SIMD-accelerated JSON parser.

[![DUB](https://img.shields.io/dub/v/fastjsond)](https://code.dlang.org/packages/fastjsond)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![D](https://img.shields.io/badge/D-2.105%2B-red.svg)](https://dlang.org/)

## Overview

fastjsond provides two APIs:

- **Native API**: Zero-copy parsing with maximum performance
- **std.json-compatible API**: Drop-in replacement with faster execution

SIMD instruction sets (AVX2, SSE4.2, NEON) are auto-detected at runtime.

## Installation

Add to your `dub.json`:

```json
"dependencies": {
    "fastjsond": "~>1.0.0"
}
```

Or with `dub.sdl`:

```sdl
dependency "fastjsond" version="~>1.0.0"
```

### Building from Source

```bash
git clone https://github.com/federikowsky/fastjsond.git
cd fastjsond
make lib    # Build static library
make test   # Run tests
```

## Quick Start

### Drop-in Replacement for std.json

```d
import fastjsond.std;  // Change import from std.json

auto json = parseJSON(`{"name": "Aurora", "version": 2}`);
string name = json["name"].str;
long ver = json["version"].integer;
```

### Native Zero-Copy API

```d
import fastjsond;

auto parser = Parser.create();
auto doc = parser.parse(`{
    "name": "Aurora",
    "version": 2,
    "features": ["fast", "safe"]
}`);

if (!doc.valid) {
    writeln("Error: ", doc.errorMessage);
    return;
}

// Zero-copy: getString returns slice into original buffer
const(char)[] name = doc.root["name"].getString;
long ver = doc.root["version"].getInt;

// Iteration
foreach (feature; doc.root["features"]) {
    writeln(feature.getString);
}
```

## API Reference

### Native API (`fastjsond`)

**Parser**

```d
auto parser = Parser.create();  // Reusable parser instance
auto doc = parser.parse(jsonString);
auto doc = parser.parsePadded(paddedBuffer);  // Pre-padded input
```

**Document**

```d
if (doc.valid) {
    auto root = doc.root;
}
string err = doc.errorMessage;
```

**Value**

```d
// Type access
bool   b = value.getBool();
long   n = value.getInt();
ulong  u = value.getUint();
double d = value.getDouble();
const(char)[] s = value.getString();  // Zero-copy

// Safe extraction
if (auto result = value.tryInt()) {
    writeln("Value: ", result.value);
}

// Navigation
auto field = root["key"];        // Object field
auto item = root["items"][0];    // Array element

// Iteration
foreach (item; root["array"]) { }
foreach (key, val; root["object"]) { }
```

### std.json-Compatible API (`fastjsond.std`)

```d
import fastjsond.std;

auto json = parseJSON(jsonString);
string name = json["name"].str;
long count = json["count"].integer;
double price = json["price"].floating;

if (auto ptr = "optional" in json) {
    writeln(ptr.str);
}
```

### Module Functions

```d
import fastjsond;

bool ok = validate(jsonString);              // Validate without parsing
size_t padding = requiredPadding();          // Get padding requirement
string impl = activeImplementation();        // "haswell", "arm64", etc.
```

## Performance

Benchmarked on Apple M1:

| Payload | std.json | fastjsond | Speedup |
|---------|----------|-----------|---------|
| 1 MB | 8.45 ms | 0.59 ms | 14x |
| 10 MB | 82 ms | 6.8 ms | 12x |
| 100 MB | 818 ms | 126 ms | 6.5x |

Error detection:

| Error Type | std.json | fastjsond | Speedup |
|------------|----------|-----------|---------|
| Invalid syntax | 0.75 ms | 0.008 ms | 93x |
| Invalid escapes | 0.86 ms | 0.004 ms | 210x |

## String Lifetime

Native API strings are borrowed references into the original buffer:

```d
// Incorrect: reference invalid after doc goes out of scope
const(char)[] getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString;  // Dangling reference
}

// Correct: copy the string
string getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString.idup;
}

// Alternative: use std API (auto-copies)
import fastjsond.std;
string getName() {
    auto json = parseJSON(`{"name": "test"}`);
    return json["name"].str;
}
```

## Building

### Requirements

- **D Compiler**: LDC 1.35+ (recommended) or DMD 2.105+
- **C++ Compiler**: clang++ or g++ (C++17)

### Make Targets

| Target | Description |
|--------|-------------|
| `make lib` | Build `libfastjsond.a` |
| `make test` | Run all tests |
| `make bench` | Run benchmarks |
| `make clean` | Clean artifacts |

## Documentation

- [Technical Specifications](docs/specs.md) — Complete API reference
- [simdjson](https://github.com/simdjson/simdjson) — Underlying parser

## Contributing

Contributions are welcome. Please ensure:

1. Tests pass (`make test`)
2. Benchmarks do not regress
3. Code follows D style guidelines

## License

MIT License — see [LICENSE](LICENSE) for details.
