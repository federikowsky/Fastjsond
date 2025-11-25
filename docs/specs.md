# fastjsond - High-Performance JSON Parser for D

## Overview

`fastjsond` is a D wrapper around [simdjson](https://github.com/simdjson/simdjson), It provides:

1. **Native API** (`fastjsond`) - Zero-copy, high-performance access
2. **Std API** (`fastjsond.std`) - Drop-in replacement for `std.json`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      D Application                          │
├─────────────────────────────────────────────────────────────┤
│  fastjsond.std       │           fastjsond                  │
│  ┌─────────────┐     │  ┌────────┐ ┌────────┐ ┌───────┐     │
│  │ JSONValue   │     │  │ Parser │ │Document│ │ Value │     │
│  │ parseJSON() │     │  └────────┘ └────────┘ └───────┘     │
│  │ toJSON()    │     │                                      │
│  └─────────────┘     │  Zero-copy, borrowed references      │
│  Copies data         │                                      │
├─────────────────────────────────────────────────────────────┤
│                    fastjsond.bindings                       │
│              (D bindings to C API)                          │
├─────────────────────────────────────────────────────────────┤
│                      C API Layer                            │
│              (simdjson_api.cpp → simdjson_api.h)            │
├─────────────────────────────────────────────────────────────┤
│                       simdjson                              │
│              (Amalgamated C++ source)                       │
└─────────────────────────────────────────────────────────────┘
```

## Native API (`fastjsond`)

### Design Principles

1. **Zero-copy strings** - String values point directly into the source buffer
2. **Explicit lifetime** - Document owns data, Value borrows from Document
3. **Type-safe errors** - `JsonError` enum with descriptive values
4. **Reusable parser** - Parser instance holds internal buffers, reuse for efficiency
5. **Move semantics** - Document is move-only, no accidental copies

### Types

#### `Parser`
Reusable parser instance. Holds internal buffers for efficiency.
Thread-local usage recommended.

```d
struct Parser {
    /// Parse JSON string, returns Document
    Document parse(const(char)[] json);
    
    /// Parse with explicit padding (for maximum SIMD efficiency)
    Document parsePadded(const(char)[] json, size_t padding = 64);
    
    /// Parse from ubyte array
    Document parse(const(ubyte)[] json);
}

// Usage
auto parser = Parser();
auto doc = parser.parse(`{"name": "Aurora", "version": 1}`);
```

#### `Document`
Parsed JSON document. Owns the parsed data.

```d
struct Document {
    /// Get root value
    Value root() @nogc nothrow;
    
    /// Check if parsing succeeded
    bool valid() const @nogc nothrow;
    
    /// Get error if parsing failed
    JsonError error() const @nogc nothrow;
    
    /// Error message (empty if valid)
    const(char)[] errorMessage() const @nogc nothrow;
    
    // Move-only semantics
    @disable this(this);
    Document opAssign(Document rhs);  // Move assignment
}
```

#### `Value`
Reference to a JSON value. **Borrows from Document** - only valid while Document exists.

```d
struct Value {
    // ─────────────────────────────────────────────────────
    // Type Checking
    // ─────────────────────────────────────────────────────
    JsonType type() @nogc nothrow;
    
    bool isNull()   @nogc nothrow;
    bool isBool()   @nogc nothrow;
    bool isInt()    @nogc nothrow;
    bool isUint()   @nogc nothrow;
    bool isDouble() @nogc nothrow;
    bool isNumber() @nogc nothrow;  // int, uint, or double
    bool isString() @nogc nothrow;
    bool isArray()  @nogc nothrow;
    bool isObject() @nogc nothrow;
    
    // ─────────────────────────────────────────────────────
    // Value Extraction (throw on type mismatch)
    // ─────────────────────────────────────────────────────
    bool        getBool();
    long        getInt();
    ulong       getUint();
    double      getDouble();
    const(char)[] getString() @nogc;  // Zero-copy!
    
    // ─────────────────────────────────────────────────────
    // Safe Extraction (return Result)
    // ─────────────────────────────────────────────────────
    Result!bool        tryBool()   @nogc nothrow;
    Result!long        tryInt()    @nogc nothrow;
    Result!ulong       tryUint()   @nogc nothrow;
    Result!double      tryDouble() @nogc nothrow;
    Result!(const(char)[]) tryString() @nogc nothrow;
    
    // ─────────────────────────────────────────────────────
    // Object Access
    // ─────────────────────────────────────────────────────
    Value opIndex(const(char)[] key);      // json["key"]
    bool hasKey(const(char)[] key) @nogc nothrow;
    
    // ─────────────────────────────────────────────────────
    // Array Access
    // ─────────────────────────────────────────────────────
    Value opIndex(size_t idx);             // json[0]
    size_t length() @nogc nothrow;         // Array/Object size
    
    // ─────────────────────────────────────────────────────
    // Iteration
    // ─────────────────────────────────────────────────────
    // Array iteration
    int opApply(scope int delegate(Value element) dg);
    int opApply(scope int delegate(size_t idx, Value element) dg);
    
    // Object iteration
    int opApply(scope int delegate(const(char)[] key, Value val) dg);
    
    // Range interface
    auto byElement();   // For arrays
    auto byKeyValue();  // For objects
}
```

#### `JsonType`
```d
enum JsonType : ubyte {
    null_,
    bool_,
    int64,
    uint64,
    double_,
    string_,
    array,
    object
}
```

#### `JsonError`
```d
enum JsonError : ubyte {
    none = 0,
    
    // Structural errors
    invalidJson,
    emptyInput,
    unexpectedEnd,
    
    // Type errors
    typeMismatch,
    keyNotFound,
    indexOutOfBounds,
    
    // Encoding errors
    invalidUtf8,
    invalidEscape,
    
    // Number errors
    numberOutOfRange,
    invalidNumber,
    
    // Capacity errors
    documentTooDeep,
    tooManyFields,
    stringTooLong
}
```

#### `Result(T)`
```d
struct Result(T) {
    private T _value;
    private JsonError _error;
    
    bool valid() const @nogc nothrow;
    JsonError error() const @nogc nothrow;
    
    T value() const;              // Throws if error
    T valueOr(T defaultVal) const @nogc nothrow;
    
    // Implicit conversion when valid
    alias opCast(bool) = valid;
}
```

### Usage Examples

```d
import fastjsond;

// Parse JSON
auto parser = Parser();
auto doc = parser.parse(`{
    "name": "Aurora",
    "version": 2,
    "features": ["fast", "safe", "modern"],
    "config": {
        "workers": 4,
        "debug": false
    }
}`);

if (!doc.valid) {
    writeln("Error: ", doc.errorMessage);
    return;
}

auto root = doc.root;

// Access values (zero-copy strings!)
string name = root["name"].getString.idup;  // Copy only when needed
long version_ = root["version"].getInt;

// Safe access with Result
if (auto workers = root["config"]["workers"].tryInt) {
    writeln("Workers: ", workers.value);
}

// Iterate array
foreach (feature; root["features"]) {
    writeln("Feature: ", feature.getString);
}

// Iterate object
foreach (key, val; root["config"]) {
    writeln(key, " = ", val);
}

// Check existence before access
if (root.hasKey("optional")) {
    auto opt = root["optional"];
}
```

---

## Std API (`fastjsond.std`)

Drop-in replacement for `std.json`. **Copies all data** into D structures
for easy migration, at the cost of performance.

### Types

#### `JSONValue`
```d
struct JSONValue {
    // ─────────────────────────────────────────────────────
    // Type enum (matches std.json)
    // ─────────────────────────────────────────────────────
    enum Type {
        null_,
        string_,
        integer,
        uinteger,
        float_,
        array,
        object,
        true_,
        false_
    }
    
    Type type();
    
    // ─────────────────────────────────────────────────────
    // Value accessors (match std.json)
    // ─────────────────────────────────────────────────────
    string str();
    long integer();
    ulong uinteger();
    double floating();
    JSONValue[] array();
    JSONValue[string] object();
    bool boolean();  // Extension
    
    // ─────────────────────────────────────────────────────
    // Operators
    // ─────────────────────────────────────────────────────
    JSONValue opIndex(string key);
    JSONValue opIndex(size_t idx);
    
    // in operator
    JSONValue* opBinaryRight(string op)(string key) if (op == "in");
    
    // ─────────────────────────────────────────────────────
    // Serialization
    // ─────────────────────────────────────────────────────
    string toString();
    void toString(scope void delegate(const(char)[]) sink);
}
```

### Functions

```d
/// Parse JSON string (throws JSONException on error)
JSONValue parseJSON(string json);
JSONValue parseJSON(const(char)[] json);

/// Parse with options
JSONValue parseJSON(string json, ParseOptions options);

/// Convert to JSON string
string toJSON(JSONValue value);
string toJSON(JSONValue value, bool pretty);

/// Pretty print with custom indent
string toPrettyJSON(JSONValue value, string indent = "  ");
```

### Migration from std.json

```d
// Before (std.json)
import std.json;
auto json = parseJSON(`{"name": "test"}`);
string name = json["name"].str;

// After (fastjsond.std) - identical!
import fastjsond.std;
auto json = parseJSON(`{"name": "test"}`);
string name = json["name"].str;
```

### Differences from std.json

| Feature | std.json | fastjsond.std |
|---------|----------|---------------|
| Performance | Baseline | 5-10x faster parsing |
| Memory | GC allocations | Bulk allocation + copy |
| Streaming | No | No |
| Comments | No | No |

---

## Performance Characteristics

### Parsing Speed (measured on Apple M1)

| Parser | Throughput | Relative |
|--------|------------|----------|
| std.json | 100-200 MB/s | 1x |
| fastjsond.std | 150-500 MB/s | 1.5-2.5x |
| fastjsond (native) | 700-4000 MB/s | 7-20x |

### Large Payload Performance

| Payload | std.json | fastjsond native | Speedup |
|---------|----------|------------------|---------|
| 1 MB | 8.45 ms | 0.59 ms | 14.3x |
| 10 MB | 82.22 ms | 6.83 ms | 12.0x |
| 100 MB | 818.66 ms | 126.49 ms | 6.5x |
| 500 MB | 9.0 sec | 1.05 sec | 8.6x |

### Error Detection Speed

| Error Type | std.json | fastjsond | Speedup |
|------------|----------|-----------|---------|
| Invalid syntax | 0.75 ms | 0.008 ms | 93x |
| Invalid escapes | 0.86 ms | 0.004 ms | 210x |

### Memory Usage

- **Native API**: Near-zero allocation (reuses parser buffers)
- **Std API**: Single bulk allocation for copied data

### Best Practices

1. **Reuse Parser instances** - Don't create new Parser per parse
2. **Use native API for hot paths** - Zero-copy is much faster
3. **Copy strings only when needed** - Use `.idup` explicitly
4. **Prefer tryX() methods** - Avoid exception overhead

---

## Buffer Lifetime

### Critical: Zero-Copy String Lifetime

Native API strings point into the original JSON buffer. They are valid only
while the Document exists:

```d
const(char)[] getString() {
    auto parser = Parser();
    auto doc = parser.parse(`{"name": "test"}`);
    return doc.root["name"].getString;  // DANGER: Returns borrowed pointer
}  // doc destroyed here!

void main() {
    auto name = getString();  // ⚠️ DANGLING POINTER - undefined behavior!
    writeln(name);            // May crash or print garbage
}
```

### Safe Patterns

```d
// Pattern 1: Copy immediately
string getName(const(char)[] json) {
    auto parser = Parser();
    auto doc = parser.parse(json);
    return doc.root["name"].getString.idup;  // ✓ Safe: copied to GC heap
}

// Pattern 2: Process within scope
void processJson(const(char)[] json) {
    auto parser = Parser();
    auto doc = parser.parse(json);
    
    // ✓ Safe: all access within Document lifetime
    foreach (key, val; doc.root) {
        writeln(key, ": ", val.getString);
    }
}  // doc destroyed, all Values invalidated

// Pattern 3: Use std API (auto-copies)
JSONValue parseAndKeep(string json) {
    return parseJSON(json);  // ✓ Safe: all strings copied
}
```

---

## Error Handling

### Native API

```d
// Option 1: Check validity
auto doc = parser.parse(json);
if (!doc.valid) {
    stderr.writeln("Parse error: ", doc.errorMessage);
    return;
}

// Option 2: Use Result types
auto result = doc.root["key"].tryString;
if (!result.valid) {
    // Handle error
} else {
    auto value = result.value;
}

// Option 3: Let it throw
try {
    auto value = doc.root["missing"]["key"].getString;
} catch (JsonException e) {
    // Handle error
}
```

### Compat API

```d
try {
    auto json = parseJSON(input);
    auto name = json["name"].str;
} catch (JSONException e) {
    // Compatible with std.json exception handling
    writeln("Error: ", e.msg);
}
```

---

## Thread Safety

- `Parser` is **not thread-safe** - use one per thread (thread-local)
- `Document` is **not thread-safe** - owned by creating thread
- `Value` is **not thread-safe** - borrows from Document
- `JSONValue` (std) is **thread-safe** after creation (immutable data)

Recommended pattern:
```d
// Thread-local parser for maximum efficiency
static Parser tlsParser;

void processRequest(const(char)[] json) {
    if (tlsParser is null) {
        tlsParser = Parser();
    }
    auto doc = tlsParser.parse(json);
    // ...
}
```

---

## Build Configuration

### Makefile Targets

```makefile
make lib      # Build static library
make test     # Run unit tests
make bench    # Run benchmarks
make clean    # Clean build artifacts
```

### SIMD Detection

simdjson auto-detects the best SIMD implementation:
- **x86-64**: AVX-512, AVX2, SSE4.2
- **ARM**: NEON
- **Fallback**: Portable scalar code

---

## File Structure

```
fastjsond/
├── source/fastjsond/
│   ├── package.d         # Public API exports
│   ├── parser.d          # Parser implementation
│   ├── document.d        # Document type
│   ├── value.d           # Value type  
│   ├── types.d           # JsonType, JsonError enums
│   ├── bindings.d        # D bindings to C API
│   ├── std.d             # std.json compatibility layer
│   └── c/
│       ├── api.h         # C API header
│       ├── api.cpp       # C API implementation
│       ├── simdjson.h    # Amalgamated simdjson
│       └── simdjson.cpp  # Amalgamated simdjson
├── tests/
│   ├── native_test.d     # Native API tests (30 tests)
│   └── std_test.d        # Std API tests (36 tests)
├── benchmarks/
│   ├── benchmark.d       # Comprehensive benchmark suite
│   ├── Makefile
│   └── README.md
├── docs/
│   └── specs.md          # This file
├── Makefile
├── dub.json
├── LICENSE
└── README.md
```
