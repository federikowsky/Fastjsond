/**
 * fastjsond.std - std.json Compatibility Layer Tests
 */
module tests.std_test;

import fastjsond.std;
import std.stdio;

void main() {
    writeln("========================================");
    writeln("  fastjsond.std Tests");
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
    // Basic Parsing Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln("Basic Parsing:");
    
    test("Parse null", {
        auto json = parseJSON(`null`);
        return json.isNull;
    });
    
    test("Parse true", {
        auto json = parseJSON(`true`);
        return json.type == JSONValue.Type.true_;
    });
    
    test("Parse false", {
        auto json = parseJSON(`false`);
        return json.type == JSONValue.Type.false_;
    });
    
    test("Parse integer", {
        auto json = parseJSON(`42`);
        return json.type == JSONValue.Type.integer && json.integer == 42;
    });
    
    test("Parse negative integer", {
        auto json = parseJSON(`-123`);
        return json.integer == -123;
    });
    
    test("Parse float", {
        auto json = parseJSON(`3.14`);
        return json.type == JSONValue.Type.float_ && json.floating > 3.1;
    });
    
    test("Parse string", {
        auto json = parseJSON(`"hello"`);
        return json.type == JSONValue.Type.string_ && json.str == "hello";
    });
    
    test("Parse empty array", {
        auto json = parseJSON(`[]`);
        return json.type == JSONValue.Type.array && json.array.length == 0;
    });
    
    test("Parse array", {
        auto json = parseJSON(`[1, 2, 3]`);
        return json.array.length == 3 && json[0].integer == 1;
    });
    
    test("Parse empty object", {
        auto json = parseJSON(`{}`);
        return json.type == JSONValue.Type.object && json.object.length == 0;
    });
    
    test("Parse object", {
        auto json = parseJSON(`{"name": "test"}`);
        return json["name"].str == "test";
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // std.json Compatible Access
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("std.json Compatible Access:");
    
    test(".str accessor", {
        auto json = parseJSON(`{"key": "value"}`);
        return json["key"].str == "value";
    });
    
    test(".integer accessor", {
        auto json = parseJSON(`{"num": 42}`);
        return json["num"].integer == 42;
    });
    
    test(".floating accessor", {
        auto json = parseJSON(`{"pi": 3.14}`);
        return json["pi"].floating > 3.0;
    });
    
    test(".boolean accessor", {
        auto json = parseJSON(`{"flag": true}`);
        return json["flag"].boolean == true;
    });
    
    test(".array accessor", {
        auto json = parseJSON(`{"items": [1, 2, 3]}`);
        return json["items"].array.length == 3;
    });
    
    test(".object accessor", {
        auto json = parseJSON(`{"nested": {"a": 1}}`);
        auto obj = json["nested"].object;
        return ("a" in obj) !is null;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Operator Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Operators:");
    
    test("opIndex string", {
        auto json = parseJSON(`{"key": "value"}`);
        return json["key"].str == "value";
    });
    
    test("opIndex int", {
        auto json = parseJSON(`[10, 20, 30]`);
        return json[1].integer == 20;
    });
    
    test("in operator", {
        auto json = parseJSON(`{"exists": true}`);
        return ("exists" in json) !is null && ("missing" in json) is null;
    });
    
    test("length", {
        auto json = parseJSON(`[1, 2, 3, 4, 5]`);
        return json.length == 5;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Iteration Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Iteration:");
    
    test("Array foreach", {
        auto json = parseJSON(`[1, 2, 3]`);
        long sum = 0;
        foreach (ref v; json) {
            sum += v.integer;
        }
        return sum == 6;
    });
    
    test("Array foreach with index", {
        auto json = parseJSON(`["a", "b", "c"]`);
        size_t count = 0;
        foreach (size_t i, ref v; json) {
            count++;
        }
        return count == 3;
    });
    
    test("Object foreach", {
        auto json = parseJSON(`{"a": 1, "b": 2}`);
        long sum = 0;
        foreach (string k, ref v; json) {
            sum += v.integer;
        }
        return sum == 3;
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Serialization Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Serialization:");
    
    test("toJSON null", {
        auto json = parseJSON(`null`);
        return toJSON(json) == "null";
    });
    
    test("toJSON bool", {
        auto json = parseJSON(`true`);
        return toJSON(json) == "true";
    });
    
    test("toJSON integer", {
        auto json = parseJSON(`42`);
        return toJSON(json) == "42";
    });
    
    test("toJSON string", {
        auto json = parseJSON(`"hello"`);
        return toJSON(json) == `"hello"`;
    });
    
    test("toJSON array", {
        auto json = parseJSON(`[1,2,3]`);
        return toJSON(json) == "[1,2,3]";
    });
    
    test("toJSON object", {
        auto json = parseJSON(`{"a":1}`);
        auto result = toJSON(json);
        // Object key order may vary
        return result == `{"a":1}`;
    });
    
    test("Pretty print", {
        auto json = parseJSON(`{"a":1}`);
        auto pretty = toPrettyJSON(json);
        return pretty.length > `{"a":1}`.length; // Should have newlines/indents
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Error Handling Tests
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Error Handling:");
    
    test("Parse error throws", {
        try {
            parseJSON(`{invalid}`);
            return false;
        } catch (JSONException e) {
            return true;
        }
    });
    
    test("Type mismatch throws", {
        auto json = parseJSON(`42`);
        try {
            json.str;  // Should throw - not a string
            return false;
        } catch (JSONException e) {
            return true;
        }
    });
    
    test("Key not found throws", {
        auto json = parseJSON(`{"a": 1}`);
        try {
            json["missing"];
            return false;
        } catch (JSONException e) {
            return true;
        }
    });
    
    test("Index out of bounds throws", {
        auto json = parseJSON(`[1, 2]`);
        try {
            json[10];
            return false;
        } catch (JSONException e) {
            return true;
        }
    });
    
    // ─────────────────────────────────────────────────────────────────────────
    // Complex JSON Test
    // ─────────────────────────────────────────────────────────────────────────
    
    writeln();
    writeln("Complex JSON:");
    
    test("Parse and access complex JSON", {
        auto json = parseJSON(`{
            "users": [
                {"name": "Alice", "age": 30},
                {"name": "Bob", "age": 25}
            ],
            "meta": {
                "count": 2,
                "page": 1
            }
        }`);
        
        if (json["users"].length != 2) return false;
        if (json["users"][0]["name"].str != "Alice") return false;
        if (json["users"][1]["age"].integer != 25) return false;
        if (json["meta"]["count"].integer != 2) return false;
        
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
