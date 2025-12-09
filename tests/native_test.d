/**
 * fastjsond - Native API Tests
 */
module tests.native_test;

import fastjsond;
import std.stdio;

void main() {
    writeln("========================================");
    writeln("  fastjsond Native API Tests");
    writeln("========================================");
    writeln();
    
    int passed = 0;
    int failed = 0;
    
    void test(string name, bool delegate() fn) {
        write("  ", name, "... ");
        stdout.flush();
        try {
            if (fn()) {
                writeln("✓ PASS");
                passed++;
            } else {
                writeln("✗ FAIL");
                failed++;
            }
        } catch (Exception e) {
            writeln("✗ ERROR: ", e.msg);
            failed++;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // Parser Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln("Parser Tests:");
    
    test("Create parser", {
        auto parser = Parser.create();
        return parser.valid;
    });
    
    test("Parse simple object", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"name": "test"}`);
        return doc.valid;
    });
    
    test("Parse empty input fails", {
        auto parser = Parser.create();
        auto doc = parser.parse("");
        return !doc.valid && doc.error == JsonError.empty;
    });
    
    test("Parse invalid JSON fails", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{invalid}`);
        return !doc.valid;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Value Type Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Value Type Tests:");
    
    test("Null type", {
        auto parser = Parser.create();
        auto doc = parser.parse(`null`);
        return doc.valid && doc.root.isNull;
    });
    
    test("Boolean true", {
        auto parser = Parser.create();
        auto doc = parser.parse(`true`);
        return doc.valid && doc.root.isBool && doc.root.getBool == true;
    });
    
    test("Boolean false", {
        auto parser = Parser.create();
        auto doc = parser.parse(`false`);
        return doc.valid && doc.root.isBool && doc.root.getBool == false;
    });
    
    test("Integer", {
        auto parser = Parser.create();
        auto doc = parser.parse(`42`);
        return doc.valid && doc.root.isInt && doc.root.getInt == 42;
    });
    
    test("Negative integer", {
        auto parser = Parser.create();
        auto doc = parser.parse(`-123`);
        return doc.valid && doc.root.isInt && doc.root.getInt == -123;
    });
    
    test("Double", {
        auto parser = Parser.create();
        auto doc = parser.parse(`3.14159`);
        if (!doc.valid) return false;
        auto val = doc.root.getDouble;
        return val > 3.14 && val < 3.15;
    });
    
    test("String", {
        auto parser = Parser.create();
        auto doc = parser.parse(`"hello world"`);
        return doc.valid && doc.root.isString && doc.root.getString == "hello world";
    });
    
    test("String with escapes", {
        auto parser = Parser.create();
        auto doc = parser.parse(`"line1\nline2"`);
        return doc.valid && doc.root.getString == "line1\nline2";
    });
    
    test("Empty array", {
        auto parser = Parser.create();
        auto doc = parser.parse(`[]`);
        return doc.valid && doc.root.isArray && doc.root.length == 0;
    });
    
    test("Array with values", {
        auto parser = Parser.create();
        auto doc = parser.parse(`[1, 2, 3]`);
        if (!doc.valid) return false;
        if (!doc.root.isArray) return false;
        if (doc.root.length != 3) return false;
        return doc.root[0].getInt == 1 && 
               doc.root[1].getInt == 2 && 
               doc.root[2].getInt == 3;
    });
    
    test("Empty object", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{}`);
        return doc.valid && doc.root.isObject && doc.root.length == 0;
    });
    
    test("Object with values", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"a": 1, "b": 2}`);
        if (!doc.valid) return false;
        if (!doc.root.isObject) return false;
        return doc.root["a"].getInt == 1 && doc.root["b"].getInt == 2;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Nested Access Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Nested Access Tests:");
    
    test("Nested object access", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"user": {"name": "Alice", "age": 30}}`);
        if (!doc.valid) return false;
        return doc.root["user"]["name"].getString == "Alice" &&
               doc.root["user"]["age"].getInt == 30;
    });
    
    test("Nested array access", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"matrix": [[1, 2], [3, 4]]}`);
        if (!doc.valid) return false;
        return doc.root["matrix"][0][0].getInt == 1 &&
               doc.root["matrix"][1][1].getInt == 4;
    });
    
    test("hasKey check", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"exists": true}`);
        if (!doc.valid) return false;
        return doc.root.hasKey("exists") && !doc.root.hasKey("missing");
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Result Type Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Result Type Tests:");
    
    test("tryInt success", {
        auto parser = Parser.create();
        auto doc = parser.parse(`42`);
        auto result = doc.root.tryInt;
        return result.ok && result.value == 42;
    });
    
    test("tryInt failure", {
        auto parser = Parser.create();
        auto doc = parser.parse(`"not a number"`);
        auto result = doc.root.tryInt;
        return !result.ok && result.error == JsonError.incorrectType;
    });
    
    test("valueOr default", {
        auto parser = Parser.create();
        auto doc = parser.parse(`"text"`);
        auto val = doc.root.tryInt.valueOr(99);
        return val == 99;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Iteration Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Iteration Tests:");
    
    test("Array iteration", {
        auto parser = Parser.create();
        auto doc = parser.parse(`[10, 20, 30]`);
        if (!doc.valid) return false;
        
        long sum = 0;
        foreach (elem; doc.root) {
            sum += elem.getInt;
        }
        return sum == 60;
    });
    
    test("Array iteration with index", {
        auto parser = Parser.create();
        auto doc = parser.parse(`["a", "b", "c"]`);
        if (!doc.valid) return false;
        
        size_t count = 0;
        foreach (size_t i, elem; doc.root) {
            count++;
            if (i == 0 && elem.getString != "a") return false;
            if (i == 1 && elem.getString != "b") return false;
            if (i == 2 && elem.getString != "c") return false;
        }
        return count == 3;
    });
    
    test("Object iteration", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"x": 1, "y": 2, "z": 3}`);
        if (!doc.valid) return false;
        
        long sum = 0;
        foreach (const(char)[] key, val; doc.root) {
            sum += val.getInt;
        }
        return sum == 6;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Utility Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Utility Tests:");
    
    test("Validate valid JSON", {
        return validate(`{"valid": true}`) == JsonError.none;
    });
    
    test("Validate invalid JSON", {
        return validate(`{invalid}`) != JsonError.none;
    });
    
    test("Required padding > 0", {
        return requiredPadding() > 0;
    });
    
    test("Active implementation", {
        auto impl = activeImplementation();
        return impl.length > 0;
    });
    
    test("Parse padded buffer API", {
        auto parser = Parser.create();
        
        // Test that parsePadded() API exists and works
        // Note: Current implementation calls parse() internally, so it works with regular JSON
        // This test verifies the API is functional
        string jsonStr = `{"test": 42}`;
        
        // For now, test with regular string (parsePadded will work because it calls parse internally)
        // In a full implementation, this would require a properly padded buffer
        auto doc = parser.parsePadded(jsonStr);
        if (!doc.valid) return false;
        return doc.root["test"].getInt == 42;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Complex JSON Test
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Complex JSON Test:");
    
    test("Parse complex JSON", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{
            "name": "fastjsond",
            "version": 1,
            "features": ["fast", "safe", "zero-copy"],
            "config": {
                "simd": true,
                "threads": 4,
                "nested": {
                    "deep": {
                        "value": 42
                    }
                }
            },
            "empty": null,
            "pi": 3.14159,
            "negative": -999
        }`);
        
        if (!doc.valid) return false;
        
        auto root = doc.root;
        
        // Test various types
        if (root["name"].getString != "fastjsond") return false;
        if (root["version"].getInt != 1) return false;
        if (root["features"].length != 3) return false;
        if (root["features"][0].getString != "fast") return false;
        if (root["config"]["simd"].getBool != true) return false;
        if (root["config"]["threads"].getInt != 4) return false;
        if (root["config"]["nested"]["deep"]["value"].getInt != 42) return false;
        if (!root["empty"].isNull) return false;
        if (root["pi"].getDouble < 3.14) return false;
        if (root["negative"].getInt != -999) return false;
        
        return true;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Edge Case Tests (Robustness)
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Edge Case Tests:");
    
    test("Deep nested JSON (50 levels)", {
        auto parser = Parser.create();
        string json = "";
        for (int i = 0; i < 50; i++) json ~= `{"a":`;
        json ~= "42";
        for (int i = 0; i < 50; i++) json ~= "}";
        
        auto doc = parser.parse(json);
        if (!doc.valid) return false;
        
        auto val = doc.root;
        for (int i = 0; i < 50; i++) val = val["a"];
        return val.getInt == 42;
    });
    
    test("Large JSON array (10000 elements)", {
        auto parser = Parser.create();
        import std.array : appender;
        import std.conv : to;
        auto sb = appender!string();
        sb.put("[");
        for (int i = 0; i < 10000; i++) {
            if (i > 0) sb.put(",");
            sb.put(i.to!string);
        }
        sb.put("]");
        
        auto doc = parser.parse(sb.data);
        if (!doc.valid) return false;
        if (doc.root.length != 10000) return false;
        return doc.root[0].getInt == 0 && doc.root[9999].getInt == 9999;
    });
    
    test("Large JSON object (1000 keys)", {
        auto parser = Parser.create();
        import std.array : appender;
        import std.conv : to;
        auto sb = appender!string();
        sb.put("{");
        for (int i = 0; i < 1000; i++) {
            if (i > 0) sb.put(",");
            sb.put(`"k` ~ i.to!string ~ `":` ~ i.to!string);
        }
        sb.put("}");
        
        auto doc = parser.parse(sb.data);
        if (!doc.valid) return false;
        return doc.root["k0"].getInt == 0 && doc.root["k999"].getInt == 999;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Error Handling Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Error Handling Tests:");
    
    test("getString throws on type mismatch", {
        auto parser = Parser.create();
        auto doc = parser.parse(`42`);
        if (!doc.valid) return false;
        // getString() should throw JsonException for non-string value
        try {
            doc.root.getString;
            return false;  // Should have thrown
        } catch (JsonException e) {
            return e.error == JsonError.incorrectType;
        }
    });
    
    test("getString throws on invalid value", {
        auto parser = Parser.create();
        auto doc = parser.parse(`{"invalid": null}`);
        if (!doc.valid) return false;
        // getString() should throw JsonException for null value
        try {
            doc.root["invalid"].getString;
            return false;  // Should have thrown
        } catch (JsonException e) {
            return e.error == JsonError.incorrectType;
        }
    });
    
    test("Capacity error with small parser", {
        auto parser = Parser(100); // Very small capacity (100 bytes)
        // Try to parse a document larger than capacity
        import std.array : appender;
        auto sb = appender!string();
        sb.put(`{"data": "`);
        // Add enough data to exceed 100 bytes
        foreach (_; 0 .. 200) {
            sb.put("x");
        }
        sb.put(`"}`);
        
        auto doc = parser.parse(sb.data);
        // Should fail with capacity error
        return !doc.valid && doc.error == JsonError.capacity;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // UTF-8 Edge Cases Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("UTF-8 Edge Cases Tests:");
    
    test("UTF-8 emoji in string", {
        auto parser = Parser.create();
        // Test with emoji (4-byte UTF-8)
        auto doc = parser.parse(`"Hello 🌍 World"`);
        if (!doc.valid) return false;
        auto str = doc.root.getString;
        // Verify string contains emoji by checking length (emoji takes 4 bytes)
        return str.length > 10; // "Hello " is 6 bytes, emoji is 4, " World" is 6 = 16 bytes
    });
    
    test("UTF-8 Chinese characters", {
        auto parser = Parser.create();
        // Test with Chinese characters (3-byte UTF-8)
        auto doc = parser.parse(`"你好世界"`);
        if (!doc.valid) return false;
        auto str = doc.root.getString;
        return str.length > 0;
    });
    
    test("UTF-8 mixed scripts", {
        auto parser = Parser.create();
        // Test with mixed scripts (Latin, Cyrillic, Arabic, etc.)
        auto doc = parser.parse(`"Hello Привет مرحبا"`);
        if (!doc.valid) return false;
        auto str = doc.root.getString;
        return str.length > 0;
    });
    
    test("UTF-8 escape sequences", {
        auto parser = Parser.create();
        // Test with Unicode escape sequences
        // Note: simdjson returns escape sequences as-is (doesn't decode them)
        auto doc = parser.parse(`"\\u0041\\u0042\\u0043"`); // \u0041\u0042\u0043
        if (!doc.valid) return false;
        auto str = doc.root.getString;
        // String should contain the escape sequences literally
        return str.length > 0 && str.length == 18; // "\u0041\u0042\u0043" is 18 chars
    });
    
    test("UTF-8 high surrogate pair", {
        auto parser = Parser.create();
        // Test with high surrogate (U+1F600 = 😀, encoded as \uD83D\uDE00)
        auto doc = parser.parse(`"\\uD83D\\uDE00"`); // 😀 emoji
        if (!doc.valid) return false;
        auto str = doc.root.getString;
        return str.length > 0;
    });
    
    test("UTF-8 in object keys", {
        auto parser = Parser.create();
        // Test UTF-8 in object keys
        auto doc = parser.parse(`{"名字": "test", "âge": 25}`);
        if (!doc.valid) return false;
        // Should be able to access keys with UTF-8
        return doc.root.hasKey("名字") && doc.root.hasKey("âge");
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Number Limit Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Number Limit Tests:");
    
    test("MAX_INT64", {
        auto parser = Parser.create();
        // Maximum signed 64-bit integer: 9223372036854775807
        auto doc = parser.parse(`9223372036854775807`);
        if (!doc.valid) return false;
        if (!doc.root.isInt) return false;
        return doc.root.getInt == 9223372036854775807L;
    });
    
    test("MIN_INT64", {
        auto parser = Parser.create();
        // Minimum signed 64-bit integer: -9223372036854775808
        // Note: Can't write -9223372036854775808L directly (overflow), so we parse and check
        auto doc = parser.parse(`-9223372036854775808`);
        if (!doc.valid) return false;
        if (!doc.root.isInt) return false;
        // Check that it's the minimum value
        long minVal = doc.root.getInt;
        return minVal == long.min; // long.min is -9223372036854775808
    });
    
    test("MAX_UINT64", {
        auto parser = Parser.create();
        // Maximum unsigned 64-bit integer: 18446744073709551615
        auto doc = parser.parse(`18446744073709551615`);
        if (!doc.valid) return false;
        if (!doc.root.isUint) return false;
        return doc.root.getUint == 18446744073709551615UL;
    });
    
    test("Zero as integer", {
        auto parser = Parser.create();
        auto doc = parser.parse(`0`);
        if (!doc.valid) return false;
        if (!doc.root.isInt) return false;
        return doc.root.getInt == 0;
    });
    
    test("Zero as unsigned", {
        auto parser = Parser.create();
        auto doc = parser.parse(`0`);
        if (!doc.valid) return false;
        // Zero can be both int and uint
        return doc.root.isInt || doc.root.isUint;
    });
    
    test("Large double precision", {
        auto parser = Parser.create();
        // Test with very large double
        auto doc = parser.parse(`1.7976931348623157e+308`);
        if (!doc.valid) return false;
        if (!doc.root.isDouble) return false;
        auto val = doc.root.getDouble;
        return val > 1e300;
    });
    
    test("Small double precision", {
        auto parser = Parser.create();
        // Test with very small double (denormalized)
        auto doc = parser.parse(`2.2250738585072014e-308`);
        if (!doc.valid) return false;
        if (!doc.root.isDouble) return false;
        auto val = doc.root.getDouble;
        return val > 0 && val < 1e-300;
    });
    
    test("Integer overflow detection", {
        auto parser = Parser.create();
        // Test with number larger than MAX_UINT64
        // simdjson returns numberError for numbers that exceed representable range
        auto doc = parser.parse(`18446744073709551616`); // MAX_UINT64 + 1
        // Should fail with numberError
        return !doc.valid && doc.error == JsonError.numberError;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Specific Error Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Specific Error Tests:");
    
    test("Depth error with very deep nesting (>1024 levels)", {
        auto parser = Parser.create();
        // Create JSON with >1024 levels of nesting
        // simdjson limit is 1024 levels
        string json = "";
        for (int i = 0; i < 1025; i++) json ~= `{"a":`;
        json ~= "42";
        for (int i = 0; i < 1025; i++) json ~= "}";
        
        auto doc = parser.parse(json);
        // Should fail with depthError
        return !doc.valid && doc.error == JsonError.depthError;
    });
    
    test("UTF-8 error with invalid sequence", {
        auto parser = Parser.create();
        // Create JSON with invalid UTF-8 sequence
        // 0xFF 0xFE is invalid UTF-8 (not a valid start byte)
        ubyte[] invalidUtf8 = [0x22, 0xFF, 0xFE, 0x22]; // "invalid"
        auto doc = parser.parse(cast(const(char)[]) invalidUtf8);
        // Should fail with utf8Error or stringError
        return !doc.valid && (doc.error == JsonError.utf8Error || doc.error == JsonError.stringError);
    });
    
    test("UTF-8 error with incomplete sequence", {
        auto parser = Parser.create();
        // Create JSON with incomplete UTF-8 sequence
        // 0xC0 starts a 2-byte sequence but is incomplete
        ubyte[] incompleteUtf8 = [0x22, 0xC0, 0x22]; // "incomplete"
        auto doc = parser.parse(cast(const(char)[]) incompleteUtf8);
        // Should fail with utf8Error or stringError
        return !doc.valid && (doc.error == JsonError.utf8Error || doc.error == JsonError.stringError);
    });
    
    test("Unclosed string error", {
        auto parser = Parser.create();
        // Create JSON with unclosed string
        auto doc = parser.parse(`{"key": "unclosed`);
        // Should fail with unclosedString error
        return !doc.valid && doc.error == JsonError.unclosedString;
    });
    
    test("Unescaped control characters error", {
        auto parser = Parser.create();
        // Create JSON with unescaped control character (0x01)
        ubyte[] withControl = [0x22, 0x01, 0x22]; // "\x01"
        auto doc = parser.parse(cast(const(char)[]) withControl);
        // Should fail with unescapedChars error
        return !doc.valid && doc.error == JsonError.unescapedChars;
    });
    
    // Note: memalloc error is difficult to test deterministically
    // as it depends on system memory availability. It would require
    // allocating an extremely large document that exceeds available memory.
    
    // ─────────────────────────────────────────────────────────────────────────
    // Summary
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("========================================");
    writefln("  Results: %d passed, %d failed", passed, failed);
    writeln("========================================");
    
    if (failed > 0) {
        import core.stdc.stdlib : exit;
        exit(1);
    }
}
