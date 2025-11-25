/**
 * fastjsond C API Implementation
 * 
 * C wrapper around simdjson for D language bindings.
 */

#include "api.h"
#include "simdjson.h"

#include <new>
#include <cstring>

using namespace simdjson;

/* ============================================================================
 * Internal Structures
 * ============================================================================ */

struct fj_parser_s {
    dom::parser parser;
    
    fj_parser_s(size_t max_capacity) {
        if (max_capacity > 0) {
            parser.set_max_capacity(max_capacity);
        }
    }
};

struct fj_document_s {
    dom::element root;
    fj_error error;
    
    fj_document_s() : error(FJ_SUCCESS) {}
};

struct fj_array_iter_s {
    dom::array array;
    dom::array::iterator current;
    dom::array::iterator end;
    
    fj_array_iter_s(dom::array arr) : array(arr) {
        current = array.begin();
        end = array.end();
    }
};

struct fj_object_iter_s {
    dom::object object;
    dom::object::iterator current;
    dom::object::iterator end;
    
    fj_object_iter_s(dom::object obj) : object(obj) {
        current = object.begin();
        end = object.end();
    }
};

/* ============================================================================
 * Error Mapping
 * ============================================================================ */

static fj_error map_error(error_code err) {
    switch (err) {
        case SUCCESS: return FJ_SUCCESS;
        case CAPACITY: return FJ_ERROR_CAPACITY;
        case MEMALLOC: return FJ_ERROR_MEMALLOC;
        case TAPE_ERROR: return FJ_ERROR_TAPE_ERROR;
        case DEPTH_ERROR: return FJ_ERROR_DEPTH_ERROR;
        case STRING_ERROR: return FJ_ERROR_STRING_ERROR;
        case T_ATOM_ERROR: return FJ_ERROR_T_ATOM_ERROR;
        case F_ATOM_ERROR: return FJ_ERROR_F_ATOM_ERROR;
        case N_ATOM_ERROR: return FJ_ERROR_N_ATOM_ERROR;
        case NUMBER_ERROR: return FJ_ERROR_NUMBER_ERROR;
        case UTF8_ERROR: return FJ_ERROR_UTF8_ERROR;
        case UNINITIALIZED: return FJ_ERROR_UNINITIALIZED;
        case EMPTY: return FJ_ERROR_EMPTY;
        case UNESCAPED_CHARS: return FJ_ERROR_UNESCAPED_CHARS;
        case UNCLOSED_STRING: return FJ_ERROR_UNCLOSED_STRING;
        case UNSUPPORTED_ARCHITECTURE: return FJ_ERROR_UNSUPPORTED_ARCH;
        case INCORRECT_TYPE: return FJ_ERROR_INCORRECT_TYPE;
        case NUMBER_OUT_OF_RANGE: return FJ_ERROR_NUMBER_OUT_OF_RANGE;
        case INDEX_OUT_OF_BOUNDS: return FJ_ERROR_INDEX_OUT_OF_BOUNDS;
        case NO_SUCH_FIELD: return FJ_ERROR_NO_SUCH_FIELD;
        case IO_ERROR: return FJ_ERROR_IO_ERROR;
        case INVALID_JSON_POINTER: return FJ_ERROR_INVALID_JSON_POINTER;
        case INVALID_URI_FRAGMENT: return FJ_ERROR_INVALID_URI_FRAGMENT;
        case UNEXPECTED_ERROR: return FJ_ERROR_UNEXPECTED_ERROR;
        case PARSER_IN_USE: return FJ_ERROR_PARSER_IN_USE;
        case OUT_OF_ORDER_ITERATION: return FJ_ERROR_OUT_OF_ORDER_ITERATION;
        case INSUFFICIENT_PADDING: return FJ_ERROR_INSUFFICIENT_PADDING;
        case INCOMPLETE_ARRAY_OR_OBJECT: return FJ_ERROR_INCOMPLETE_ARRAY_OR_OBJECT;
        case SCALAR_DOCUMENT_AS_VALUE: return FJ_ERROR_SCALAR_DOCUMENT_AS_VALUE;
        case OUT_OF_BOUNDS: return FJ_ERROR_OUT_OF_BOUNDS;
        case TRAILING_CONTENT: return FJ_ERROR_TRAILING_CONTENT;
        default: return FJ_ERROR_UNKNOWN;
    }
}

static fj_type map_type(dom::element_type t) {
    switch (t) {
        case dom::element_type::NULL_VALUE: return FJ_TYPE_NULL;
        case dom::element_type::BOOL: return FJ_TYPE_BOOL;
        case dom::element_type::INT64: return FJ_TYPE_INT64;
        case dom::element_type::UINT64: return FJ_TYPE_UINT64;
        case dom::element_type::DOUBLE: return FJ_TYPE_DOUBLE;
        case dom::element_type::STRING: return FJ_TYPE_STRING;
        case dom::element_type::ARRAY: return FJ_TYPE_ARRAY;
        case dom::element_type::OBJECT: return FJ_TYPE_OBJECT;
        default: return FJ_TYPE_NULL;
    }
}

/* ============================================================================
 * Parser Functions
 * ============================================================================ */

extern "C" {

fj_parser fj_parser_new(size_t max_capacity) {
    try {
        return new fj_parser_s(max_capacity);
    } catch (...) {
        return nullptr;
    }
}

void fj_parser_free(fj_parser p) {
    delete p;
}

fj_error fj_parser_parse(fj_parser p, const char* json, size_t len, fj_document* doc) {
    if (!p || !json || !doc) {
        return FJ_ERROR_UNINITIALIZED;
    }
    
    try {
        auto result = p->parser.parse(json, len);
        if (result.error()) {
            *doc = nullptr;
            return map_error(result.error());
        }
        
        auto d = new fj_document_s();
        d->root = result.value();
        d->error = FJ_SUCCESS;
        *doc = d;
        return FJ_SUCCESS;
    } catch (...) {
        *doc = nullptr;
        return FJ_ERROR_UNEXPECTED_ERROR;
    }
}

fj_error fj_parser_parse_padded(fj_parser p, const char* json, size_t len, fj_document* doc) {
    /* For padded input, simdjson can skip the copy */
    return fj_parser_parse(p, json, len, doc);
}

/* ============================================================================
 * Document Functions
 * ============================================================================ */

void fj_document_free(fj_document doc) {
    delete doc;
}

fj_value fj_document_root(fj_document doc) {
    fj_value v;
    v.impl = doc ? reinterpret_cast<void*>(&doc->root) : nullptr;
    v.doc = doc;
    return v;
}

fj_error fj_document_error(fj_document doc) {
    return doc ? doc->error : FJ_ERROR_UNINITIALIZED;
}

const char* fj_error_message(fj_error err) {
    static const char* messages[] = {
        "Success",
        "Document too large",
        "Memory allocation failed",
        "Internal tape error",
        "Document too deep",
        "Invalid string",
        "Invalid 'true' atom",
        "Invalid 'false' atom",
        "Invalid 'null' atom",
        "Invalid number",
        "Invalid UTF-8 encoding",
        "Parser not initialized",
        "Empty input",
        "Unescaped control characters in string",
        "Unclosed string",
        "Unsupported architecture",
        "Incorrect type",
        "Number out of range",
        "Array index out of bounds",
        "Object field not found",
        "I/O error",
        "Invalid JSON pointer",
        "Invalid URI fragment",
        "Unexpected error",
        "Parser already in use",
        "Out of order iteration",
        "Insufficient padding",
        "Incomplete array or object",
        "Scalar document as value",
        "Out of bounds",
        "Trailing content after JSON"
    };
    
    if (err == FJ_ERROR_UNKNOWN || err > FJ_ERROR_TRAILING_CONTENT) {
        return "Unknown error";
    }
    return messages[err];
}

/* ============================================================================
 * Value Type Functions
 * ============================================================================ */

static inline dom::element* get_element(fj_value v) {
    return reinterpret_cast<dom::element*>(v.impl);
}

fj_type fj_value_type(fj_value v) {
    if (!v.impl) return FJ_TYPE_NULL;
    return map_type(get_element(v)->type());
}

bool fj_value_is_null(fj_value v) {
    return v.impl && get_element(v)->is_null();
}

bool fj_value_is_bool(fj_value v) {
    return v.impl && get_element(v)->is_bool();
}

bool fj_value_is_int64(fj_value v) {
    return v.impl && get_element(v)->is_int64();
}

bool fj_value_is_uint64(fj_value v) {
    return v.impl && get_element(v)->is_uint64();
}

bool fj_value_is_double(fj_value v) {
    return v.impl && get_element(v)->is_double();
}

bool fj_value_is_number(fj_value v) {
    if (!v.impl) return false;
    auto t = get_element(v)->type();
    return t == dom::element_type::INT64 || 
           t == dom::element_type::UINT64 || 
           t == dom::element_type::DOUBLE;
}

bool fj_value_is_string(fj_value v) {
    return v.impl && get_element(v)->is_string();
}

bool fj_value_is_array(fj_value v) {
    return v.impl && get_element(v)->is_array();
}

bool fj_value_is_object(fj_value v) {
    return v.impl && get_element(v)->is_object();
}

/* ============================================================================
 * Value Extraction Functions
 * ============================================================================ */

fj_error fj_value_get_bool(fj_value v, bool* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_bool();
    if (result.error()) return map_error(result.error());
    *out = result.value();
    return FJ_SUCCESS;
}

fj_error fj_value_get_int64(fj_value v, int64_t* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_int64();
    if (result.error()) return map_error(result.error());
    *out = result.value();
    return FJ_SUCCESS;
}

fj_error fj_value_get_uint64(fj_value v, uint64_t* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_uint64();
    if (result.error()) return map_error(result.error());
    *out = result.value();
    return FJ_SUCCESS;
}

fj_error fj_value_get_double(fj_value v, double* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_double();
    if (result.error()) return map_error(result.error());
    *out = result.value();
    return FJ_SUCCESS;
}

fj_error fj_value_get_string(fj_value v, const char** out, size_t* len) {
    if (!v.impl || !out || !len) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_string();
    if (result.error()) return map_error(result.error());
    std::string_view sv = result.value();
    *out = sv.data();
    *len = sv.size();
    return FJ_SUCCESS;
}

/* ============================================================================
 * Object Access Functions
 * ============================================================================ */

fj_error fj_value_get_field(fj_value v, const char* key, fj_value* out) {
    if (!v.impl || !key || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto obj_result = get_element(v)->get_object();
    if (obj_result.error()) return map_error(obj_result.error());
    
    auto field_result = obj_result.value()[key];
    if (field_result.error()) return map_error(field_result.error());
    
    /* Store element in document's memory */
    static thread_local dom::element stored_elements[256];
    static thread_local size_t stored_idx = 0;
    stored_idx = (stored_idx + 1) % 256;
    stored_elements[stored_idx] = field_result.value();
    
    out->impl = &stored_elements[stored_idx];
    out->doc = v.doc;
    return FJ_SUCCESS;
}

fj_error fj_value_get_field_len(fj_value v, const char* key, size_t key_len, fj_value* out) {
    if (!v.impl || !key || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto obj_result = get_element(v)->get_object();
    if (obj_result.error()) return map_error(obj_result.error());
    
    auto field_result = obj_result.value()[std::string_view(key, key_len)];
    if (field_result.error()) return map_error(field_result.error());
    
    static thread_local dom::element stored_elements[256];
    static thread_local size_t stored_idx = 0;
    stored_idx = (stored_idx + 1) % 256;
    stored_elements[stored_idx] = field_result.value();
    
    out->impl = &stored_elements[stored_idx];
    out->doc = v.doc;
    return FJ_SUCCESS;
}

bool fj_value_has_field(fj_value v, const char* key) {
    if (!v.impl || !key) return false;
    
    auto obj_result = get_element(v)->get_object();
    if (obj_result.error()) return false;
    
    auto field_result = obj_result.value()[key];
    return !field_result.error();
}

fj_error fj_value_object_size(fj_value v, size_t* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_object();
    if (result.error()) return map_error(result.error());
    *out = result.value().size();
    return FJ_SUCCESS;
}

/* ============================================================================
 * Array Access Functions
 * ============================================================================ */

fj_error fj_value_get_index(fj_value v, size_t idx, fj_value* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto arr_result = get_element(v)->get_array();
    if (arr_result.error()) return map_error(arr_result.error());
    
    auto elem_result = arr_result.value().at(idx);
    if (elem_result.error()) return map_error(elem_result.error());
    
    static thread_local dom::element stored_elements[256];
    static thread_local size_t stored_idx = 0;
    stored_idx = (stored_idx + 1) % 256;
    stored_elements[stored_idx] = elem_result.value();
    
    out->impl = &stored_elements[stored_idx];
    out->doc = v.doc;
    return FJ_SUCCESS;
}

fj_error fj_value_array_size(fj_value v, size_t* out) {
    if (!v.impl || !out) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_array();
    if (result.error()) return map_error(result.error());
    *out = result.value().size();
    return FJ_SUCCESS;
}

/* ============================================================================
 * Iteration Functions
 * ============================================================================ */

fj_error fj_array_iter_new(fj_value v, fj_array_iter* iter) {
    if (!v.impl || !iter) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_array();
    if (result.error()) return map_error(result.error());
    
    try {
        *iter = new fj_array_iter_s(result.value());
        return FJ_SUCCESS;
    } catch (...) {
        return FJ_ERROR_MEMALLOC;
    }
}

bool fj_array_iter_next(fj_array_iter iter, fj_value* out) {
    if (!iter || !out) return false;
    
    if (iter->current == iter->end) return false;
    
    static thread_local dom::element stored_elements[256];
    static thread_local size_t stored_idx = 0;
    stored_idx = (stored_idx + 1) % 256;
    stored_elements[stored_idx] = *iter->current;
    
    out->impl = &stored_elements[stored_idx];
    out->doc = nullptr;
    
    ++iter->current;
    return true;
}

void fj_array_iter_free(fj_array_iter iter) {
    delete iter;
}

fj_error fj_object_iter_new(fj_value v, fj_object_iter* iter) {
    if (!v.impl || !iter) return FJ_ERROR_UNINITIALIZED;
    
    auto result = get_element(v)->get_object();
    if (result.error()) return map_error(result.error());
    
    try {
        *iter = new fj_object_iter_s(result.value());
        return FJ_SUCCESS;
    } catch (...) {
        return FJ_ERROR_MEMALLOC;
    }
}

bool fj_object_iter_next(fj_object_iter iter, const char** key, size_t* key_len, fj_value* val) {
    if (!iter || !key || !key_len || !val) return false;
    
    if (iter->current == iter->end) return false;
    
    auto field = *iter->current;
    std::string_view k = field.key;
    *key = k.data();
    *key_len = k.size();
    
    static thread_local dom::element stored_elements[256];
    static thread_local size_t stored_idx = 0;
    stored_idx = (stored_idx + 1) % 256;
    stored_elements[stored_idx] = field.value;
    
    val->impl = &stored_elements[stored_idx];
    val->doc = nullptr;
    
    ++iter->current;
    return true;
}

void fj_object_iter_free(fj_object_iter iter) {
    delete iter;
}

/* ============================================================================
 * Utility Functions
 * ============================================================================ */

size_t fj_required_padding(void) {
    return SIMDJSON_PADDING;
}

/* Store implementation name statically to avoid returning dangling pointer */
static const char* cached_impl_name = nullptr;

const char* fj_active_implementation(void) {
    if (cached_impl_name == nullptr) {
        /* Get the implementation once and cache it */
        static std::string impl_name = simdjson::get_active_implementation()->name();
        cached_impl_name = impl_name.c_str();
    }
    return cached_impl_name;
}

fj_error fj_minify(char* json, size_t len, size_t* out_len) {
    if (!json || !out_len) return FJ_ERROR_UNINITIALIZED;
    
    auto err = simdjson::minify(json, len, json, *out_len);
    return map_error(err);
}

fj_error fj_validate(const char* json, size_t len) {
    if (!json) return FJ_ERROR_UNINITIALIZED;
    
    dom::parser parser;
    auto result = parser.parse(json, len);
    return map_error(result.error());
}

} /* extern "C" */
