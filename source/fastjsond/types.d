/**
 * fastjsond - Type Definitions
 *
 * Core types: JsonType, JsonError, Result
 */
module fastjsond.types;

import std.format : format;

/* ============================================================================
 * JSON Type Enum
 * ============================================================================ */

/// JSON value type
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

/// Convert JsonType to human-readable string
string toString(JsonType t) @nogc nothrow {
    final switch (t) {
        case JsonType.null_:   return "null";
        case JsonType.bool_:   return "bool";
        case JsonType.int64:   return "int64";
        case JsonType.uint64:  return "uint64";
        case JsonType.double_: return "double";
        case JsonType.string_: return "string";
        case JsonType.array:   return "array";
        case JsonType.object:  return "object";
    }
}

/* ============================================================================
 * JSON Error Enum
 * ============================================================================ */

/// JSON parsing/access error
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
string errorMessage(JsonError err) @nogc nothrow {
    final switch (err) {
        case JsonError.none:               return "Success";
        case JsonError.capacity:           return "Document too large";
        case JsonError.memalloc:           return "Memory allocation failed";
        case JsonError.tapeError:          return "Internal tape error";
        case JsonError.depthError:         return "Document too deep (>1024 levels)";
        case JsonError.stringError:        return "Invalid string encoding";
        case JsonError.tAtomError:         return "Invalid 'true' literal";
        case JsonError.fAtomError:         return "Invalid 'false' literal";
        case JsonError.nAtomError:         return "Invalid 'null' literal";
        case JsonError.numberError:        return "Invalid number format";
        case JsonError.utf8Error:          return "Invalid UTF-8 encoding";
        case JsonError.uninitialized:      return "Parser not initialized";
        case JsonError.empty:              return "Empty input";
        case JsonError.unescapedChars:     return "Unescaped control characters in string";
        case JsonError.unclosedString:     return "Unclosed string literal";
        case JsonError.unsupportedArch:    return "Unsupported CPU architecture";
        case JsonError.incorrectType:      return "Type mismatch";
        case JsonError.numberOutOfRange:   return "Number out of representable range";
        case JsonError.indexOutOfBounds:   return "Array index out of bounds";
        case JsonError.noSuchField:        return "Object field not found";
        case JsonError.ioError:            return "I/O error";
        case JsonError.invalidJsonPointer: return "Invalid JSON Pointer syntax";
        case JsonError.invalidUriFragment: return "Invalid URI fragment";
        case JsonError.unexpectedError:    return "Unexpected internal error";
        case JsonError.parserInUse:        return "Parser already in use";
        case JsonError.outOfOrderIteration:return "Iteration order violation";
        case JsonError.insufficientPadding:return "Insufficient buffer padding";
        case JsonError.incompleteStructure:return "Incomplete array or object";
        case JsonError.scalarAsValue:      return "Scalar document accessed as value";
        case JsonError.outOfBounds:        return "Out of bounds";
        case JsonError.trailingContent:    return "Trailing content after JSON";
        case JsonError.unknown:            return "Unknown error";
    }
}

/* ============================================================================
 * Result Type
 * ============================================================================ */

/**
 * Result type for safe value extraction.
 *
 * Use this when you want to handle errors without exceptions.
 *
 * Example:
 * ---
 * auto result = value.tryInt();
 * if (result.ok) {
 *     writeln("Value: ", result.value);
 * } else {
 *     writeln("Error: ", result.error.errorMessage);
 * }
 *
 * // Or with default value
 * auto val = value.tryInt().valueOr(42);
 * ---
 */
struct Result(T) {
    private T _value;
    private JsonError _error;
    
    /// Construct success result
    static Result ok(T value) @nogc nothrow {
        Result r;
        r._value = value;
        r._error = JsonError.none;
        return r;
    }
    
    /// Construct error result
    static Result err(JsonError error) @nogc nothrow {
        Result r;
        r._error = error;
        return r;
    }
    
    /// Check if result is valid (no error)
    bool ok() const @nogc nothrow {
        return _error == JsonError.none;
    }
    
    /// Check if result has error
    bool hasError() const @nogc nothrow {
        return _error != JsonError.none;
    }
    
    /// Get error code
    JsonError error() const @nogc nothrow {
        return _error;
    }
    
    /// Get value (throws if error)
    T value() const {
        if (_error != JsonError.none) {
            throw new JsonException(_error);
        }
        return _value;
    }
    
    /// Get value or default
    T valueOr(T defaultValue) const @nogc nothrow {
        return _error == JsonError.none ? _value : defaultValue;
    }
    
    /// Implicit bool conversion for if (result) { ... }
    bool opCast(T : bool)() const @nogc nothrow {
        return ok;
    }
    
    /// Allow: if (auto val = result) { use val }
    auto opUnary(string op : "*")() const {
        return value;
    }
}

/* ============================================================================
 * Exception Type
 * ============================================================================ */

/// Exception thrown on JSON errors
class JsonException : Exception {
    JsonError error;
    
    this(JsonError err, string file = __FILE__, size_t line = __LINE__) {
        error = err;
        super(err.errorMessage.idup, file, line);
    }
    
    this(string msg, JsonError err = JsonError.unknown, 
         string file = __FILE__, size_t line = __LINE__) {
        error = err;
        super(msg, file, line);
    }
}
