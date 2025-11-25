/**
 * fastjsond - D Bindings to simdjson C API
 *
 * Low-level bindings. Use fastjsond.parser and fastjsond.value for 
 * the high-level D API.
 */
module fastjsond.bindings;

extern (C):
@nogc nothrow:

/* ============================================================================
 * Opaque Handle Types  
 * ============================================================================ */

alias fj_parser = void*;
alias fj_document = void*;

/// Value is passed by value (16 bytes) for efficiency
struct fj_value {
    void* impl;
    void* doc;
}

/* ============================================================================
 * Error Codes
 * ============================================================================ */

enum FjError : ubyte {
    success = 0,
    
    /* Parse errors */
    capacity,
    memalloc,
    tapeError,
    depthError,
    stringError,
    tAtomError,
    fAtomError,
    nAtomError,
    numberError,
    utf8Error,
    uninitialized,
    empty,
    unescapedChars,
    unclosedString,
    unsupportedArch,
    incorrectType,
    numberOutOfRange,
    indexOutOfBounds,
    noSuchField,
    ioError,
    invalidJsonPointer,
    invalidUriFragment,
    unexpectedError,
    parserInUse,
    outOfOrderIteration,
    insufficientPadding,
    incompleteArrayOrObject,
    scalarDocumentAsValue,
    outOfBounds,
    trailingContent,
    
    unknown = 255
}

/* ============================================================================
 * JSON Type
 * ============================================================================ */

enum FjType : ubyte {
    null_ = 0,
    bool_,
    int64,
    uint64,
    double_,
    string_,
    array,
    object
}

/* ============================================================================
 * Iterator Handles
 * ============================================================================ */

alias fj_array_iter = void*;
alias fj_object_iter = void*;

/* ============================================================================
 * Parser Functions
 * ============================================================================ */

fj_parser fj_parser_new(size_t max_capacity);
void fj_parser_free(fj_parser p);
FjError fj_parser_parse(fj_parser p, const(char)* json, size_t len, fj_document* doc);
FjError fj_parser_parse_padded(fj_parser p, const(char)* json, size_t len, fj_document* doc);

/* ============================================================================
 * Document Functions
 * ============================================================================ */

void fj_document_free(fj_document doc);
fj_value fj_document_root(fj_document doc);
FjError fj_document_error(fj_document doc);
const(char)* fj_error_message(FjError err);

/* ============================================================================
 * Value Type Functions
 * ============================================================================ */

FjType fj_value_type(fj_value v);
bool fj_value_is_null(fj_value v);
bool fj_value_is_bool(fj_value v);
bool fj_value_is_int64(fj_value v);
bool fj_value_is_uint64(fj_value v);
bool fj_value_is_double(fj_value v);
bool fj_value_is_number(fj_value v);
bool fj_value_is_string(fj_value v);
bool fj_value_is_array(fj_value v);
bool fj_value_is_object(fj_value v);

/* ============================================================================
 * Value Extraction Functions
 * ============================================================================ */

FjError fj_value_get_bool(fj_value v, bool* out_);
FjError fj_value_get_int64(fj_value v, long* out_);
FjError fj_value_get_uint64(fj_value v, ulong* out_);
FjError fj_value_get_double(fj_value v, double* out_);
FjError fj_value_get_string(fj_value v, const(char)** out_, size_t* len);

/* ============================================================================
 * Object Access Functions  
 * ============================================================================ */

FjError fj_value_get_field(fj_value v, const(char)* key, fj_value* out_);
FjError fj_value_get_field_len(fj_value v, const(char)* key, size_t key_len, fj_value* out_);
bool fj_value_has_field(fj_value v, const(char)* key);
FjError fj_value_object_size(fj_value v, size_t* out_);

/* ============================================================================
 * Array Access Functions
 * ============================================================================ */

FjError fj_value_get_index(fj_value v, size_t idx, fj_value* out_);
FjError fj_value_array_size(fj_value v, size_t* out_);

/* ============================================================================
 * Iteration Functions
 * ============================================================================ */

FjError fj_array_iter_new(fj_value v, fj_array_iter* iter);
bool fj_array_iter_next(fj_array_iter iter, fj_value* out_);
void fj_array_iter_free(fj_array_iter iter);

FjError fj_object_iter_new(fj_value v, fj_object_iter* iter);
bool fj_object_iter_next(fj_object_iter iter, const(char)** key, size_t* key_len, fj_value* val);
void fj_object_iter_free(fj_object_iter iter);

/* ============================================================================
 * Utility Functions
 * ============================================================================ */

size_t fj_required_padding();
const(char)* fj_active_implementation();
FjError fj_minify(char* json, size_t len, size_t* out_len);
FjError fj_validate(const(char)* json, size_t len);
