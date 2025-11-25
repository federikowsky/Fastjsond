/**
 * fastjsond - High-Performance JSON Parser for D
 *
 * A D wrapper around simdjson, the fastest JSON parser in the world.
 *
 * Two APIs are provided:
 *
 * 1. Native API (this module) - Zero-copy, maximum performance
 * 2. Std API (fastjsond.std) - Drop-in std.json replacement
 *
 * Native API Example:
 * ---
 * import fastjsond;
 *
 * // Create reusable parser
 * auto parser = Parser.create();
 *
 * // Parse JSON
 * auto doc = parser.parse(`{"name": "Alice", "age": 30}`);
 *
 * if (doc.valid) {
 *     auto root = doc.root;
 *     
 *     // Zero-copy string access
 *     const(char)[] name = root["name"].getString;
 *     long age = root["age"].getInt;
 *     
 *     // Safe access with Result
 *     if (auto email = root["email"].tryString) {
 *         writeln("Email: ", email.value);
 *     }
 *     
 *     // Iteration
 *     foreach (key, val; root) {
 *         writeln(key, ": ", val);
 *     }
 * }
 * ---
 *
 * Std API Example:
 * ---
 * import fastjsond.std;
 *
 * // Same API as std.json!
 * auto json = parseJSON(`{"name": "test"}`);
 * string name = json["name"].str;
 * ---
 *
 * Performance Tips:
 * - Reuse Parser instances across multiple parses
 * - Use native API for hot paths (zero-copy is much faster)
 * - Copy strings with .idup only when needed
 * - Use tryX() methods to avoid exception overhead
 *
 * Thread Safety:
 * - Parser is NOT thread-safe - use one per thread
 * - Document is NOT thread-safe - owned by creating thread
 * - Value borrows from Document - same thread only
 * - JSONValue (compat) is thread-safe after creation
 */
module fastjsond;

// Core types
public import fastjsond.types : JsonType, JsonError, JsonException, Result;

// Parser and Document
public import fastjsond.parser : Parser, validate, requiredPadding, activeImplementation;
public import fastjsond.document : Document;

// Value access
public import fastjsond.value : Value;
