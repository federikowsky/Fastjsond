/**
 * fastjsond - Parser Type
 *
 * Reusable JSON parser. Holds internal buffers for efficiency.
 * Create one per thread (not thread-safe).
 */
module fastjsond.parser;

import fastjsond.types;
import fastjsond.document;
import fastjsond.bindings;

/**
 * JSON Parser.
 *
 * Reusable parser instance. Holds internal buffers that are reused
 * across parse calls for efficiency.
 *
 * Thread-safety: NOT thread-safe. Use one Parser per thread.
 *
 * Example:
 * ---
 * // Create parser (reuse for multiple parses)
 * auto parser = Parser();
 *
 * // Parse JSON
 * auto doc1 = parser.parse(`{"a": 1}`);
 * auto doc2 = parser.parse(`{"b": 2}`);  // Reuses internal buffers
 *
 * // Access values
 * if (doc1.valid) {
 *     writeln(doc1.root["a"].getInt);  // 1
 * }
 * ---
 */
struct Parser {
    private fj_parser handle;
    
    /**
     * Create a new parser.
     *
     * Params:
     *   maxCapacity = Maximum document size in bytes (0 = default ~4GB)
     */
    this(size_t maxCapacity) @nogc nothrow {
        handle = fj_parser_new(maxCapacity);
    }
    
    /// Create parser with default capacity
    static Parser create() @nogc nothrow {
        Parser p;
        p.handle = fj_parser_new(0);
        return p;
    }
    
    /// Destructor
    ~this() @nogc nothrow {
        if (handle !is null) {
            fj_parser_free(handle);
            handle = null;
        }
    }
    
    /// Disable copy (move-only for safety)
    @disable this(this);
    
    /// Move assignment
    ref Parser opAssign(return scope Parser rhs) return @nogc nothrow {
        if (handle !is null) {
            fj_parser_free(handle);
        }
        handle = rhs.handle;
        rhs.handle = null;
        return this;
    }
    
    /* =========================================================================
     * Parsing
     * ========================================================================= */
    
    /**
     * Parse JSON string.
     *
     * The input string is NOT copied - ensure it remains valid while
     * accessing zero-copy string values from the resulting Document.
     *
     * Params:
     *   json = JSON string to parse
     *
     * Returns:
     *   Document containing parsed JSON, or error document if parsing failed.
     */
    Document parse(const(char)[] json) @nogc nothrow {
        if (handle is null) {
            return Document.withError(JsonError.uninitialized);
        }
        
        if (json.length == 0) {
            return Document.withError(JsonError.empty);
        }
        
        fj_document doc;
        auto err = fj_parser_parse(handle, json.ptr, json.length, &doc);
        
        if (err != FjError.success) {
            return Document.withError(cast(JsonError) err);
        }
        
        return Document(doc);
    }
    
    /// Parse from string (convenience overload)
    Document parse(string json) @nogc nothrow {
        return parse(cast(const(char)[]) json);
    }
    
    /// Parse from ubyte array
    Document parse(const(ubyte)[] json) @nogc nothrow {
        return parse(cast(const(char)[]) json);
    }
    
    /**
     * Parse with pre-padded buffer.
     *
     * For maximum performance, provide a buffer with SIMDJSON_PADDING (64)
     * extra bytes at the end. This avoids an internal copy.
     *
     * Params:
     *   json = JSON string with padding bytes after
     *
     * Returns:
     *   Parsed Document
     */
    Document parsePadded(const(char)[] json) @nogc nothrow {
        if (handle is null) {
            return Document.withError(JsonError.uninitialized);
        }
        
        if (json.length == 0) {
            return Document.withError(JsonError.empty);
        }
        
        fj_document doc;
        auto err = fj_parser_parse_padded(handle, json.ptr, json.length, &doc);
        
        if (err != FjError.success) {
            return Document.withError(cast(JsonError) err);
        }
        
        return Document(doc);
    }
    
    /* =========================================================================
     * Utilities
     * ========================================================================= */
    
    /// Check if parser is valid
    bool valid() const @nogc nothrow {
        return handle !is null;
    }
    
    /// Implicit bool conversion
    bool opCast(T : bool)() const @nogc nothrow {
        return valid;
    }
}

/* ============================================================================
 * Module-Level Convenience Functions
 * ============================================================================ */

/// Thread-local parser instance for convenience functions
private Parser* tlsParser;

/// Get thread-local parser (lazy initialization)
private Parser* getThreadLocalParser() @nogc nothrow {
    if (tlsParser is null) {
        // Can't use new in @nogc, need to handle this differently
        // For now, just return null and let caller handle it
        return null;
    }
    return tlsParser;
}

/**
 * Quickly validate JSON without full parse.
 *
 * Faster than full parse if you only need to check validity.
 *
 * Params:
 *   json = JSON string to validate
 *
 * Returns:
 *   JsonError.none if valid, error code otherwise
 */
JsonError validate(const(char)[] json) @nogc nothrow {
    return cast(JsonError) fj_validate(json.ptr, json.length);
}

/**
 * Get required padding for SIMD optimization.
 *
 * When using parsePadded(), ensure your buffer has this many
 * extra bytes at the end.
 */
size_t requiredPadding() @nogc nothrow {
    return fj_required_padding();
}

/**
 * Get active SIMD implementation name.
 *
 * Returns: "haswell", "westmere", "arm64", "fallback", etc.
 */
const(char)[] activeImplementation() @nogc nothrow {
    import core.stdc.string : strlen;
    auto ptr = fj_active_implementation();
    if (ptr is null) return "unknown";
    return ptr[0 .. strlen(ptr)];
}
