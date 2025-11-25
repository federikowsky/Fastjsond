/**
 * fastjsond.std - std.json Compatibility Layer
 *
 * Drop-in replacement for std.json. Provides JSONValue type and
 * parseJSON/toJSON functions with compatible signatures.
 *
 * IMPORTANT: Unlike the native API, this layer COPIES all data
 * into D structures. Use the native API for maximum performance.
 *
 * Example:
 * ---
 * // Before (std.json)
 * import std.json;
 * auto json = parseJSON(`{"name": "test"}`);
 * string name = json["name"].str;
 *
 * // After (fastjsond.std) - identical!
 * import fastjsond.std;
 * auto json = parseJSON(`{"name": "test"}`);
 * string name = json["name"].str;
 * ---
 */
module fastjsond.std;

import fastjsond.parser : Parser;
import fastjsond.value : Value;
import fastjsond.types : JsonType, JsonError, JsonException;
import fastjsond.bindings : fj_object_iter, fj_object_iter_new, fj_object_iter_next, 
                            fj_object_iter_free, fj_value, FjError;

import std.array : Appender, appender;
import std.conv : to;
import std.range : empty;

/**
 * JSON Value - compatible with std.json.JSONValue
 *
 * This is a GC-allocated structure that owns its data.
 * Safe to pass around and store; no lifetime concerns.
 */
struct JSONValue {
    /**
     * JSON type enum - compatible with std.json
     */
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
    
    private {
        Type _type = Type.null_;
        
        // Use separate storage to avoid @safe issues with unions containing GC types
        string _string;
        long _integer;
        ulong _uinteger;
        double _float;
        JSONValue[] _array;
        JSONValue[string] _object;
    }
    
    /* =========================================================================
     * Constructors
     * ========================================================================= */
    
    /// Construct null value
    this(typeof(null)) {
        _type = Type.null_;
    }
    
    /// Construct from bool
    this(bool val) {
        _type = val ? Type.true_ : Type.false_;
    }
    
    /// Construct from string
    this(string val) {
        _type = Type.string_;
        _string = val;
    }
    
    /// Construct from long
    this(long val) {
        _type = Type.integer;
        _integer = val;
    }
    
    /// Construct from int
    this(int val) {
        _type = Type.integer;
        _integer = val;
    }
    
    /// Construct from ulong
    this(ulong val) {
        _type = Type.uinteger;
        _uinteger = val;
    }
    
    /// Construct from double
    this(double val) {
        _type = Type.float_;
        _float = val;
    }
    
    /// Construct from array
    this(JSONValue[] arr) {
        _type = Type.array;
        _array = arr;
    }
    
    /// Construct from object
    this(JSONValue[string] obj) {
        _type = Type.object;
        _object = obj;
    }
    
    /* =========================================================================
     * Type
     * ========================================================================= */
    
    /// Get value type
    Type type() const @safe pure nothrow @nogc {
        return _type;
    }
    
    /// Check if null
    bool isNull() const @safe pure nothrow @nogc {
        return _type == Type.null_;
    }
    
    /* =========================================================================
     * Value Accessors (compatible with std.json)
     * ========================================================================= */
    
    /// Get string value
    string str() const @safe pure {
        if (_type != Type.string_) {
            throw new JSONException("JSONValue is not a string");
        }
        return _string;
    }
    
    /// Get integer value
    long integer() const @safe pure {
        if (_type != Type.integer) {
            throw new JSONException("JSONValue is not an integer");
        }
        return _integer;
    }
    
    /// Get unsigned integer value
    ulong uinteger() const @safe pure {
        if (_type != Type.uinteger) {
            throw new JSONException("JSONValue is not an unsigned integer");
        }
        return _uinteger;
    }
    
    /// Get float value
    double floating() const @safe pure {
        if (_type != Type.float_) {
            throw new JSONException("JSONValue is not a float");
        }
        return _float;
    }
    
    /// Get boolean value
    bool boolean() const @safe pure {
        if (_type != Type.true_ && _type != Type.false_) {
            throw new JSONException("JSONValue is not a boolean");
        }
        return _type == Type.true_;
    }
    
    /// Get array value
    inout(JSONValue[]) array() inout @safe pure {
        if (_type != Type.array) {
            throw new JSONException("JSONValue is not an array");
        }
        return _array;
    }
    
    /// Get object value
    inout(JSONValue[string]) object() inout @safe pure {
        if (_type != Type.object) {
            throw new JSONException("JSONValue is not an object");
        }
        return _object;
    }
    
    /* =========================================================================
     * Operators
     * ========================================================================= */
    
    /// Object field access
    ref inout(JSONValue) opIndex(string key) inout @safe pure {
        if (_type != Type.object) {
            throw new JSONException("JSONValue is not an object");
        }
        if (auto p = key in _object) {
            return *p;
        }
        throw new JSONException("Key not found: " ~ key);
    }
    
    /// Array index access
    ref inout(JSONValue) opIndex(size_t idx) inout @safe pure {
        if (_type != Type.array) {
            throw new JSONException("JSONValue is not an array");
        }
        if (idx >= _array.length) {
            throw new JSONException("Array index out of bounds");
        }
        return _array[idx];
    }
    
    /// "in" operator for objects
    inout(JSONValue)* opBinaryRight(string op)(string key) inout @safe pure
        if (op == "in")
    {
        if (_type != Type.object) return null;
        return key in _object;
    }
    
    /// Length for arrays/objects
    size_t length() const @safe pure {
        if (_type == Type.array) return _array.length;
        if (_type == Type.object) return _object.length;
        throw new JSONException("JSONValue has no length");
    }
    
    /// Iteration over arrays
    int opApply(scope int delegate(ref JSONValue) dg) {
        if (_type != Type.array) return 0;
        foreach (ref v; _array) {
            if (auto r = dg(v)) return r;
        }
        return 0;
    }
    
    /// Iteration over arrays with index
    int opApply(scope int delegate(size_t, ref JSONValue) dg) {
        if (_type != Type.array) return 0;
        foreach (i, ref v; _array) {
            if (auto r = dg(i, v)) return r;
        }
        return 0;
    }
    
    /// Iteration over objects
    int opApply(scope int delegate(string, ref JSONValue) dg) {
        if (_type != Type.object) return 0;
        foreach (k, ref v; _object) {
            if (auto r = dg(k, v)) return r;
        }
        return 0;
    }
    
    /* =========================================================================
     * String Conversion
     * ========================================================================= */
    
    /// Convert to JSON string
    string toString() const {
        auto app = appender!string();
        toStringImpl(app, false, 0);
        return app.data;
    }
    
    /// Write to output sink
    void toString(scope void delegate(const(char)[]) sink) const {
        auto app = appender!string();
        toStringImpl(app, false, 0);
        sink(app.data);
    }
    
    private void toStringImpl(ref Appender!string app, bool pretty, int indent) const {
        final switch (_type) {
            case Type.null_:
                app.put("null");
                break;
            case Type.true_:
                app.put("true");
                break;
            case Type.false_:
                app.put("false");
                break;
            case Type.string_:
                app.put('"');
                escapeString(app, _string);
                app.put('"');
                break;
            case Type.integer:
                app.put(_integer.to!string);
                break;
            case Type.uinteger:
                app.put(_uinteger.to!string);
                break;
            case Type.float_:
                app.put(_float.to!string);
                break;
            case Type.array:
                app.put('[');
                bool first = true;
                foreach (ref v; _array) {
                    if (!first) app.put(',');
                    first = false;
                    if (pretty) {
                        app.put('\n');
                        foreach (_; 0 .. indent + 1) app.put("  ");
                    }
                    v.toStringImpl(app, pretty, indent + 1);
                }
                if (pretty && !_array.empty) {
                    app.put('\n');
                    foreach (_; 0 .. indent) app.put("  ");
                }
                app.put(']');
                break;
            case Type.object:
                app.put('{');
                bool first = true;
                foreach (k, ref v; _object) {
                    if (!first) app.put(',');
                    first = false;
                    if (pretty) {
                        app.put('\n');
                        foreach (_; 0 .. indent + 1) app.put("  ");
                    }
                    app.put('"');
                    escapeString(app, k);
                    app.put('"');
                    app.put(':');
                    if (pretty) app.put(' ');
                    v.toStringImpl(app, pretty, indent + 1);
                }
                if (pretty && !_object.empty) {
                    app.put('\n');
                    foreach (_; 0 .. indent) app.put("  ");
                }
                app.put('}');
                break;
        }
    }
}

/* ============================================================================
 * Helper Functions
 * ============================================================================ */

private void escapeString(ref Appender!string app, string s) {
    foreach (c; s) {
        switch (c) {
            case '"':  app.put(`\"`); break;
            case '\\': app.put(`\\`); break;
            case '\b': app.put(`\b`); break;
            case '\f': app.put(`\f`); break;
            case '\n': app.put(`\n`); break;
            case '\r': app.put(`\r`); break;
            case '\t': app.put(`\t`); break;
            default:
                if (c < 0x20) {
                    app.put(`\u00`);
                    app.put("0123456789abcdef"[c >> 4]);
                    app.put("0123456789abcdef"[c & 0xF]);
                } else {
                    app.put(c);
                }
        }
    }
}

/* ============================================================================
 * Exception Type (compatible with std.json)
 * ============================================================================ */

/// JSON exception - compatible with std.json.JSONException
class JSONException : Exception {
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

/* ============================================================================
 * Parsing Functions
 * ============================================================================ */

// Thread-local parser for efficiency
private Parser* tlsParser;

private Parser* getParser() {
    if (tlsParser is null) {
        tlsParser = new Parser(0);
    }
    return tlsParser;
}

/**
 * Parse JSON string to JSONValue.
 *
 * Compatible with std.json.parseJSON.
 *
 * Params:
 *   json = JSON string to parse
 *
 * Returns:
 *   Parsed JSONValue
 *
 * Throws:
 *   JSONException on parse error
 */
JSONValue parseJSON(string json) {
    return parseJSON(cast(const(char)[]) json);
}

/// ditto
JSONValue parseJSON(const(char)[] json) {
    auto parser = getParser();
    if (parser is null || !parser.valid) {
        throw new JSONException("Failed to initialize parser");
    }
    
    auto doc = parser.parse(json);
    if (!doc.valid) {
        throw new JSONException("Parse error: " ~ doc.errorMessage.idup);
    }
    
    return convertValue(doc.root);
}

/// Convert native Value to JSONValue (copies data)
private JSONValue convertValue(Value val) {
    final switch (val.type) {
        case JsonType.null_:
            return JSONValue(null);
        
        case JsonType.bool_:
            return JSONValue(val.tryBool.valueOr(false));
        
        case JsonType.int64:
            return JSONValue(val.tryInt.valueOr(0L));
        
        case JsonType.uint64:
            return JSONValue(val.tryUint.valueOr(0UL));
        
        case JsonType.double_:
            return JSONValue(val.tryDouble.valueOr(0.0));
        
        case JsonType.string_:
            // Copy string to GC heap
            return JSONValue(val.tryString.valueOr("").idup);
        
        case JsonType.array:
            JSONValue[] arr;
            arr.reserve(val.length);
            foreach (elem; val) {
                arr ~= convertValue(elem);
            }
            return JSONValue(arr);
        
        case JsonType.object:
            JSONValue[string] obj;
            // Use explicit string key iteration for objects
            fj_object_iter iter;
            if (fj_object_iter_new(val.handle, &iter) == FjError.success) {
                scope(exit) fj_object_iter_free(iter);
                
                const(char)* key;
                size_t keyLen;
                fj_value fval;
                while (fj_object_iter_next(iter, &key, &keyLen, &fval)) {
                    obj[key[0 .. keyLen].idup] = convertValue(Value(fval));
                }
            }
            return JSONValue(obj);
    }
}

/* ============================================================================
 * Serialization Functions
 * ============================================================================ */

/**
 * Convert JSONValue to JSON string.
 *
 * Compatible with std.json.toJSON.
 */
string toJSON(JSONValue value) {
    return value.toString();
}

/// Convert to JSON with pretty printing option
string toJSON(JSONValue value, bool pretty) {
    if (!pretty) return value.toString();
    return toPrettyJSON(value);
}

/// Pretty print with custom indent
string toPrettyJSON(JSONValue value, string indent = "  ") {
    auto app = appender!string();
    value.toStringImpl(app, true, 0);
    return app.data;
}
