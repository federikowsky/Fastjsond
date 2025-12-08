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

## Features

- ⚡ **High Performance**: 7-20x faster than `std.json` on typical workloads
- 🔒 **Zero-Copy**: Native API returns string slices directly into the JSON buffer
- 🔄 **Drop-in Replacement**: `fastjsond.std` is API-compatible with `std.json`
- 🛡️ **Type-Safe**: Strong typing with `JsonType`, `JsonError`, and `Result<T>` types
- 🧵 **Thread-Safe std API**: `JSONValue` is immutable and thread-safe after creation
- 📦 **No Dependencies**: Self-contained with embedded simdjson
- 🎯 **@nogc Support**: Native API works in `@nogc` contexts
- 🔍 **Comprehensive Error Handling**: Detailed error codes and exception support
- 🚀 **SIMD Optimized**: Auto-detects and uses best SIMD instructions available

## Installation

Add to your `dub.json`:

```json
"dependencies": {
    "fastjsond": "~>1.0.2"
}
```

Or with `dub.sdl`:

```sdl
dependency "fastjsond" version="~>1.0.2"
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

#### Parser

```d
// Create parser with default capacity (~4GB)
auto parser = Parser.create();

// Create parser with custom max capacity
auto parser = Parser(1024 * 1024);  // 1MB max

// Parse JSON (multiple overloads)
auto doc = parser.parse(jsonString);
auto doc = parser.parse(cast(const(char)[]) json);
auto doc = parser.parse(cast(const(ubyte)[]) json);

// Parse with pre-padded buffer (for maximum performance)
auto doc = parser.parsePadded(paddedBuffer);

// Check if parser is valid
if (parser.valid) { ... }
```

#### Document

```d
// Check if parsing succeeded
if (doc.valid) {
    auto root = doc.root;
}

// Get error information
if (!doc.valid) {
    JsonError err = doc.error;           // Error code
    string msg = doc.errorMessage;       // Human-readable message
}

// Access root value
auto root = doc.root;

// Convenience: direct indexing into root
auto name = doc["name"];        // If root is object
auto first = doc[0];            // If root is array
```

#### Value - Type Checking

```d
// Get JSON type
JsonType t = value.type();  // null_, bool_, int64, uint64, double_, string_, array, object

// Type checking methods
if (value.isNull()) { ... }
if (value.isBool()) { ... }
if (value.isInt()) { ... }
if (value.isUint()) { ... }
if (value.isDouble()) { ... }
if (value.isNumber()) { ... }  // int, uint, or double
if (value.isString()) { ... }
if (value.isArray()) { ... }
if (value.isObject()) { ... }
```

#### Value - Extraction

```d
// Throwing extraction (throws JsonException on error)
bool   b = value.getBool();
long   n = value.getInt();
ulong  u = value.getUint();
double d = value.getDouble();

// getString() returns null on error (can't throw in @nogc)
const(char)[] s = value.getString();  // Zero-copy, returns null on error
if (s is null) {
    // Handle error - use tryString() for proper error handling
}

// Safe extraction with Result<T> (no exceptions)
if (auto result = value.tryBool()) {
    bool b = result.value;
} else {
    JsonError err = result.error;
}

if (auto result = value.tryInt()) {
    long n = result.value;
}

if (auto result = value.tryString()) {
    const(char)[] s = result.value;  // Zero-copy
}

// Get value or default
long n = value.tryInt().valueOr(0);
const(char)[] s = value.tryString().valueOr("");
```

#### Value - Object Access

```d
// Get field by key (throws if not found)
auto field = root["key"];

// Check if field exists
if (root.hasKey("optional")) {
    auto opt = root["optional"];
}

// Get number of fields
size_t count = root.objectSize();

// Iteration
foreach (const(char)[] key, val; root) {
    writeln(key, ": ", val);
}
```

#### Value - Array Access

```d
// Get element by index (throws if out of bounds)
auto item = root["items"][0];

// Get array length
size_t len = root["items"].length;
// or
size_t len = root["items"].$;  // opDollar alias

// Iteration
foreach (item; root["items"]) {
    writeln(item);
}

// Iteration with index
foreach (size_t i, item; root["items"]) {
    writeln(i, ": ", item);
}
```

#### Value - Utilities

```d
// Convert to string (for debugging)
string str = value.toString();  // Returns JSON-like representation
```

### std.json-Compatible API (`fastjsond.std`)

```d
import fastjsond.std;

// Parse JSON (throws JSONException on error)
auto json = parseJSON(jsonString);
auto json = parseJSON(cast(const(char)[]) json);

// Type checking
JSONValue.Type t = json.type();  // null_, string_, integer, uinteger, float_, array, object, true_, false_
if (json.isNull()) { ... }

// Value accessors
string name = json["name"].str;
long count = json["count"].integer;
ulong ucount = json["count"].uinteger;
double price = json["price"].floating;
bool flag = json["flag"].boolean;

// Array/Object access
JSONValue[] arr = json["items"].array;
JSONValue[string] obj = json["config"].object;

// Operators
auto field = json["key"];        // Object field
auto item = json[0];             // Array element
if (auto ptr = "optional" in json) { ... }  // Check existence
size_t len = json.length;        // Array/Object length

// Iteration
foreach (ref item; json["items"]) { ... }
foreach (size_t i, ref item; json["items"]) { ... }
foreach (string key, ref val; json) { ... }

// Serialization
string jsonStr = toJSON(json);
string pretty = toJSON(json, true);  // Pretty print
string custom = toPrettyJSON(json, "  ");  // Custom indent
```

### Types

```d
import fastjsond;

// JSON type enum
enum JsonType : ubyte {
    null_, bool_, int64, uint64, double_, string_, array, object
}

// Error codes
enum JsonError : ubyte {
    none, capacity, memalloc, tapeError, depthError,
    stringError, numberError, utf8Error, incorrectType,
    indexOutOfBounds, noSuchField, // ... and more
}

// Exception type
class JsonException : Exception {
    JsonError error;
}

// Result type for safe extraction
struct Result(T) {
    bool ok();
    bool hasError();
    JsonError error();
    T value();              // Throws if error
    T valueOr(T default);   // Returns default if error
}
```

### Module Functions

```d
import fastjsond;

// Validate JSON without full parse (faster for validation-only)
JsonError err = validate(jsonString);
if (err == JsonError.none) {
    // Valid JSON
}

// Get required padding for parsePadded()
size_t padding = requiredPadding();  // Returns 64 (SIMDJSON_PADDING)

// Get active SIMD implementation
string impl = activeImplementation();  // "haswell", "westmere", "arm64", "fallback", etc.
```

## Error Handling

### Native API

```d
import fastjsond;

// Option 1: Check document validity
auto doc = parser.parse(json);
if (!doc.valid) {
    writeln("Error: ", doc.errorMessage);
    writeln("Code: ", doc.error);
    return;
}

// Option 2: Use Result types (no exceptions)
auto result = doc.root["key"].tryString;
if (!result.ok) {
    writeln("Error: ", result.error);
} else {
    auto value = result.value;
}

// Option 3: Let it throw
try {
    auto value = doc.root["missing"]["key"].getString;
} catch (JsonException e) {
    writeln("Error: ", e.error, " - ", e.msg);
}

// Note: getString() returns null on error (can't throw in @nogc)
const(char)[] str = value.getString();
if (str is null) {
    // Error occurred - use tryString() for proper error handling
}
```

### std API

```d
import fastjsond.std;

try {
    auto json = parseJSON(input);
    auto name = json["name"].str;
} catch (JSONException e) {
    writeln("Error: ", e.msg);
}
```

## Thread Safety

**Native API:**
- `Parser` is **NOT thread-safe** - use one per thread (thread-local recommended)
- `Document` is **NOT thread-safe** - owned by creating thread
- `Value` is **NOT thread-safe** - borrows from Document

**std API:**
- `JSONValue` is **thread-safe** after creation (immutable data)

**Recommended Pattern:**

```d
// Thread-local parser for maximum efficiency
static Parser tlsParser;

void processRequest(const(char)[] json) {
    if (tlsParser is null) {
        tlsParser = Parser.create();
    }
    auto doc = tlsParser.parse(json);
    // Process doc (all access in same thread)
}
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

For comprehensive benchmark results, see [benchmarks/README.md](benchmarks/README.md).

## String Lifetime

Native API strings are borrowed references into the original JSON buffer. They are valid only while the Document exists.

**Important:** `getString()` returns `null` on error (cannot throw exceptions due to `@nogc` constraint). Use `tryString()` for proper error handling.

```d
// Incorrect: reference invalid after doc goes out of scope
const(char)[] getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString;  // ⚠️ Dangling reference
}

// Correct: copy the string
string getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString.idup;  // ✓ Safe: copied to GC heap
}

// Better: use tryString() for error handling
string getName() {
    auto doc = parser.parse(`{"name": "test"}`);
    if (auto result = doc.root["name"].tryString) {
        return result.value.idup;  // ✓ Safe with error handling
    }
    return "";
}

// Alternative: use std API (auto-copies, thread-safe)
import fastjsond.std;
string getName() {
    auto json = parseJSON(`{"name": "test"}`);
    return json["name"].str;  // ✓ Safe: all strings copied
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

- [Technical Specifications](docs/specs.md) — Complete API reference with examples
- [Benchmarks](benchmarks/README.md) — Comprehensive performance analysis
- [simdjson](https://github.com/simdjson/simdjson) — Underlying parser library

## Contributing

Contributions are welcome. Please ensure:

1. Tests pass (`make test`)
2. Benchmarks do not regress
3. Code follows D style guidelines

## License

MIT License — see [LICENSE](LICENSE) for details.
