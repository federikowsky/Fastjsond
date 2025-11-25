/**
 * fastjsond - Document Type
 *
 * Represents a parsed JSON document. Owns the parsed data.
 * Move-only semantics to prevent accidental copies.
 */
module fastjsond.document;

import fastjsond.types;
import fastjsond.value;
import fastjsond.bindings;

/**
 * Parsed JSON Document.
 *
 * Owns the parsed JSON data. Value references borrow from this Document
 * and become invalid when the Document is destroyed.
 *
 * Move-only semantics: cannot be copied, only moved.
 *
 * Example:
 * ---
 * auto parser = Parser();
 * auto doc = parser.parse(`{"name": "test"}`);
 *
 * if (doc.valid) {
 *     auto root = doc.root;
 *     writeln(root["name"].getString);
 * } else {
 *     writeln("Error: ", doc.errorMessage);
 * }
 * ---
 */
struct Document {
    private fj_document handle;
    private JsonError _error;
    
    /// Construct from C handle
    package this(fj_document h, JsonError err = JsonError.none) @nogc nothrow {
        handle = h;
        _error = err;
    }
    
    /// Construct error document
    package static Document withError(JsonError err) @nogc nothrow {
        Document d;
        d.handle = null;
        d._error = err;
        return d;
    }
    
    /// Destructor - free document resources
    ~this() @nogc nothrow {
        if (handle !is null) {
            fj_document_free(handle);
            handle = null;
        }
    }
    
    /// Disable copy (move-only)
    @disable this(this);
    
    /// Move assignment
    ref Document opAssign(return scope Document rhs) return @nogc nothrow {
        if (handle !is null) {
            fj_document_free(handle);
        }
        handle = rhs.handle;
        _error = rhs._error;
        rhs.handle = null;
        return this;
    }
    
    /* =========================================================================
     * Status
     * ========================================================================= */
    
    /// Check if document was parsed successfully
    bool valid() const @nogc nothrow {
        return handle !is null && _error == JsonError.none;
    }
    
    /// Implicit bool conversion
    bool opCast(T : bool)() const @nogc nothrow {
        return valid;
    }
    
    /// Get error code (none if valid)
    JsonError error() const @nogc nothrow {
        return _error;
    }
    
    /// Get human-readable error message
    const(char)[] errorMessage() const @nogc nothrow {
        return _error.errorMessage;
    }
    
    /* =========================================================================
     * Access
     * ========================================================================= */
    
    /**
     * Get root value of the document.
     *
     * Returns a Value that borrows from this Document.
     * Valid only while Document exists.
     */
    Value root() @nogc nothrow {
        if (handle is null) {
            return Value(fj_value(null, null));
        }
        return Value(fj_document_root(handle));
    }
    
    /// Convenience: direct indexing into root object
    Value opIndex(const(char)[] key) {
        return root[key];
    }
    
    /// Convenience: direct indexing into root array
    Value opIndex(size_t idx) {
        return root[idx];
    }
}
