/**
 * fastjsond - Value Type
 *
 * Represents a JSON value. Borrows data from Document.
 * Valid only while the parent Document exists.
 *
 * WARNING: Zero-copy strings point into the original JSON buffer.
 * Copy with .idup if you need to keep them beyond Document lifetime.
 */
module fastjsond.value;

import fastjsond.types;
import fastjsond.bindings;

/**
 * JSON Value - borrowed reference to a JSON element.
 *
 * This is a lightweight handle (16 bytes) that references data
 * owned by a Document. It becomes invalid when the Document is destroyed.
 *
 * Example:
 * ---
 * auto doc = parser.parse(`{"name": "Alice", "age": 30}`);
 * auto root = doc.root;
 *
 * // Access object fields
 * auto name = root["name"].getString;  // Zero-copy!
 * auto age = root["age"].getInt;
 *
 * // Safe access with Result
 * if (auto email = root["email"].tryString) {
 *     writeln("Email: ", email.value);
 * }
 *
 * // Iteration
 * foreach (key, val; root) {
 *     writeln(key, ": ", val);
 * }
 * ---
 */
struct Value {
    package fj_value handle;
    
    /// Construct from C handle
    package this(fj_value h) @nogc nothrow {
        handle = h;
    }
    
    /* =========================================================================
     * Type Checking
     * ========================================================================= */
    
    /// Get the JSON type of this value
    JsonType type() @nogc nothrow {
        return cast(JsonType) fj_value_type(handle);
    }
    
    /// Check if value is null
    bool isNull() @nogc nothrow {
        return fj_value_is_null(handle);
    }
    
    /// Check if value is boolean
    bool isBool() @nogc nothrow {
        return fj_value_is_bool(handle);
    }
    
    /// Check if value is signed 64-bit integer
    bool isInt() @nogc nothrow {
        return fj_value_is_int64(handle);
    }
    
    /// Check if value is unsigned 64-bit integer
    bool isUint() @nogc nothrow {
        return fj_value_is_uint64(handle);
    }
    
    /// Check if value is double-precision float
    bool isDouble() @nogc nothrow {
        return fj_value_is_double(handle);
    }
    
    /// Check if value is any numeric type
    bool isNumber() @nogc nothrow {
        return fj_value_is_number(handle);
    }
    
    /// Check if value is string
    bool isString() @nogc nothrow {
        return fj_value_is_string(handle);
    }
    
    /// Check if value is array
    bool isArray() @nogc nothrow {
        return fj_value_is_array(handle);
    }
    
    /// Check if value is object
    bool isObject() @nogc nothrow {
        return fj_value_is_object(handle);
    }
    
    /* =========================================================================
     * Value Extraction (throwing)
     * ========================================================================= */
    
    /// Get boolean value. Throws JsonException on type mismatch.
    bool getBool() {
        bool result;
        auto err = cast(JsonError) fj_value_get_bool(handle, &result);
        if (err != JsonError.none) throw new JsonException(err);
        return result;
    }
    
    /// Get signed 64-bit integer. Throws on type mismatch.
    long getInt() {
        long result;
        auto err = cast(JsonError) fj_value_get_int64(handle, &result);
        if (err != JsonError.none) throw new JsonException(err);
        return result;
    }
    
    /// Get unsigned 64-bit integer. Throws on type mismatch.
    ulong getUint() {
        ulong result;
        auto err = cast(JsonError) fj_value_get_uint64(handle, &result);
        if (err != JsonError.none) throw new JsonException(err);
        return result;
    }
    
    /// Get double-precision float. Throws on type mismatch.
    double getDouble() {
        double result;
        auto err = cast(JsonError) fj_value_get_double(handle, &result);
        if (err != JsonError.none) throw new JsonException(err);
        return result;
    }
    
    /**
     * Get string value (zero-copy).
     *
     * WARNING: Returns a slice into the original JSON buffer.
     * Valid only while Document exists. Use .idup to copy.
     *
     * Throws JsonException on type mismatch or invalid value.
     * Use tryString() for @nogc contexts or explicit error handling.
     */
    const(char)[] getString() {
        const(char)* ptr;
        size_t len;
        auto err = cast(JsonError) fj_value_get_string(handle, &ptr, &len);
        if (err != JsonError.none) {
            throw new JsonException(err);
        }
        return ptr[0 .. len];
    }
    
    /* =========================================================================
     * Safe Value Extraction (Result)
     * ========================================================================= */
    
    /// Try to get boolean value
    Result!bool tryBool() @nogc nothrow {
        bool result;
        auto err = cast(JsonError) fj_value_get_bool(handle, &result);
        return err == JsonError.none 
            ? Result!bool.ok(result) 
            : Result!bool.err(err);
    }
    
    /// Try to get signed 64-bit integer
    Result!long tryInt() @nogc nothrow {
        long result;
        auto err = cast(JsonError) fj_value_get_int64(handle, &result);
        return err == JsonError.none 
            ? Result!long.ok(result) 
            : Result!long.err(err);
    }
    
    /// Try to get unsigned 64-bit integer
    Result!ulong tryUint() @nogc nothrow {
        ulong result;
        auto err = cast(JsonError) fj_value_get_uint64(handle, &result);
        return err == JsonError.none 
            ? Result!ulong.ok(result) 
            : Result!ulong.err(err);
    }
    
    /// Try to get double-precision float
    Result!double tryDouble() @nogc nothrow {
        double result;
        auto err = cast(JsonError) fj_value_get_double(handle, &result);
        return err == JsonError.none 
            ? Result!double.ok(result) 
            : Result!double.err(err);
    }
    
    /// Try to get string value (zero-copy)
    Result!(const(char)[]) tryString() @nogc nothrow {
        const(char)* ptr;
        size_t len;
        auto err = cast(JsonError) fj_value_get_string(handle, &ptr, &len);
        return err == JsonError.none 
            ? Result!(const(char)[]).ok(ptr[0 .. len]) 
            : Result!(const(char)[]).err(err);
    }
    
    /* =========================================================================
     * Object Access
     * ========================================================================= */
    
    /**
     * Get object field by key.
     * 
     * Example:
     * ---
     * auto name = json["user"]["name"].getString;
     * ---
     *
     * Throws JsonException if key not found or not an object.
     */
    Value opIndex(const(char)[] key) {
        fj_value result;
        FjError err;
        
        // Use null-terminated version if possible
        if (key.length > 0 && key.ptr[key.length] == '\0') {
            err = fj_value_get_field(handle, key.ptr, &result);
        } else {
            err = fj_value_get_field_len(handle, key.ptr, key.length, &result);
        }
        
        if (err != FjError.success) {
            throw new JsonException(cast(JsonError) err);
        }
        return Value(result);
    }
    
    /// Check if object has field
    bool hasKey(const(char)[] key) @nogc nothrow {
        // Need null-terminated for C API
        if (key.length == 0) return false;
        
        // Check if already null-terminated
        if (key.ptr[key.length] == '\0') {
            return fj_value_has_field(handle, key.ptr);
        }
        
        // Need to make a copy - can't do in @nogc
        // Fall back to trying to get the field
        fj_value result;
        auto err = fj_value_get_field_len(handle, key.ptr, key.length, &result);
        return err == FjError.success;
    }
    
    /// Get number of fields in object
    size_t objectSize() @nogc nothrow {
        size_t result;
        auto err = fj_value_object_size(handle, &result);
        return err == FjError.success ? result : 0;
    }
    
    /* =========================================================================
     * Array Access
     * ========================================================================= */
    
    /**
     * Get array element by index.
     *
     * Example:
     * ---
     * auto first = json["items"][0];
     * ---
     *
     * Throws JsonException if index out of bounds or not an array.
     */
    Value opIndex(size_t idx) {
        fj_value result;
        auto err = fj_value_get_index(handle, idx, &result);
        if (err != FjError.success) {
            throw new JsonException(cast(JsonError) err);
        }
        return Value(result);
    }
    
    /// Get array/object length
    size_t length() @nogc nothrow {
        size_t result;
        
        // Try array first
        if (fj_value_array_size(handle, &result) == FjError.success) {
            return result;
        }
        
        // Try object
        if (fj_value_object_size(handle, &result) == FjError.success) {
            return result;
        }
        
        return 0;
    }
    
    /// Alias for length
    alias opDollar = length;
    
    /* =========================================================================
     * Iteration
     * ========================================================================= */
    
    /// Iterate array elements
    int opApply(scope int delegate(Value) dg) {
        fj_array_iter iter;
        if (fj_array_iter_new(handle, &iter) != FjError.success) {
            return 0;
        }
        scope(exit) fj_array_iter_free(iter);
        
        fj_value elem;
        while (fj_array_iter_next(iter, &elem)) {
            if (auto result = dg(Value(elem))) {
                return result;
            }
        }
        return 0;
    }
    
    /// Iterate array elements with index
    int opApply(scope int delegate(size_t, Value) dg) {
        fj_array_iter iter;
        if (fj_array_iter_new(handle, &iter) != FjError.success) {
            return 0;
        }
        scope(exit) fj_array_iter_free(iter);
        
        size_t idx = 0;
        fj_value elem;
        while (fj_array_iter_next(iter, &elem)) {
            if (auto result = dg(idx++, Value(elem))) {
                return result;
            }
        }
        return 0;
    }
    
    /// Iterate object key-value pairs
    int opApply(scope int delegate(const(char)[], Value) dg) {
        fj_object_iter iter;
        if (fj_object_iter_new(handle, &iter) != FjError.success) {
            return 0;
        }
        scope(exit) fj_object_iter_free(iter);
        
        const(char)* key;
        size_t keyLen;
        fj_value val;
        while (fj_object_iter_next(iter, &key, &keyLen, &val)) {
            if (auto result = dg(key[0 .. keyLen], Value(val))) {
                return result;
            }
        }
        return 0;
    }
    
    /* =========================================================================
     * String Conversion
     * ========================================================================= */
    
    /// Convert value to string representation (for debugging)
    string toString() {
        import std.format : format;
        final switch (type) {
            case JsonType.null_:   return "null";
            case JsonType.bool_:   return tryBool.valueOr(false) ? "true" : "false";
            case JsonType.int64:   return format("%d", tryInt.valueOr(0));
            case JsonType.uint64:  return format("%d", tryUint.valueOr(0));
            case JsonType.double_: return format("%g", tryDouble.valueOr(0.0));
            case JsonType.string_: return format(`"%s"`, tryString.valueOr(""));
            case JsonType.array:   return format("[array:%d]", length);
            case JsonType.object:  return format("{object:%d}", length);
        }
    }
}

// Remove unused format wrapper
