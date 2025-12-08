# fastjsond - High-Performance JSON Parser for D

> **Version**: 1.0.0  
> **License**: MIT  
> **Repository**: [github.com/federikowsky/fastjsond](https://github.com/federikowsky/fastjsond)  
> **Last Updated**: 2025-12-06

---

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
    /// Create parser with specified max capacity
    this(size_t maxCapacity) @nogc nothrow;
    
    /// Create parser with default capacity
    static Parser create() @nogc nothrow;
    
    /// Parse JSON string, returns Document
    Document parse(const(char)[] json) @nogc nothrow;
    
    /// Parse from string (convenience overload)
    Document parse(string json) @nogc nothrow;
    
    /// Parse from ubyte array
    Document parse(const(ubyte)[] json) @nogc nothrow;
    
    /// Parse with pre-padded buffer (for maximum SIMD efficiency)
    /// Buffer must have SIMDJSON_PADDING (64) extra bytes at end
    Document parsePadded(const(char)[] json) @nogc nothrow;
    
    /// Check if parser is valid
    bool valid() const @nogc nothrow;
    
    /// Implicit bool conversion
    bool opCast(T : bool)() const @nogc nothrow;
    
    // Move-only semantics
    @disable this(this);
    ref Parser opAssign(return scope Parser rhs) return @nogc nothrow;
}

// Usage
auto parser = Parser.create();
auto doc = parser.parse(`{"name": "Aurora", "version": 1}`);
```

#### `Document`
Parsed JSON document. Owns the parsed data.

```d
struct Document {
    /// Get root value
    Value root() @nogc nothrow;
    
    /// Convenience: direct indexing into root object
    Value opIndex(const(char)[] key);
    
    /// Convenience: direct indexing into root array
    Value opIndex(size_t idx);
    
    /// Check if parsing succeeded
    bool valid() const @nogc nothrow;
    
    /// Implicit bool conversion
    bool opCast(T : bool)() const @nogc nothrow;
    
    /// Get error if parsing failed
    JsonError error() const @nogc nothrow;
    
    /// Error message (empty if valid)
    const(char)[] errorMessage() const @nogc nothrow;
    
    // Move-only semantics
    @disable this(this);
    ref Document opAssign(return scope Document rhs) return @nogc nothrow;
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
    // Value Extraction (throws JsonException on type mismatch)
    // ─────────────────────────────────────────────────────
    bool          getBool();
    long          getInt();
    ulong         getUint();
    double        getDouble();
    const(char)[] getString() @nogc;  // Zero-copy! Returns null on error
    
    // ─────────────────────────────────────────────────────
    // Safe Extraction (return Result)
    // ─────────────────────────────────────────────────────
    Result!bool              tryBool()   @nogc nothrow;
    Result!long              tryInt()    @nogc nothrow;
    Result!ulong             tryUint()   @nogc nothrow;
    Result!double            tryDouble() @nogc nothrow;
    Result!(const(char)[])   tryString() @nogc nothrow;
    
    // ─────────────────────────────────────────────────────
    // Object Access
    // ─────────────────────────────────────────────────────
    Value opIndex(const(char)[] key);      // json["key"] - throws if not found
    bool hasKey(const(char)[] key) @nogc nothrow;
    size_t objectSize() @nogc nothrow;     // Number of fields
    
    // ─────────────────────────────────────────────────────
    // Array Access
    // ─────────────────────────────────────────────────────
    Value opIndex(size_t idx);             // json[0] - throws if out of bounds
    size_t length() @nogc nothrow;         // Array/Object size
    alias opDollar = length;
    
    // ─────────────────────────────────────────────────────
    // Iteration (foreach support)
    // ─────────────────────────────────────────────────────
    // Array iteration
    int opApply(scope int delegate(Value element) dg);
    int opApply(scope int delegate(size_t idx, Value element) dg);
    
    // Object iteration
    int opApply(scope int delegate(const(char)[] key, Value val) dg);
    
    // ─────────────────────────────────────────────────────
    // String Conversion (for debugging)
    // ─────────────────────────────────────────────────────
    string toString();
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
    
    // Capacity errors
    capacity,           /// Document too large
    memalloc,           /// Memory allocation failed
    
    // Parse errors
    tapeError,          /// Internal tape error
    depthError,         /// Document too deep (>1024 levels)
    stringError,        /// Invalid string encoding
    tAtomError,         /// Invalid 'true' literal
    fAtomError,         /// Invalid 'false' literal
    nAtomError,         /// Invalid 'null' literal
    numberError,        /// Invalid number format
    utf8Error,          /// Invalid UTF-8 encoding
    
    // State errors
    uninitialized,      /// Parser not initialized
    empty,              /// Empty input
    
    // Syntax errors
    unescapedChars,     /// Unescaped control characters
    unclosedString,     /// Unclosed string literal
    
    // Runtime errors
    unsupportedArch,    /// Unsupported CPU architecture
    incorrectType,      /// Type mismatch
    numberOutOfRange,   /// Number out of representable range
    indexOutOfBounds,   /// Array index out of bounds
    noSuchField,        /// Object field not found
    ioError,            /// I/O error (file operations)
    
    // JSON Pointer errors
    invalidJsonPointer, /// Invalid JSON Pointer syntax
    invalidUriFragment, /// Invalid URI fragment
    
    // Internal errors
    unexpectedError,    /// Unexpected internal error
    parserInUse,        /// Parser already parsing
    outOfOrderIteration,/// Iteration order violation
    insufficientPadding,/// Insufficient buffer padding
    incompleteStructure,/// Incomplete array/object
    scalarAsValue,      /// Scalar document accessed as value
    outOfBounds,        /// Generic out of bounds
    trailingContent,    /// Trailing content after JSON
    
    unknown = 255       /// Unknown error
}

/// Get human-readable error message
string errorMessage(JsonError err) @nogc nothrow;
```

#### `Result(T)`
```d
struct Result(T) {
    private T _value;
    private JsonError _error;
    
    /// Construct success result
    static Result ok(T value) @nogc nothrow;
    
    /// Construct error result
    static Result err(JsonError error) @nogc nothrow;
    
    /// Check if result is valid (no error)
    bool ok() const @nogc nothrow;
    
    /// Check if result has error
    bool hasError() const @nogc nothrow;
    
    /// Get error code
    JsonError error() const @nogc nothrow;
    
    /// Get value (throws JsonException if error)
    T value() const;
    
    /// Get value or default
    T valueOr(T defaultValue) const @nogc nothrow;
    
    /// Implicit bool conversion: if (result) { ... }
    bool opCast(T : bool)() const @nogc nothrow;
}
```

#### `JsonException`
```d
class JsonException : Exception {
    JsonError error;
    
    this(JsonError err, string file = __FILE__, size_t line = __LINE__);
    this(string msg, JsonError err = JsonError.unknown, 
         string file = __FILE__, size_t line = __LINE__);
}
```

### Module-Level Functions

```d
/// Quickly validate JSON without full parse.
/// Faster than full parse if you only need to check validity.
/// Returns: JsonError.none if valid, error code otherwise.
JsonError validate(const(char)[] json) @nogc nothrow;

/// Get required padding for SIMD optimization.
/// When using parsePadded(), ensure your buffer has this many
/// extra bytes at the end.
size_t requiredPadding() @nogc nothrow;

/// Get active SIMD implementation name.
/// Returns: "haswell", "westmere", "arm64", "fallback", etc.
const(char)[] activeImplementation() @nogc nothrow;
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
