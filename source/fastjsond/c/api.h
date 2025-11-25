/**
 * fastjsond C API
 * 
 * C wrapper around simdjson for D language bindings.
 * Provides opaque handles and C-compatible function signatures.
 */

#ifndef FASTJSOND_API_H
#define FASTJSOND_API_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Opaque Handle Types
 * ============================================================================ */

typedef struct fj_parser_s* fj_parser;
typedef struct fj_document_s* fj_document;

/* Value is passed by value (16 bytes) for efficiency */
typedef struct fj_value_s {
    void* impl;      /* Pointer to simdjson::dom::element or ondemand::value */
    void* doc;       /* Back-pointer to document for lifetime tracking */
} fj_value;

/* ============================================================================
 * Error Codes
 * ============================================================================ */

typedef enum fj_error_e {
    FJ_SUCCESS = 0,
    
    /* Parse errors */
    FJ_ERROR_CAPACITY,          /* Document too large */
    FJ_ERROR_MEMALLOC,          /* Memory allocation failed */
    FJ_ERROR_TAPE_ERROR,        /* Internal tape error */
    FJ_ERROR_DEPTH_ERROR,       /* Document too deep */
    FJ_ERROR_STRING_ERROR,      /* Invalid string */
    FJ_ERROR_T_ATOM_ERROR,      /* Invalid true atom */
    FJ_ERROR_F_ATOM_ERROR,      /* Invalid false atom */
    FJ_ERROR_N_ATOM_ERROR,      /* Invalid null atom */
    FJ_ERROR_NUMBER_ERROR,      /* Invalid number */
    FJ_ERROR_UTF8_ERROR,        /* Invalid UTF-8 */
    FJ_ERROR_UNINITIALIZED,     /* Parser not initialized */
    FJ_ERROR_EMPTY,             /* Empty input */
    FJ_ERROR_UNESCAPED_CHARS,   /* Unescaped control characters */
    FJ_ERROR_UNCLOSED_STRING,   /* Unclosed string */
    FJ_ERROR_UNSUPPORTED_ARCH,  /* Unsupported architecture */
    FJ_ERROR_INCORRECT_TYPE,    /* Wrong type for operation */
    FJ_ERROR_NUMBER_OUT_OF_RANGE, /* Number out of range */
    FJ_ERROR_INDEX_OUT_OF_BOUNDS, /* Array index out of bounds */
    FJ_ERROR_NO_SUCH_FIELD,     /* Object field not found */
    FJ_ERROR_IO_ERROR,          /* I/O error */
    FJ_ERROR_INVALID_JSON_POINTER, /* Invalid JSON pointer */
    FJ_ERROR_INVALID_URI_FRAGMENT, /* Invalid URI fragment */
    FJ_ERROR_UNEXPECTED_ERROR,  /* Unexpected error */
    FJ_ERROR_PARSER_IN_USE,     /* Parser already in use */
    FJ_ERROR_OUT_OF_ORDER_ITERATION, /* Iteration order error */
    FJ_ERROR_INSUFFICIENT_PADDING, /* Insufficient padding */
    FJ_ERROR_INCOMPLETE_ARRAY_OR_OBJECT, /* Incomplete structure */
    FJ_ERROR_SCALAR_DOCUMENT_AS_VALUE, /* Scalar as value */
    FJ_ERROR_OUT_OF_BOUNDS,     /* Out of bounds */
    FJ_ERROR_TRAILING_CONTENT,  /* Trailing content after JSON */
    
    FJ_ERROR_UNKNOWN = 255      /* Unknown error */
} fj_error;

/* ============================================================================
 * JSON Type
 * ============================================================================ */

typedef enum fj_type_e {
    FJ_TYPE_NULL = 0,
    FJ_TYPE_BOOL,
    FJ_TYPE_INT64,
    FJ_TYPE_UINT64,
    FJ_TYPE_DOUBLE,
    FJ_TYPE_STRING,
    FJ_TYPE_ARRAY,
    FJ_TYPE_OBJECT
} fj_type;

/* ============================================================================
 * Parser Functions
 * ============================================================================ */

/**
 * Create a new parser instance.
 * @param max_capacity Maximum document size (0 = default 4GB)
 * @return Parser handle, or NULL on failure
 */
fj_parser fj_parser_new(size_t max_capacity);

/**
 * Destroy parser and free resources.
 */
void fj_parser_free(fj_parser p);

/**
 * Parse JSON string.
 * @param p Parser instance
 * @param json JSON string (must remain valid until document is freed)
 * @param len Length of JSON string
 * @param doc Output document handle
 * @return Error code
 */
fj_error fj_parser_parse(fj_parser p, const char* json, size_t len, fj_document* doc);

/**
 * Parse JSON with padding.
 * For maximum performance, provide SIMDJSON_PADDING (64) bytes of padding.
 * @param p Parser instance  
 * @param json JSON string with padding
 * @param len Length of JSON (excluding padding)
 * @param doc Output document handle
 * @return Error code
 */
fj_error fj_parser_parse_padded(fj_parser p, const char* json, size_t len, fj_document* doc);

/* ============================================================================
 * Document Functions
 * ============================================================================ */

/**
 * Free document resources.
 */
void fj_document_free(fj_document doc);

/**
 * Get root value of document.
 */
fj_value fj_document_root(fj_document doc);

/**
 * Get error from document (after failed parse).
 */
fj_error fj_document_error(fj_document doc);

/**
 * Get error message string.
 * @return Static string, do not free
 */
const char* fj_error_message(fj_error err);

/* ============================================================================
 * Value Type Functions
 * ============================================================================ */

/**
 * Get type of value.
 */
fj_type fj_value_type(fj_value v);

/**
 * Type checking helpers.
 */
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

/**
 * Get boolean value.
 * @param v Value
 * @param out Output boolean
 * @return Error code (FJ_ERROR_INCORRECT_TYPE if not bool)
 */
fj_error fj_value_get_bool(fj_value v, bool* out);

/**
 * Get signed 64-bit integer.
 */
fj_error fj_value_get_int64(fj_value v, int64_t* out);

/**
 * Get unsigned 64-bit integer.
 */
fj_error fj_value_get_uint64(fj_value v, uint64_t* out);

/**
 * Get double-precision float.
 */
fj_error fj_value_get_double(fj_value v, double* out);

/**
 * Get string value (zero-copy).
 * @param v Value
 * @param out Output string pointer (points into JSON buffer!)
 * @param len Output string length
 * @return Error code
 * 
 * WARNING: Returned string is NOT null-terminated and points into
 * the original JSON buffer. Valid only while document exists.
 */
fj_error fj_value_get_string(fj_value v, const char** out, size_t* len);

/* ============================================================================
 * Object Access Functions
 * ============================================================================ */

/**
 * Get object field by key.
 * @param v Object value
 * @param key Field name (null-terminated)
 * @param out Output value
 * @return Error code (FJ_ERROR_NO_SUCH_FIELD if not found)
 */
fj_error fj_value_get_field(fj_value v, const char* key, fj_value* out);

/**
 * Get object field by key with length.
 */
fj_error fj_value_get_field_len(fj_value v, const char* key, size_t key_len, fj_value* out);

/**
 * Check if object has field.
 */
bool fj_value_has_field(fj_value v, const char* key);

/**
 * Get number of fields in object.
 */
fj_error fj_value_object_size(fj_value v, size_t* out);

/* ============================================================================
 * Array Access Functions
 * ============================================================================ */

/**
 * Get array element by index.
 * @param v Array value
 * @param idx Index
 * @param out Output value
 * @return Error code (FJ_ERROR_INDEX_OUT_OF_BOUNDS if invalid)
 */
fj_error fj_value_get_index(fj_value v, size_t idx, fj_value* out);

/**
 * Get array length.
 */
fj_error fj_value_array_size(fj_value v, size_t* out);

/* ============================================================================
 * Iteration Functions
 * ============================================================================ */

/* Opaque iterator handles */
typedef struct fj_array_iter_s* fj_array_iter;
typedef struct fj_object_iter_s* fj_object_iter;

/**
 * Create array iterator.
 * @param v Array value
 * @param iter Output iterator
 * @return Error code
 */
fj_error fj_array_iter_new(fj_value v, fj_array_iter* iter);

/**
 * Get next array element.
 * @param iter Iterator
 * @param out Output value
 * @return true if element available, false if end
 */
bool fj_array_iter_next(fj_array_iter iter, fj_value* out);

/**
 * Free array iterator.
 */
void fj_array_iter_free(fj_array_iter iter);

/**
 * Create object iterator.
 */
fj_error fj_object_iter_new(fj_value v, fj_object_iter* iter);

/**
 * Get next object field.
 * @param iter Iterator
 * @param key Output key (points into JSON buffer)
 * @param key_len Output key length
 * @param val Output value
 * @return true if field available, false if end
 */
bool fj_object_iter_next(fj_object_iter iter, const char** key, size_t* key_len, fj_value* val);

/**
 * Free object iterator.
 */
void fj_object_iter_free(fj_object_iter iter);

/* ============================================================================
 * Utility Functions  
 * ============================================================================ */

/**
 * Get required padding for SIMD operations.
 * Buffers should have this many extra bytes at the end.
 */
size_t fj_required_padding(void);

/**
 * Get simdjson implementation name.
 * @return Static string (e.g., "haswell", "westmere", "arm64")
 */
const char* fj_active_implementation(void);

/**
 * Minify JSON in-place.
 * @param json JSON buffer (will be modified)
 * @param len Input length
 * @param out_len Output length after minification
 * @return Error code
 */
fj_error fj_minify(char* json, size_t len, size_t* out_len);

/**
 * Validate JSON without full parse.
 * Faster than full parse if you only need to check validity.
 */
fj_error fj_validate(const char* json, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* FASTJSOND_API_H */
