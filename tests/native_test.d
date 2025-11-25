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
